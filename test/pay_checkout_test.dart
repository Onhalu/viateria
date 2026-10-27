import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/domain/fapi_offer.dart';
import 'package:viateria/domain/pay_cta.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/fapi_checkout_webview.dart';

import 'challenge_reward_test.dart';
import 'helpers/fake_payment_webview.dart';
import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugPaymentWebViewBuilder = fakePaymentWebViewBuilder();
  });

  tearDown(() {
    debugPaymentWebViewBuilder = null;
  });

  group('checkout idempotency', () {
    PayCheckoutAttempt attempt() {
      var n = 0;
      return PayCheckoutAttempt(
        mint: () {
          n++;
          return 'key-$n';
        },
      );
    }

    test('reuses the key for the same variant and price', () {
      final pay = attempt();
      final first = pay.begin(
        variant: RewardVariant.diploma,
        priceCents: 124900,
      );
      pay.phase = PayCtaPhase.idle;
      final second = pay.begin(
        variant: RewardVariant.diploma,
        priceCents: 124900,
      );
      expect(second, first);
      expect(first, 'key-1');
    });

    test('retry after timeout keeps the key when the price arrives late', () {
      final pay = attempt();
      final first = pay.begin(
        variant: RewardVariant.diploma,
        priceCents: null,
      );
      pay.phase = PayCtaPhase.timeout;
      final retry = pay.begin(
        variant: RewardVariant.diploma,
        priceCents: 124900,
      );
      expect(retry, first);
      expect(pay.phase, PayCtaPhase.loading);
    });

    test('a new variant or a new price mints a new key, including 0 Kč', () {
      final pay = attempt();
      final free = pay.begin(variant: RewardVariant.diploma, priceCents: 0);
      pay.phase = PayCtaPhase.error;
      final freeRetry = pay.begin(
        variant: RewardVariant.diploma,
        priceCents: 0,
      );
      expect(freeRetry, free);

      pay.phase = PayCtaPhase.idle;
      final medal = pay.begin(
        variant: RewardVariant.medalAndDiploma,
        priceCents: 0,
      );
      expect(medal, isNot(free));

      pay.phase = PayCtaPhase.idle;
      final priced = pay.begin(
        variant: RewardVariant.medalAndDiploma,
        priceCents: 100,
      );
      expect(priced, isNot(medal));
    });
  });

  test('pay labels use the verb in cs, en, and de', () {
    final cs = AppStrings('cs');
    final en = AppStrings('en');
    final de = AppStrings('de');
    expect(cs.payCtaFree, 'Přihlásit se do výzvy');
    expect(en.payCtaFree, 'Join the challenge');
    expect(de.payCtaFree, 'Zur Challenge anmelden');
    expect(cs.retry, 'Zkusit znovu');

    final paid = formatChallengePrice(124900, 'czk', 'cs')!;
    expect(
      payCtaLabel(
        productLabel: cs.payDigitalDiploma,
        priceCents: 124900,
        amountLabel: cs.payCtaAmount(paid),
        freeLabel: cs.payCtaFree,
        showRetry: false,
        retryLabel: cs.retry,
      ),
      'Zaplatit $paid',
    );
    expect(
      payCtaLabel(
        productLabel: en.payDigitalDiploma,
        priceCents: 0,
        amountLabel: null,
        freeLabel: en.payCtaFree,
        showRetry: false,
        retryLabel: en.retry,
      ),
      'Join the challenge',
    );
    expect(
      payCtaLabel(
        productLabel: de.payMedalAndDiploma,
        priceCents: null,
        amountLabel: null,
        freeLabel: de.payCtaFree,
        showRetry: false,
        retryLabel: de.retry,
      ),
      de.payMedalAndDiploma,
    );
    expect(
      payCtaLabel(
        productLabel: cs.payDigitalDiploma,
        priceCents: 124900,
        amountLabel: cs.payCtaAmount(paid),
        freeLabel: cs.payCtaFree,
        showRetry: true,
        retryLabel: cs.retry,
      ),
      'Zkusit znovu',
    );
    expect(payCtaPriceCents(offerReady: false, offerCents: 0), isNull);
    expect(payCtaPriceCents(offerReady: true, offerCents: 0), 0);
  });

  testWidgets('a loading pay button keeps its width and skips motion', (
    tester,
  ) async {
    const label = 'Zaplatit 1 249 Kč';
    Future<void> pump({required bool loading, required bool reduce}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Scaffold(
              body: Center(
                child: AppButton(
                  label: label,
                  loading: loading,
                  haptic: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pump(loading: false, reduce: true);
    final idle = tester.getSize(find.byType(AppButton)).width;
    expect(idle, greaterThan(64));

    await pump(loading: true, reduce: true);
    expect(tester.getSize(find.byType(AppButton)).width, closeTo(idle, 0.5));
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size(18, 18),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
  });

  testWidgets('timeout unlocks retry with the same key; medal mints another', (
    tester,
  ) async {
    useTallView(tester);
    final gate = Completer<CheckoutSession>();
    final purchases = MemoryPurchases(completeOnRefresh: false)
      ..checkoutGate = gate;
    final story = sampleStoryChallenge();
    await tester.pumpWidget(
      _screen(
        buildServices(detail: story, purchases: purchases),
        challengeId: story.challenge.id,
        checkoutTimeout: const Duration(milliseconds: 30),
      ),
    );
    await tester.pumpAndSettle();

    final diploma = find.byKey(const Key('challenge-pay-diploma'));
    await tester.ensureVisible(diploma);
    final width = tester.getSize(diploma).width;
    await tester.tap(diploma);
    await tester.pump();

    expect(purchases.startCalls, 1);
    expect(
      tester.widget<PopScope>(find.byKey(const Key('challenge-pay-scope'))).canPop,
      isFalse,
    );
    expect(
      tester
          .widget<AbsorbPointer>(find.byKey(const Key('challenge-pay-lock')))
          .absorbing,
      isTrue,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(of: diploma, matching: find.byType(OutlinedButton)),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('app-button-spinner')), findsWidgets);
    expect(tester.getSize(diploma).width, closeTo(width, 0.5));

    await tester.tap(diploma, warnIfMissed: false);
    await tester.pump();
    expect(purchases.startCalls, 1, reason: 'the locked button ignores a second tap');

    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();
    gate.completeError(StateError('late response'));
    await tester.pump();

    expect(find.byKey(const Key('challenge-pay-phase-timeout')), findsOneWidget);
    expect(find.text('Zkusit znovu'), findsWidgets);
    expect(
      tester.widget<PopScope>(find.byKey(const Key('challenge-pay-scope'))).canPop,
      isTrue,
    );
    final key = purchases.idempotencyKeys.single;
    expect(
      key,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );

    purchases.checkoutError = StateError('still down');
    await tester.ensureVisible(diploma);
    await tester.tap(diploma);
    await tester.pumpAndSettle();
    expect(purchases.idempotencyKeys, [key, key]);
    expect(find.text('Zkusit znovu'), findsWidgets);

    final medal = find.byKey(const Key('challenge-pay-medal'));
    await tester.ensureVisible(medal);
    await tester.tap(medal);
    await tester.pumpAndSettle();
    expect(purchases.idempotencyKeys, hasLength(3));
    expect(purchases.idempotencyKeys[2], isNot(key));
    expect(
      purchases.purchases[story.challenge.id]!.rewardVariant,
      RewardVariant.medalAndDiploma,
    );
    expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);
  });

  testWidgets('a free challenge uses the same CTAs and one key per cart', (
    tester,
  ) async {
    useTallView(tester);
    final story = sampleStoryChallenge();
    final free = ChallengeDetail(
      challenge: Challenge(
        id: story.challenge.id,
        slug: story.challenge.slug,
        accessMode: story.challenge.accessMode,
        pricingType: PricingType.free,
        priceCents: 0,
        diplomaPriceCents: 0,
        medalPriceCents: 0,
        currency: 'czk',
        status: story.challenge.status,
        translations: story.challenge.translations,
        fapiFormUrlDiploma: story.challenge.fapiFormUrlDiploma,
        fapiFormUrlMedal: story.challenge.fapiFormUrlMedal,
      ),
      waypoints: story.waypoints,
    );
    final purchases = MemoryPurchases(completeOnRefresh: false)
      ..offer = const FapiOffer(
        diploma: FapiOfferVariant(priceCents: 0, currency: 'czk'),
        medal: FapiOfferVariant(priceCents: 0, currency: 'czk'),
      );
    await tester.pumpWidget(
      _screen(
        buildServices(detail: free, purchases: purchases),
        challengeId: free.challenge.id,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Přihlásit se do výzvy'), findsNWidgets(4));
    expect(find.byKey(const Key('challenge-pay-diploma')), findsOneWidget);
    expect(find.byKey(const Key('challenge-pay-medal')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('challenge-pay-diploma')));
    await tester.tap(find.byKey(const Key('challenge-pay-diploma')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);
    expect(purchases.idempotencyKeys.single, isNotEmpty);
    expect(
      purchases.purchases[free.challenge.id]!.rewardVariant,
      RewardVariant.diploma,
    );

    await tester.tap(find.byKey(const Key('payment-checkout-close')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('challenge-pay-diploma')));
    await tester.tap(find.byKey(const Key('challenge-pay-diploma')));
    await tester.pumpAndSettle();
    expect(purchases.idempotencyKeys, [
      purchases.idempotencyKeys.first,
      purchases.idempotencyKeys.first,
    ]);
  });
}

Widget _screen(
  AppServices services, {
  required String challengeId,
  Duration checkoutTimeout = kPayCheckoutStartTimeout,
}) {
  return TickerMode(
    enabled: false,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleController(initial: 'cs'),
        ),
        ChangeNotifierProvider(
          create: (_) => LastOpenedChallengeStore(initialId: challengeId),
        ),
        Provider<AppServices>.value(value: services),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ChallengeScreen(
          challengeId: challengeId,
          checkoutTimeout: checkoutTimeout,
        ),
      ),
    ),
  );
}
