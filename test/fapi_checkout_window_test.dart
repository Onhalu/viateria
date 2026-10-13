import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/unconfigured.dart';
import 'package:viateria/domain/fapi_frame_policy.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/ui/fapi_checkout_window.dart';
import 'package:viateria/ui/widgets/fapi_checkout_webview.dart';

import 'helpers/fake_payment_webview.dart';
import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugPaymentWebViewBuilder = fakePaymentWebViewBuilder();
  });

  tearDown(() {
    debugPaymentWebViewBuilder = null;
  });

  testWidgets('checkout opens in a sized dialog with a close button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const Key('open-checkout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('payment-checkout-dialog')), findsOneWidget);
    expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);
    expect(find.byKey(const Key('payment-checkout-close')), findsOneWidget);
    expect(
      find.byKey(const Key('payment-checkout-popup-fallback')),
      findsNothing,
    );
    expect(find.text('https://form.fapi.cz/diploma-test'), findsOneWidget);

    final dialog = tester.getSize(
      find.byKey(const Key('payment-checkout-dialog')),
    );
    expect(dialog.width, closeTo(320 * 0.92, 0.01));
    expect(dialog.height, closeTo(480 * 0.92, 0.01));

    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('payment-checkout-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('payment-checkout-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment-checkout-dialog')), findsNothing);
  });

  testWidgets('blocked framing opens a centered popup instead of a tab', (
    tester,
  ) async {
    final strings = AppStrings('en');
    String? features;
    String? targetUrl;

    await tester.pumpWidget(
      _host(
        presentation: FapiCheckoutPresentation.centeredPopup,
        screenSize: (width: 1200, height: 900),
        openPopup: (url, popupFeatures) {
          targetUrl = url;
          features = popupFeatures;
          return true;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-checkout')));
    await tester.pump();
    await tester.pump();

    expect(targetUrl, 'https://form.fapi.cz/diploma-test');
    expect(features, contains('width=560'));
    expect(features, contains('height=828'));
    expect(features, contains('left=320'));
    expect(features, contains('top=36'));
    expect(features!.contains('_blank'), isFalse);
    expect(
      find.byKey(const Key('payment-checkout-popup-fallback')),
      findsOneWidget,
    );
    expect(find.text(strings.paymentPopupBody), findsOneWidget);
    expect(find.text(strings.paymentPopupBlocked), findsNothing);

    await tester.tap(find.byKey(const Key('payment-checkout-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('payment-checkout-dialog')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a blocked popup tells the user and can be retried', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    var opened = false;
    await tester.pumpWidget(
      _host(
        locale: 'cs',
        presentation: FapiCheckoutPresentation.centeredPopup,
        openPopup: (url, features) {
          expect(features, contains('width='));
          expect(features, contains('height='));
          expect(features, contains('left='));
          expect(features, contains('top='));
          return opened;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-checkout')));
    await tester.pumpAndSettle();

    expect(find.text(strings.paymentPopupBlocked), findsOneWidget);
    expect(find.byKey(const Key('payment-popup-retry')), findsOneWidget);

    opened = true;
    await tester.tap(find.byKey(const Key('payment-popup-retry')));
    await tester.pump();
    expect(find.text(strings.paymentPopupBody), findsOneWidget);

    await tester.tap(find.byKey(const Key('payment-checkout-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('payment-checkout-dialog')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}

Widget _host({
  String locale = 'en',
  FapiCheckoutPresentation? presentation,
  FapiPopupOpener? openPopup,
  ({double width, double height})? screenSize,
}) {
  final services = AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: UnconfiguredAuth(),
    catalog: UnconfiguredCatalog(),
    progress: UnconfiguredProgress(),
    purchases: MemoryPurchases(completeOnRefresh: false),
    photos: UnconfiguredPhotos(),
    photoCapture: UnconfiguredCapture(),
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: locale)),
      Provider.value(value: services),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-checkout'),
                onPressed: () {
                  showInAppFapiCheckout(
                    context,
                    challengeId: 'story-1',
                    checkoutUrl: 'https://form.fapi.cz/diploma-test',
                    presentation: presentation,
                    openPopup: openPopup,
                    screenSize: screenSize,
                  );
                },
                child: const Text('Pay'),
              ),
            ),
          );
        },
      ),
    ),
  );
}
