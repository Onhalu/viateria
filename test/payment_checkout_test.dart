import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/domain/payment_checkout.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/screens/payment_checkout_screen.dart';
import 'package:viateria/ui/widgets/fapi_checkout_webview.dart';

import 'helpers/fake_payment_webview.dart';
import 'helpers/fakes.dart';

Purchase pendingPurchase() => const Purchase(
  challengeId: 'story-1',
  status: PurchaseStatus.pending,
  rewardVariant: RewardVariant.diploma,
);

Purchase paidPurchase() => Purchase(
  challengeId: 'story-1',
  status: PurchaseStatus.paid,
  paidAt: DateTime(2026, 3, 11),
  rewardVariant: RewardVariant.diploma,
);

PaymentCheckoutController controllerWith({
  required Future<Purchase?> Function() refreshPurchase,
  Future<void> Function(Duration duration)? delay,
  DateTime Function()? clock,
}) {
  return PaymentCheckoutController(
    refreshPurchase: refreshPurchase,
    delay: delay ?? (_) async {},
    clock: clock,
  );
}

Widget wrapPayment({
  required PaymentCheckoutController controller,
  String locale = 'cs',
  String url = 'https://form.fapi.cz/diploma-test',
  Duration? autoPopAfterSuccess,
  bool autoLoad = true,
  AppServices? services,
}) {
  return TickerMode(
    key: ValueKey('$locale-${identityHashCode(controller)}-$autoLoad'),
    enabled: false,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleController(initial: locale),
        ),
        ChangeNotifierProvider(
          create: (_) => LastOpenedChallengeStore(initialId: 'story-1'),
        ),
        Provider.value(
          value:
              services ??
              AppServices(
                config: const AppConfig(
                  supabaseUrl: 'https://example.supabase.co',
                  supabaseAnonKey: 'anon',
                  stripePublishableKey: 'pk_test',
                ),
                auth: MemoryAuth(
                  user: const Profile(
                    id: 'user-1',
                    locale: 'cs',
                    displayName: 'Ada',
                  ),
                ),
                catalog: MemoryCatalog(),
                progress: MemoryProgress(),
                purchases: MemoryPurchases(),
                photos: MemoryPhotos(),
                photoCapture: MemoryCapture(),
              ),
        ),
      ],
      child: MaterialApp(
        home: PaymentCheckoutScreen(
          challengeId: 'story-1',
          checkoutUrl: url,
          controller: controller,
          webViewBuilder: fakePaymentWebViewBuilder(autoLoad: autoLoad),
          autoPopAfterSuccess: autoPopAfterSuccess,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugPaymentWebViewBuilder = null;
  });

  group('completion heuristic', () {
    test('matches thank-you / order-status / payment-success URLs', () {
      expect(
        looksLikeFapiFormCompletion(Uri.parse('https://form.fapi.cz/dekujeme')),
        isTrue,
      );
      expect(
        looksLikeFapiFormCompletion(
          Uri.parse('https://form.fapi.cz/form?next=thank-you'),
        ),
        isTrue,
      );
      expect(
        looksLikeFapiFormCompletion(
          Uri.parse('https://pay.example/order-status/1'),
        ),
        isTrue,
      );
      expect(
        looksLikeFapiFormCompletion(
          Uri.parse('https://form.fapi.cz/payment-success'),
        ),
        isTrue,
      );
      expect(
        looksLikeFapiFormCompletion(Uri.parse('https://shop.example/danke')),
        isTrue,
      );
    });

    test('ignores the raw FAPI form URL and payment-gateway hosts', () {
      expect(
        looksLikeFapiFormCompletion(
          Uri.parse('https://form.fapi.cz/diploma-test'),
        ),
        isFalse,
      );
      expect(
        looksLikeFapiFormCompletion(
          Uri.parse('https://acs.comgate.cz/3dsecure/start'),
        ),
        isFalse,
      );
      expect(
        isPaymentGatewayUrl(Uri.parse('https://platby.gopay.com/3ds')),
        isTrue,
      );
      expect(isFapiCheckoutJsSignal('submit'), isTrue);
      expect(isFapiCheckoutJsSignal('thankyou-dom'), isTrue);
      expect(isFapiCheckoutJsSignal('click'), isFalse);
    });
  });

  group('PaymentCheckoutController', () {
    test(
      'loading → form → processing → success when purchase is paid',
      () async {
        final controller = controllerWith(
          refreshPurchase: () async => paidPurchase(),
        );
        addTearDown(controller.dispose);

        expect(controller.phase, PaymentCheckoutPhase.loading);
        controller.onWebViewLoaded();
        expect(controller.phase, PaymentCheckoutPhase.form);

        await controller.onFormSubmitted();
        expect(controller.phase, PaymentCheckoutPhase.success);
        expect(controller.pollCount, 1);
      },
    );

    test('pending purchase never becomes success', () async {
      var now = DateTime(2026, 1, 1);
      final controller = controllerWith(
        refreshPurchase: () async => pendingPurchase(),
        delay: (d) async => now = now.add(d),
        clock: () => now,
      );
      addTearDown(controller.dispose);

      controller.onWebViewLoaded();
      await controller.beginProcessing();
      expect(controller.phase, PaymentCheckoutPhase.timeout);
      expect(controller.phase, isNot(PaymentCheckoutPhase.success));
      expect(controller.pollCount, greaterThan(1));
    });

    test('timeout then retry resumes polling until paid', () async {
      var now = DateTime(2026, 1, 1);
      var allowPay = false;
      final controller = controllerWith(
        refreshPurchase: () async =>
            allowPay ? paidPurchase() : pendingPurchase(),
        delay: (d) async => now = now.add(d),
        clock: () => now,
      );
      addTearDown(controller.dispose);

      await controller.beginProcessing();
      expect(controller.phase, PaymentCheckoutPhase.timeout);

      allowPay = true;
      await controller.retry();
      expect(controller.phase, PaymentCheckoutPhase.success);
    });

    test('thank-you URL starts processing', () async {
      final controller = controllerWith(
        refreshPurchase: () async => paidPurchase(),
      );
      addTearDown(controller.dispose);
      controller.onWebViewLoaded();
      controller.onUrlChanged(Uri.parse('https://form.fapi.cz/dekujeme'));
      await controller.beginProcessing();
      expect(controller.phase, PaymentCheckoutPhase.success);
    });

    test('hides processing overlay on a 3DS host', () async {
      final gate = Completer<void>();
      final controller = controllerWith(
        refreshPurchase: () async => pendingPurchase(),
        delay: (_) => gate.future,
      );
      addTearDown(() {
        gate.complete();
        controller.dispose();
      });

      controller.beginProcessing();
      expect(controller.showProcessingOverlay, isTrue);
      controller.onUrlChanged(Uri.parse('https://acs.comgate.cz/3dsecure'));
      expect(controller.isProcessing, isTrue);
      expect(controller.showProcessingOverlay, isFalse);
    });
  });

  group('PaymentCheckoutScreen', () {
    testWidgets('loading copy is cream + forest spinner', (tester) async {
      final strings = AppStrings('cs');
      final controller = controllerWith(
        refreshPurchase: () async => pendingPurchase(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapPayment(controller: controller, autoLoad: false),
      );
      await tester.pump();

      expect(find.byKey(const Key('payment-loading')), findsOneWidget);
      expect(find.text(strings.paymentLoadingForm), findsOneWidget);
      expect(find.text(strings.paymentTitle), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        BrandColors.forest,
      );
    });

    testWidgets('EN and DE loading copy', (tester) async {
      for (final locale in ['en', 'de']) {
        final strings = AppStrings(locale);
        final controller = controllerWith(
          refreshPurchase: () async => pendingPurchase(),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          wrapPayment(controller: controller, locale: locale, autoLoad: false),
        );
        await tester.pump();
        expect(find.text(strings.paymentLoadingForm), findsOneWidget);
        expect(find.text(strings.paymentTitle), findsOneWidget);
      }
    });

    testWidgets('processing overlay uses approved copy', (tester) async {
      final strings = AppStrings('cs');
      final gate = Completer<void>();
      final controller = controllerWith(
        refreshPurchase: () async => pendingPurchase(),
        delay: (_) => gate.future,
      );
      addTearDown(() {
        gate.complete();
        controller.dispose();
      });

      controller.beginProcessing();
      await tester.pumpWidget(
        wrapPayment(controller: controller, autoPopAfterSuccess: null),
      );
      await tester.pump();

      expect(find.byKey(const Key('payment-processing')), findsOneWidget);
      expect(find.byKey(const Key('payment-processing-icon')), findsOneWidget);
      expect(find.text(strings.paymentProcessingTitle), findsOneWidget);
      expect(find.text(strings.paymentProcessingBody), findsOneWidget);
      expect(find.byKey(const Key('payment-success')), findsNothing);
    });

    testWidgets('success only after paid and shows CTA', (tester) async {
      final strings = AppStrings('cs');
      final controller = controllerWith(
        refreshPurchase: () async => paidPurchase(),
      );
      addTearDown(controller.dispose);
      await controller.beginProcessing();
      expect(controller.phase, PaymentCheckoutPhase.success);

      await tester.pumpWidget(
        wrapPayment(controller: controller, autoPopAfterSuccess: null),
      );
      await tester.pump();

      expect(find.byKey(const Key('payment-success')), findsOneWidget);
      expect(find.byKey(const Key('payment-success-icon')), findsOneWidget);
      expect(find.text(strings.paymentSuccessTitle), findsOneWidget);
      expect(find.text(strings.paymentSuccessBody), findsOneWidget);
      expect(find.text(strings.paymentBackToChallenge), findsOneWidget);
      expect(
        tester
            .widget<Icon>(find.byKey(const Key('payment-success-icon')))
            .color,
        BrandColors.forest,
      );
    });

    testWidgets('timeout copy and retry resumes poll', (tester) async {
      final strings = AppStrings('cs');
      var now = DateTime(2026, 1, 1);
      var allowPay = false;
      final purchases = MemoryPurchases(completeOnRefresh: false);
      final controller = controllerWith(
        refreshPurchase: () async =>
            allowPay ? paidPurchase() : pendingPurchase(),
        delay: (d) async => now = now.add(d),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.beginProcessing();
      expect(controller.phase, PaymentCheckoutPhase.timeout);

      await tester.pumpWidget(
        wrapPayment(
          controller: controller,
          autoPopAfterSuccess: null,
          services: AppServices(
            config: const AppConfig(
              supabaseUrl: 'https://example.supabase.co',
              supabaseAnonKey: 'anon',
              stripePublishableKey: 'pk_test',
            ),
            auth: MemoryAuth(
              user: const Profile(
                id: 'user-1',
                locale: 'cs',
                displayName: 'Ada',
              ),
            ),
            catalog: MemoryCatalog(),
            progress: MemoryProgress(),
            purchases: purchases,
            photos: MemoryPhotos(),
            photoCapture: MemoryCapture(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('payment-timeout')), findsOneWidget);
      expect(find.text(strings.paymentTimeoutBody), findsOneWidget);
      expect(find.text(strings.paymentBackToChallenge), findsOneWidget);
      expect(find.text(strings.paymentRetry), findsOneWidget);

      allowPay = true;
      await tester.tap(find.byKey(const Key('payment-retry')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('payment-success')), findsOneWidget);
    });

    testWidgets('back during processing shows confirm dialog', (tester) async {
      final strings = AppStrings('cs');
      final gate = Completer<void>();
      final controller = controllerWith(
        refreshPurchase: () async => pendingPurchase(),
        delay: (_) => gate.future,
      );
      addTearDown(() {
        gate.complete();
        controller.dispose();
      });
      controller.beginProcessing();

      await tester.pumpWidget(
        wrapPayment(controller: controller, autoPopAfterSuccess: null),
      );
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment-leave-dialog')), findsOneWidget);
      expect(find.text(strings.paymentLeaveConfirm), findsOneWidget);
      expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);

      await tester.tap(find.byKey(const Key('payment-stay')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payment-leave-dialog')), findsNothing);
      expect(find.byKey(const Key('payment-processing')), findsOneWidget);
    });

    testWidgets('EN processing and success copy', (tester) async {
      final strings = AppStrings('en');
      final controller = controllerWith(
        refreshPurchase: () async => paidPurchase(),
      );
      addTearDown(controller.dispose);
      await controller.beginProcessing();
      await tester.pumpWidget(
        wrapPayment(
          controller: controller,
          locale: 'en',
          autoPopAfterSuccess: null,
        ),
      );
      await tester.pump();
      expect(find.text(strings.paymentSuccessTitle), findsOneWidget);
      expect(find.text(strings.paymentSuccessBody), findsOneWidget);
      expect(find.text(strings.paymentBackToChallenge), findsOneWidget);
    });

    testWidgets('DE processing copy', (tester) async {
      final strings = AppStrings('de');
      final gate = Completer<void>();
      final controller = controllerWith(
        refreshPurchase: () async => pendingPurchase(),
        delay: (_) => gate.future,
      );
      addTearDown(() {
        gate.complete();
        controller.dispose();
      });
      controller.beginProcessing();
      await tester.pumpWidget(
        wrapPayment(
          controller: controller,
          locale: 'de',
          autoPopAfterSuccess: null,
        ),
      );
      await tester.pump();
      expect(find.text(strings.paymentProcessingTitle), findsOneWidget);
      expect(find.text(strings.paymentProcessingBody), findsOneWidget);
    });
  });
}
