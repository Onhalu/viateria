import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/diploma_client.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/data/challenge_mapping.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/domain/fapi_offer.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/challenge_cta_panel.dart';
import 'package:viateria/ui/widgets/challenge_map.dart';
import 'package:viateria/ui/widgets/challenge_reward_section.dart';
import 'package:viateria/ui/widgets/fapi_checkout_webview.dart';
import 'package:viateria/ui/widgets/route_planner_panel.dart';

import 'helpers/fake_payment_webview.dart';
import 'helpers/fakes.dart';

AppServices buildServices({
  MemoryProgress? progress,
  MemoryPurchases? purchases,
  ChallengeDetail? detail,
  ExternalUrlOpener? openUrl,
  DiplomaClient? diplomas,
}) {
  final open = detail ?? sampleOpenChallenge();
  return AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: MemoryAuth(
      user: const Profile(id: 'user-1', locale: 'cs', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(challenges: [open.challenge], details: [open]),
    progress: progress ?? MemoryProgress(details: [open]),
    purchases: purchases ?? MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    openUrl: openUrl ?? (_) async {},
    diplomas: diplomas,
  );
}

Widget wrapScreen(
  AppServices services, {
  String locale = 'cs',
  String challengeId = 'open-1',
}) {
  return TickerMode(
    enabled: false,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleController(initial: locale),
        ),
        ChangeNotifierProvider(
          create: (_) => LastOpenedChallengeStore(initialId: challengeId),
        ),
        Provider.value(value: services),
      ],
      child: MaterialApp(home: ChallengeScreen(challengeId: challengeId)),
    ),
  );
}

MemoryProgress completedProgress(ChallengeDetail detail) {
  final progress = MemoryProgress(details: [detail]);
  progress.completed[detail.challenge.id] = {
    for (final waypoint in detail.waypoints) waypoint.id,
  };
  progress.statuses[detail.challenge.id] = ChallengeRunStatus.completed;
  return progress;
}

void useTallView(WidgetTester tester) {
  useView(tester, width: 800, height: 4000);
}

void useView(
  WidgetTester tester, {
  required double width,
  double height = 4000,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugPaymentWebViewBuilder = fakePaymentWebViewBuilder();
  });

  tearDown(() {
    debugPaymentWebViewBuilder = null;
  });

  group('domain', () {
    test('complete-by is paidAt plus 6 months', () {
      expect(
        ChallengeCompletionWindow.completeBy(DateTime(2026, 3, 11, 8, 30)),
        DateTime(2026, 9, 11, 8, 30),
      );
      expect(
        ChallengeCompletionWindow.completeBy(DateTime(2025, 9, 30)),
        DateTime(2026, 3, 30),
      );
      expect(ChallengeCompletionWindow.completeBy(null), isNull);
      expect(ChallengeCompletionWindow.months, 6);
    });

    test('reward unlocks only when complete and paid', () {
      expect(
        ChallengeReward.isUnlocked(
          challengeCompleted: true,
          purchasePaid: true,
        ),
        isTrue,
      );
      expect(
        ChallengeReward.isUnlocked(
          challengeCompleted: true,
          purchasePaid: false,
        ),
        isFalse,
      );
      expect(
        ChallengeReward.isUnlocked(
          challengeCompleted: false,
          purchasePaid: true,
        ),
        isFalse,
      );
      expect(
        ChallengeReward.isUnlocked(
          challengeCompleted: true,
          purchasePaid: false,
        ),
        isFalse,
      );
    });

    test('variant is unknown until the purchase is paid', () {
      expect(
        ChallengeReward.variant(
          purchase: const Purchase(
            challengeId: 'c',
            status: PurchaseStatus.pending,
            rewardVariant: RewardVariant.diploma,
          ),
          productVariant: RewardVariant.medalAndDiploma,
        ),
        isNull,
      );
      expect(
        ChallengeReward.variant(
          purchase: Purchase(
            challengeId: 'c',
            status: PurchaseStatus.paid,
            paidAt: DateTime(2026, 3, 11),
            rewardVariant: RewardVariant.diploma,
          ),
        ),
        RewardVariant.diploma,
      );
      expect(
        ChallengeReward.variant(
          purchase: Purchase(
            challengeId: 'c',
            status: PurchaseStatus.paid,
            paidAt: DateTime(2026, 3, 11),
          ),
          productVariant: RewardVariant.medalAndDiploma,
        ),
        RewardVariant.medalAndDiploma,
      );
    });

    test('formats dates in the active locale', () {
      final date = DateTime(2026, 9, 11);
      expect(formatLocalDate(date, 'cs'), '11. 9. 2026');
      expect(formatLocalDate(date, 'de'), '11. Sept. 2026');
      expect(formatLocalDate(date, 'en'), 'Sep 11, 2026');
    });

    test('formats SKU prices from challenge currency and locale', () {
      expect(
        formatChallengePrice(19900, 'czk', 'cs'),
        '199${priceThinSpace}Kč',
      );
      expect(
        formatChallengePrice(124900, 'czk', 'cs'),
        '1${priceThinSpace}249${priceThinSpace}Kč',
      );
      expect(formatChallengePrice(499, 'eur'), '€4.99');
      expect(formatChallengePrice(900, 'EUR'), '€9.00');
      expect(formatChallengePrice(499, 'eur', 'cs'), '4,99$priceThinSpace€');
      expect(formatChallengePrice(500, 'usd'), '5 USD');
      expect(formatChallengePrice(null, 'czk', 'cs'), isNull);
      expect(formatChallengePrice(0, 'czk', 'cs'), isNull);
      expect(formatChallengePrice(-19900, 'eur'), isNull);
    });

    test('SKU prices fall back to price_cents and expose checkout URLs', () {
      const fallback = Challenge(
        id: 'c',
        slug: 'c',
        accessMode: AccessMode.open,
        pricingType: PricingType.paid,
        priceCents: 499,
        currency: 'eur',
        status: PublishStatus.published,
        stripePriceId: 'price_legacy',
        translations: [LocalizedText(locale: 'en', title: 'C')],
      );
      expect(fallback.diplomaPriceCents, isNull);
      expect(fallback.medalPriceCents, isNull);
      expect(fallback.displayPriceCents(RewardVariant.diploma), 499);
      expect(fallback.displayPriceCents(RewardVariant.medalAndDiploma), isNull);
      expect(fallback.stripePriceIdFor(RewardVariant.diploma), 'price_legacy');
      expect(
        fallback.stripePriceIdFor(RewardVariant.medalAndDiploma),
        'price_legacy',
      );
      expect(fallback.fapiFormUrlFor(RewardVariant.diploma), isNull);
      expect(fallback.fapiFormUrlFor(RewardVariant.medalAndDiploma), isNull);

      const priced = Challenge(
        id: 'c',
        slug: 'c',
        accessMode: AccessMode.open,
        pricingType: PricingType.paid,
        priceCents: 499,
        diplomaPriceCents: 19900,
        medalPriceCents: 39900,
        currency: 'czk',
        status: PublishStatus.published,
        stripePriceId: 'price_legacy',
        fapiFormUrlDiploma: ' https://form.fapi.cz/diploma ',
        fapiFormUrlMedal: 'javascript:alert(1)',
        translations: [LocalizedText(locale: 'cs', title: 'C')],
      );
      expect(priced.priceCents, 499);
      expect(priced.displayPriceCents(RewardVariant.diploma), 19900);
      expect(priced.displayPriceCents(RewardVariant.medalAndDiploma), 39900);
      expect(priced.stripePriceIdFor(RewardVariant.diploma), 'price_legacy');
      expect(
        priced.stripePriceIdFor(RewardVariant.medalAndDiploma),
        'price_legacy',
      );
      expect(
        priced.fapiFormUrlFor(RewardVariant.diploma),
        'https://form.fapi.cz/diploma',
      );
      expect(priced.fapiFormUrlFor(RewardVariant.medalAndDiploma), isNull);
      expect(httpUrlOrNull(''), isNull);
      expect(httpUrlOrNull('   '), isNull);
      expect(httpUrlOrNull('/relative'), isNull);

      const zeroDiploma = Challenge(
        id: 'c',
        slug: 'c',
        accessMode: AccessMode.open,
        pricingType: PricingType.paid,
        priceCents: 499,
        diplomaPriceCents: 0,
        medalPriceCents: -10,
        currency: 'eur',
        status: PublishStatus.published,
        translations: [LocalizedText(locale: 'en', title: 'C')],
      );
      expect(zeroDiploma.displayPriceCents(RewardVariant.diploma), isNull);
      expect(
        zeroDiploma.displayPriceCents(RewardVariant.medalAndDiploma),
        isNull,
      );
    });

    test('memory catalog seeds expose both SKU prices', () {
      final story = sampleStoryChallenge().challenge;
      expect(story.diplomaPriceCents, 499);
      expect(story.medalPriceCents, 900);
      expect(story.priceCents, 499);
      expect(story.fapiFormUrlDiploma, 'https://form.fapi.cz/diploma-test');
      expect(story.fapiFormUrlMedal, 'https://form.fapi.cz/medal-test');
      final open = sampleOpenChallenge().challenge;
      expect(open.diplomaPriceCents, 0);
      expect(open.medalPriceCents, 0);
    });

    test('wire parsers read paidAt and reward variant', () {
      expect(rewardVariantFromWire('diploma'), RewardVariant.diploma);
      expect(
        rewardVariantFromWire('medal_and_diploma'),
        RewardVariant.medalAndDiploma,
      );
      expect(
        rewardVariantFromWire('medalAndDiploma'),
        RewardVariant.medalAndDiploma,
      );
      expect(RewardVariant.diploma.wire, 'diploma');
      expect(RewardVariant.medalAndDiploma.wire, 'medal_and_diploma');
      expect(rewardVariantFromWire(null), isNull);
      expect(dateTimeFromWire(null), isNull);
      expect(
        dateTimeFromWire('2026-03-11T08:00:00.000Z'),
        DateTime.parse('2026-03-11T08:00:00.000Z'),
      );
      final now = DateTime(2026, 3, 11);
      expect(dateTimeFromWire(now), now);
    });

    test('supabase mapping loads trimmed FAPI form URLs', () {
      final mapped = challengeFromRow({
        'id': 'c',
        'slug': 'c',
        'access_mode': 'open',
        'pricing_type': 'paid',
        'price_cents': 499,
        'diploma_price_cents': 19900,
        'medal_price_cents': 39900,
        'currency': 'czk',
        'status': 'published',
        'stripe_price_id': 'price_legacy',
        'stripe_price_id_diploma': 'not-a-column',
        'stripe_price_id_medal': 'not-a-column',
        'fapi_form_url_diploma': ' https://form.fapi.cz/d ',
        'fapi_form_url_medal': '',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'C', 'description': ''},
        ],
      });
      expect(mapped.stripePriceId, 'price_legacy');
      expect(mapped.stripePriceIdFor(RewardVariant.diploma), 'price_legacy');
      expect(mapped.fapiFormUrlDiploma, 'https://form.fapi.cz/d');
      expect(mapped.fapiFormUrlMedal, isNull);
      expect(
        mapped.fapiFormUrlFor(RewardVariant.diploma),
        'https://form.fapi.cz/d',
      );
      expect(mapped.fapiFormUrlFor(RewardVariant.medalAndDiploma), isNull);
      expect(mapped.displayPriceCents(RewardVariant.diploma), 19900);
      expect(mapped.displayPriceCents(RewardVariant.medalAndDiploma), 39900);
    });

    test('memory store stamps paidAt when the purchase is paid', () async {
      final store = MemoryPurchases();
      await store.startCheckout('open-1');
      expect(store.purchases['open-1']!.isPaid, isFalse);
      expect(store.purchases['open-1']!.paidAt, isNull);

      final paidAt = DateTime(2026, 3, 11, 10);
      final paid = store.pay(
        'open-1',
        paidAt: paidAt,
        rewardVariant: RewardVariant.medalAndDiploma,
      );
      expect(paid.isPaid, isTrue);
      expect(paid.paidAt, paidAt);
      expect(paid.rewardVariant, RewardVariant.medalAndDiploma);

      final pending = MemoryPurchases();
      await pending.startCheckout('open-1');
      final refreshed = await pending.refreshPurchase('open-1');
      expect(refreshed!.isPaid, isTrue);
      expect(refreshed.paidAt, isNotNull);
      expect(refreshed.rewardVariant, RewardVariant.diploma);
    });

    test('checkout persists the chosen reward variant through pay', () async {
      final diploma = MemoryPurchases();
      await diploma.startCheckout(
        'open-1',
        rewardVariant: RewardVariant.diploma,
      );
      expect(diploma.purchases['open-1']!.rewardVariant, RewardVariant.diploma);
      expect(
        (await diploma.refreshPurchase('open-1'))!.rewardVariant,
        RewardVariant.diploma,
      );

      final medal = MemoryPurchases();
      await medal.startCheckout(
        'story-1',
        rewardVariant: RewardVariant.medalAndDiploma,
      );
      expect(
        medal.purchases['story-1']!.rewardVariant,
        RewardVariant.medalAndDiploma,
      );
      expect(
        (await medal.refreshPurchase('story-1'))!.rewardVariant,
        RewardVariant.medalAndDiploma,
      );
    });
  });

  group('challenge detail UI', () {
    testWidgets('unpaid deadline is muted with no fake date', (tester) async {
      useTallView(tester);
      final strings = AppStrings('cs');
      await tester.pumpWidget(wrapScreen(buildServices()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-deadline-banner')),
      );
      expect(find.text(strings.deadlineAfterPayment), findsOneWidget);
      expect(find.text(strings.deadlineCompleteBy), findsNothing);
      expect(find.byKey(const Key('challenge-deadline-date')), findsNothing);
    });

    testWidgets('paid deadline shows the local complete-by date', (
      tester,
    ) async {
      useTallView(tester);
      final strings = AppStrings('en');
      final paidAt = DateTime(2026, 3, 11);
      final purchases = MemoryPurchases()
        ..pay('open-1', paidAt: paidAt, rewardVariant: RewardVariant.diploma);
      await tester.pumpWidget(
        wrapScreen(buildServices(purchases: purchases), locale: 'en'),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-deadline-date')),
      );
      expect(find.text(strings.deadlineCompleteBy), findsOneWidget);
      expect(find.text(strings.deadlineAfterPayment), findsNothing);
      expect(find.text('Sep 11, 2026'), findsOneWidget);
    });

    testWidgets(
      'title, map, description, pay, planner, then places sit above deadline and reward',
      (tester) async {
        useTallView(tester);
        final strings = AppStrings('en');
        await tester.pumpWidget(wrapScreen(buildServices(), locale: 'en'));
        await tester.pumpAndSettle();

        final titleY = tester
            .getTopLeft(find.byKey(const Key('challenge-title')))
            .dy;
        final progressY = tester
            .getTopLeft(find.byKey(const Key('challenge-progress')))
            .dy;
        final mapY = tester.getTopLeft(find.byType(ChallengeMap)).dy;
        final plannerY = tester.getTopLeft(find.byType(RoutePlannerPanel)).dy;
        final infoY = tester
            .getTopLeft(find.byKey(const Key('challenge-info')))
            .dy;
        final waypointsY = tester.getTopLeft(find.text(strings.waypoints)).dy;
        final deadlineY = tester
            .getTopLeft(find.byKey(const Key('challenge-deadline-banner')))
            .dy;
        final rewardY = tester
            .getTopLeft(find.byKey(const Key('challenge-reward-section')))
            .dy;
        expect(titleY, lessThan(progressY));
        expect(progressY, lessThan(mapY));
        expect(mapY, lessThan(infoY));
        expect(infoY, lessThan(plannerY));
        expect(plannerY, lessThan(waypointsY));
        expect(waypointsY, lessThan(deadlineY));
        expect(deadlineY, lessThan(rewardY));
        expect(find.byKey(const Key('challenge-unlock-cta')), findsNothing);
        expect(find.byKey(const Key('challenge-pay-ctas')), findsOneWidget);
        expect(find.text(strings.payDigitalDiploma), findsNWidgets(2));
        expect(find.text(strings.payMedalAndDiploma), findsNWidgets(2));
        final payY = tester
            .getTopLeft(find.byKey(const Key('challenge-pay-ctas')))
            .dy;
        expect(infoY, lessThan(payY));
        expect(payY, lessThan(plannerY));
        expect(payY, lessThan(waypointsY));
        final info = tester.widget<Text>(
          find.byKey(const Key('challenge-info')),
        );
        expect(info.textAlign, TextAlign.center);
        final card = tester.widget<Material>(
          find.byKey(const Key('challenge-description')),
        );
        expect(card.color, BrandColors.cream);
        expect(
          (card.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(AppTheme.radiusCard),
        );
        expect(find.text('Visit any stop'), findsOneWidget);
        expect(find.text('Open trail'), findsOneWidget);
        expect(find.text(strings.waypoints), findsOneWidget);
      },
    );

    testWidgets(
      'wide layout puts the description and pay block under the side map',
      (tester) async {
        useView(tester, width: 1280, height: 900);
        final strings = AppStrings('en');
        await tester.pumpWidget(wrapScreen(buildServices(), locale: 'en'));
        await tester.pumpAndSettle();

        final map = tester.getRect(find.byType(ChallengeMap));
        final description = tester.getRect(
          find.byKey(const Key('challenge-description')),
        );
        final heading = tester.getRect(
          find.byKey(const Key('challenge-pay-heading')),
        );
        final progress = tester.getRect(
          find.byKey(const Key('challenge-progress')),
        );
        final planner = tester.getRect(find.byType(RoutePlannerPanel));
        final places = tester.getRect(find.text(strings.waypoints));
        expect(map.right, lessThanOrEqualTo(640));
        expect(description.top, greaterThanOrEqualTo(map.bottom - 1));
        expect(description.center.dx, inInclusiveRange(map.left, map.right));
        expect(heading.top - description.bottom, closeTo(40, 1));
        expect(heading.center.dx, lessThan(map.right));
        expect(progress.left, greaterThanOrEqualTo(map.right - 1));
        expect(progress.top, lessThan(planner.top));
        expect(planner.left, greaterThanOrEqualTo(map.right - 1));
        expect(planner.top, lessThan(places.top));

        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('challenge-feed-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          scrollable.position.maxScrollExtent,
          greaterThanOrEqualTo(scrollable.position.viewportDimension * 0.5),
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
          const Offset(0, 1),
        );
      },
    );

    testWidgets(
      'info, then side-by-side pay CTAs, then places sit above deadline and reward',
      (tester) async {
        useTallView(tester);
        final strings = AppStrings('en');
        final story = sampleStoryChallenge();
        await tester.pumpWidget(
          wrapScreen(
            buildServices(detail: story),
            locale: 'en',
            challengeId: 'story-1',
          ),
        );
        await tester.pumpAndSettle();

        final infoY = tester
            .getTopLeft(find.byKey(const Key('challenge-info')))
            .dy;
        final mapY = tester.getTopLeft(find.byType(ChallengeMap)).dy;
        final plannerY = tester.getTopLeft(find.byType(RoutePlannerPanel)).dy;
        final waypointsY = tester.getTopLeft(find.text(strings.waypoints)).dy;
        final diploma = tester.getRect(
          find.byKey(const Key('challenge-pay-diploma')),
        );
        final medal = tester.getRect(
          find.byKey(const Key('challenge-pay-medal')),
        );
        final deadlineY = tester
            .getTopLeft(find.byKey(const Key('challenge-deadline-banner')))
            .dy;
        final rewardY = tester
            .getTopLeft(find.byKey(const Key('challenge-reward-section')))
            .dy;
        expect(find.text('Unlock in order'), findsOneWidget);
        expect(find.text(strings.challengeLockedPaid), findsNothing);
        expect(find.text(strings.waypoints), findsOneWidget);
        expect(find.text(strings.payDigitalDiploma), findsNWidgets(2));
        expect(find.text(strings.payMedalAndDiploma), findsNWidgets(2));
        expect(find.text('€4.99'), findsNothing);
        expect(find.text('€9.00'), findsNothing);
        expect(find.text(strings.unlockWithStripe), findsNothing);
        expect(find.byKey(const Key('challenge-pay-trust')), findsNothing);
        final heading = tester.widget<Text>(
          find.byKey(const Key('challenge-pay-heading')),
        );
        expect(heading.data, strings.joinChallenge);
        expect(heading.textAlign, TextAlign.center);
        expect(
          (diploma.left + medal.right) / 2,
          closeTo(tester.view.physicalSize.width / 2, 8),
        );
        expect(
          tester.getCenter(find.byKey(const Key('challenge-pay-heading'))).dx,
          closeTo((diploma.left + medal.right) / 2, 1),
        );
        expect(heading.style?.fontFamily, 'Onest');
        expect(heading.style?.fontWeight, FontWeight.w700);
        expect(heading.style?.fontSize, 32);
        expect(heading.style?.height, 1.2);
        expect(heading.style?.color, BrandColors.forest);
        expect(
          tester.getTopLeft(find.byKey(const Key('challenge-pay-heading'))).dy -
              tester
                  .getBottomLeft(find.byKey(const Key('challenge-description')))
                  .dy,
          closeTo(40, 1),
        );
        expect(mapY, lessThan(infoY));
        expect(infoY, lessThan(diploma.top));
        expect(medal.bottom, lessThan(plannerY));
        expect(plannerY, lessThan(waypointsY));
        expect(medal.bottom, lessThan(waypointsY));
        expect(diploma.left, lessThan(medal.left));
        expect((diploma.center.dy - medal.center.dy).abs(), lessThan(1));
        expect(medal.left - diploma.right, closeTo(12, 0.5));
        expect(medal.right - diploma.left, closeTo(440, 1));
        expect(
          diploma.top -
              tester
                  .getBottomLeft(find.byKey(const Key('challenge-pay-heading')))
                  .dy,
          closeTo(20, 1),
        );
        expect(diploma.height, greaterThanOrEqualTo(52));
        expect(medal.height, greaterThanOrEqualTo(52));
        expect((diploma.height - medal.height).abs(), lessThan(1));
        expect((diploma.width - medal.width).abs(), lessThan(1));
        expect(waypointsY, lessThan(deadlineY));
        expect(deadlineY, lessThan(rewardY));
        expect(
          tester.widget(find.byKey(const Key('challenge-pay-ctas'))),
          isA<Column>(),
        );

        final diplomaButton = tester.widget<OutlinedButton>(
          find.descendant(
            of: find.byKey(const Key('challenge-pay-diploma')),
            matching: find.byType(OutlinedButton),
          ),
        );
        final medalButton = tester.widget<FilledButton>(
          find.descendant(
            of: find.byKey(const Key('challenge-pay-medal')),
            matching: find.byType(FilledButton),
          ),
        );
        final diplomaLabel = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('challenge-pay-diploma')),
            matching: find.text(strings.payDigitalDiploma),
          ),
        );
        final medalLabel = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('challenge-pay-medal')),
            matching: find.text(strings.payMedalAndDiploma),
          ),
        );
        expect(diplomaLabel.maxLines, 1);
        expect(diplomaLabel.textAlign, TextAlign.center);
        expect(diplomaLabel.style?.fontSize, 16);
        expect(diplomaLabel.style?.fontWeight, FontWeight.w600);
        expect(diplomaLabel.style?.letterSpacing, 0.1);
        expect(medalLabel.maxLines, 1);
        expect(medalLabel.textAlign, TextAlign.center);
        expect(medalLabel.style?.fontSize, 16);
        expect(medalLabel.style?.fontWeight, FontWeight.w600);
        expect(
          diplomaButton.style?.backgroundColor?.resolve(const {}),
          BrandColors.cream,
        );
        expect(
          diplomaButton.style?.foregroundColor?.resolve(const {}),
          BrandColors.forest,
        );
        expect(
          diplomaButton.style?.side?.resolve(const {}),
          const BorderSide(color: BrandColors.forest, width: 1.5),
        );
        expect(diplomaButton.style?.elevation?.resolve(const {}), 0);
        expect(
          diplomaButton.style?.overlayColor?.resolve({WidgetState.pressed}),
          BrandColors.forest.withValues(alpha: 0.10),
        );
        expect(
          medalButton.style?.backgroundColor?.resolve(const {}),
          BrandColors.forest,
        );
        expect(
          medalButton.style?.foregroundColor?.resolve(const {}),
          BrandColors.cream,
        );
        expect(medalButton.style?.side?.resolve(const {}), BorderSide.none);
        expect(medalButton.style?.elevation?.resolve(const {}), 0);
        expect(
          medalButton.style?.overlayColor?.resolve({WidgetState.pressed}),
          BrandColors.cream.withValues(alpha: 0.12),
        );
        expect(
          medalButton.style?.backgroundColor?.resolve({WidgetState.pressed}),
          BrandColors.forest,
        );
        expect(
          diplomaButton.style?.shape?.resolve(const {}),
          isA<StadiumBorder>(),
        );
        expect(
          medalButton.style?.shape?.resolve(const {}),
          isA<StadiumBorder>(),
        );
        expect(
          diplomaButton.style?.padding?.resolve(const {}),
          const EdgeInsets.symmetric(horizontal: 24),
        );
        expect(
          medalButton.style?.padding?.resolve(const {}),
          const EdgeInsets.symmetric(horizontal: 24),
        );
      },
    );

    testWidgets('pay CTAs use Czech product labels', (tester) async {
      useTallView(tester);
      final story = sampleStoryChallenge();
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story),
          locale: 'cs',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Digitální diplom'), findsNWidgets(2));
      expect(find.text('Medaile + diplom'), findsNWidgets(2));
      expect(find.text('Přijmi výzvu'), findsNWidgets(2));
      expect(find.text('4,99$priceThinSpace€'), findsNothing);
      expect(find.text('9,00$priceThinSpace€'), findsNothing);
    });

    testWidgets('pay CTAs format the FAPI offer and ignore CMS cents', (
      tester,
    ) async {
      useTallView(tester);
      final story = sampleStoryChallenge();
      final czk = ChallengeDetail(
        challenge: Challenge(
          id: story.challenge.id,
          slug: story.challenge.slug,
          accessMode: story.challenge.accessMode,
          pricingType: PricingType.free,
          priceCents: 1,
          diplomaPriceCents: 1,
          medalPriceCents: 1,
          currency: 'eur',
          status: story.challenge.status,
          translations: story.challenge.translations,
          fapiFormUrlDiploma: story.challenge.fapiFormUrlDiploma,
          fapiFormUrlMedal: story.challenge.fapiFormUrlMedal,
        ),
        waypoints: story.waypoints,
      );
      final purchases = MemoryPurchases()
        ..offer = const FapiOffer(
          diploma: FapiOfferVariant(priceCents: 124900, currency: 'czk'),
          medal: FapiOfferVariant(priceCents: 39900, currency: 'czk'),
        );
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: czk, purchases: purchases),
          locale: 'cs',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('1${priceThinSpace}249${priceThinSpace}Kč'),
        findsNothing,
      );
      expect(find.text('399${priceThinSpace}Kč'), findsNothing);
      expect(find.text('0,01$priceThinSpace€'), findsNothing);
      expect(find.text('Digitální diplom'), findsNWidgets(2));
      expect(find.text('Medaile + diplom'), findsNWidgets(2));
    });

    testWidgets('a FAPI price of 0 is shown as free on both buttons', (
      tester,
    ) async {
      useTallView(tester);
      final strings = AppStrings('cs');
      final story = sampleStoryChallenge();
      final priced = ChallengeDetail(
        challenge: Challenge(
          id: story.challenge.id,
          slug: story.challenge.slug,
          accessMode: story.challenge.accessMode,
          pricingType: PricingType.free,
          priceCents: 19900,
          diplomaPriceCents: 19900,
          medalPriceCents: 39900,
          currency: 'czk',
          status: story.challenge.status,
          translations: story.challenge.translations,
          fapiFormUrlDiploma: story.challenge.fapiFormUrlDiploma,
          fapiFormUrlMedal: story.challenge.fapiFormUrlMedal,
        ),
        waypoints: story.waypoints,
      );
      final purchases = MemoryPurchases()
        ..offer = const FapiOffer(
          diploma: FapiOfferVariant(
            priceCents: 0,
            currency: 'czk',
            termsUrl: 'https://form.fapi.cz/terms',
          ),
          medal: FapiOfferVariant(priceCents: 0, currency: 'czk'),
        );
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: priced, purchases: purchases),
          locale: 'cs',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('challenge-pay-diploma')), findsOneWidget);
      expect(find.byKey(const Key('challenge-pay-medal')), findsOneWidget);
      expect(find.text(strings.payPriceFree), findsNothing);
      expect(find.text('199${priceThinSpace}Kč'), findsNothing);
      expect(find.text('399${priceThinSpace}Kč'), findsNothing);
      expect(find.byKey(const Key('challenge-pay-terms')), findsNothing);
      expect(find.text('https://form.fapi.cz/terms'), findsNothing);
    });

    testWidgets('pay CTAs show a fallback when fapi-offer fails', (
      tester,
    ) async {
      useTallView(tester);
      final strings = AppStrings('en');
      final story = sampleStoryChallenge();
      final purchases = MemoryPurchases()..offerFails = true;
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story, purchases: purchases),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('challenge-pay-diploma')), findsOneWidget);
      expect(find.byKey(const Key('challenge-pay-medal')), findsOneWidget);
      expect(find.text(strings.payPriceUnavailable), findsNothing);
      expect(find.text('€4.99'), findsNothing);
      expect(find.text('€9.00'), findsNothing);
    });

    testWidgets('pay CTAs show a loading price until fapi-offer returns', (
      tester,
    ) async {
      useTallView(tester);
      final strings = AppStrings('en');
      final story = sampleStoryChallenge();
      final gate = Completer<FapiOffer>();
      final purchases = MemoryPurchases()..offerGate = gate;
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story, purchases: purchases),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('challenge-pay-diploma')), findsOneWidget);
      expect(find.byKey(const Key('challenge-pay-medal')), findsOneWidget);
      expect(
        find.byKey(const Key('challenge-pay-diploma-price-loading')),
        findsNothing,
      );
      expect(find.text('€4.99'), findsNothing);
      expect(find.text(strings.payPriceLoading), findsNothing);

      gate.complete(memoryFapiOffer);
      await tester.pumpAndSettle();
      expect(find.text('€4.99'), findsNothing);
      expect(find.text('€9.00'), findsNothing);
    });

    testWidgets(
      'a pending purchase is the only line under the centered buttons',
      (tester) async {
        useTallView(tester);
        final strings = AppStrings('en');
        final story = sampleStoryChallenge();
        final purchases = MemoryPurchases(
          completeOnRefresh: false,
          purchases: {
            story.challenge.id: Purchase(
              challengeId: story.challenge.id,
              status: PurchaseStatus.pending,
              rewardVariant: RewardVariant.diploma,
            ),
          },
        );
        await tester.pumpWidget(
          wrapScreen(
            buildServices(detail: story, purchases: purchases),
            locale: 'en',
            challengeId: story.challenge.id,
          ),
        );
        await tester.pumpAndSettle();

        final note = tester.widget<Text>(
          find.byKey(const Key('challenge-pay-pending')),
        );
        expect(note.data, strings.purchasePending);
        expect(note.textAlign, TextAlign.center);
        expect(note.style?.color, BrandColors.bark);
        expect(note.style?.fontSize, AppTheme.captionSize);
        expect(find.text(strings.purchasePending), findsOneWidget);
        expect(find.byKey(const Key('challenge-pay-terms')), findsNothing);
        expect(find.byKey(const Key('challenge-pay-trust')), findsNothing);
        final diploma = tester.getRect(
          find.byKey(const Key('challenge-pay-diploma')),
        );
        final medal = tester.getRect(
          find.byKey(const Key('challenge-pay-medal')),
        );
        final pending = tester.getRect(
          find.byKey(const Key('challenge-pay-pending')),
        );
        expect(pending.top, greaterThan(medal.bottom));
        expect(pending.center.dx, closeTo((diploma.left + medal.right) / 2, 1));
        expect(
          find.descendant(
            of: find.byKey(const Key('challenge-payment-bar')),
            matching: find.byKey(const Key('challenge-pay-pending')),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('pay CTAs use German product labels', (tester) async {
      useTallView(tester);
      final story = sampleStoryChallenge();
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story),
          locale: 'de',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Digitales Diplom'), findsNWidgets(2));
      expect(find.text('Medaille + Diplom'), findsNWidgets(2));
      expect(find.text('Nimm die Herausforderung an'), findsNWidgets(2));
    });

    testWidgets('the payment buttons float as a centered pair', (tester) async {
      useView(tester, width: 390);
      final story = sampleStoryChallenge();
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget(find.byKey(const Key('challenge-floating-pay-ctas'))),
        isA<Row>(),
      );
      expect(find.text('Accept the challenge'), findsNWidgets(2));
      final floatingHeading = tester.widget<Text>(
        find.byKey(const Key('challenge-paybar-heading')),
      );
      expect(floatingHeading.textAlign, TextAlign.center);
      expect(floatingHeading.style?.fontFamily, AppTheme.displayFont);
      expect(floatingHeading.style?.fontWeight, FontWeight.w700);
      expect(floatingHeading.style?.fontSize, ChallengeCtaPanel.headingSize);
      expect(
        floatingHeading.style?.height,
        ChallengeCtaPanel.headingLineHeight / ChallengeCtaPanel.headingSize,
      );
      expect(floatingHeading.style?.color, BrandColors.forest);
      expect(
        tester.widget(find.byKey(const Key('challenge-payment-bar'))),
        isA<Padding>(),
      );
      final diploma = tester.getRect(
        find.byKey(const Key('challenge-floating-pay-diploma')),
      );
      final medal = tester.getRect(
        find.byKey(const Key('challenge-floating-pay-medal')),
      );
      expect(diploma.right, lessThanOrEqualTo(medal.left));
      expect(medal.left - diploma.right, ChallengePaymentBarMetrics.rowGap);
      expect(diploma.width, closeTo(medal.width, 0.5));
      expect((diploma.left + medal.right) / 2, closeTo(195, 1));
      expect(diploma.height, ChallengePaymentBarMetrics.tapTarget);
      expect(medal.height, ChallengePaymentBarMetrics.tapTarget);
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byKey(const Key('challenge-floating-pay-diploma')),
                matching: find.byType(Material),
              ),
            )
            .height,
        ChallengePaymentBarMetrics.visualHeight,
      );
      final bar = tester.getRect(
        find.byKey(const Key('challenge-payment-bar')),
      );
      expect(bar.left, 0);
      expect(bar.right, 390);
      expect(bar.height, ChallengePaymentBarMetrics.bodyHeight(390));
      expect(
        diploma.top - bar.top,
        closeTo(
          ChallengePaymentBarMetrics.topPadding +
              tester
                  .getSize(find.byKey(const Key('challenge-paybar-heading')))
                  .height +
              ChallengePaymentBarMetrics.headingGap,
          1,
        ),
      );
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('challenge-floating-pay-diploma')),
          matching: find.text('Digital diploma'),
        ),
      );
      expect(
        label.style?.fontSize,
        inInclusiveRange(
          ChallengePaymentBarMetrics.minLabelSize,
          ChallengePaymentBarMetrics.labelSize,
        ),
      );
      expect(label.style?.fontWeight, FontWeight.w600);
      expect(
        label.style?.letterSpacing,
        ChallengePaymentBarMetrics.letterSpacing,
      );
      expect(label.maxLines, 1);
      expect(
        find.descendant(
          of: find.byKey(const Key('challenge-floating-pay-diploma')),
          matching: find.byWidgetPredicate(
            (widget) => widget is FittedBox && widget.fit == BoxFit.scaleDown,
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: find.byKey(const Key('challenge-floating-pay-diploma')),
                matching: find.byType(OutlinedButton),
              ),
            )
            .style
            ?.shape
            ?.resolve(const {}),
        isA<StadiumBorder>(),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: find.byKey(const Key('challenge-floating-pay-diploma')),
                matching: find.byType(OutlinedButton),
              ),
            )
            .style
            ?.tapTargetSize,
        MaterialTapTargetSize.padded,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('challenge-payment-spacer')))
            .height,
        ChallengePaymentBarMetrics.occupiedHeight(390, 0),
      );
    });

    testWidgets('the payment bar stays a row at 340 dp', (tester) async {
      useView(tester, width: 360);
      final story = sampleStoryChallenge();
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget(find.byKey(const Key('challenge-floating-pay-ctas'))),
        isA<Row>(),
      );
      final diploma = tester.getRect(
        find.byKey(const Key('challenge-floating-pay-diploma')),
      );
      final medal = tester.getRect(
        find.byKey(const Key('challenge-floating-pay-medal')),
      );
      expect(diploma.right, lessThanOrEqualTo(medal.left));
      expect(medal.left - diploma.right, ChallengePaymentBarMetrics.rowGap);
      expect((diploma.height - medal.height).abs(), lessThan(1));
      expect(diploma.width, closeTo(medal.width, 0.5));
      expect(diploma.height, ChallengePaymentBarMetrics.tapTarget);
      final outlined = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const Key('challenge-floating-pay-diploma')),
          matching: find.byType(OutlinedButton),
        ),
      );
      final filled = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('challenge-floating-pay-medal')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(outlined.style?.elevation?.resolve(const {}), 0);
      expect(filled.style?.elevation?.resolve(const {}), 0);
      expect(filled.style?.shadowColor?.resolve(const {}), Colors.transparent);
      expect(
        filled.style?.surfaceTintColor?.resolve(const {}),
        Colors.transparent,
      );
      expect(filled.style?.elevation?.resolve({WidgetState.disabled}), 0);
    });

    testWidgets(
      'a narrow in-page block stacks the medal button above the diploma',
      (tester) async {
        useView(tester, width: 360, height: 900);
        final story = sampleStoryChallenge();
        await tester.pumpWidget(
          wrapScreen(
            buildServices(detail: story),
            locale: 'de',
            challengeId: 'story-1',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget(find.byKey(const Key('challenge-pay-ctas'))),
          isA<Column>(),
        );
        final inlineMedal = tester.getRect(
          find.byKey(const Key('challenge-pay-medal')),
        );
        final inlineDiploma = tester.getRect(
          find.byKey(const Key('challenge-pay-diploma')),
        );
        expect(inlineMedal.bottom, lessThan(inlineDiploma.top));
        expect(inlineDiploma.top - inlineMedal.bottom, closeTo(8, 1));
        expect(find.text('Nimm die Herausforderung an'), findsWidgets);
      },
    );

    test('the floating panel stacks under 360 and clears the nav', () {
      expect(ChallengeCtaPanel.buttonsStack(359), isTrue);
      expect(ChallengeCtaPanel.buttonsStack(360), isFalse);
      expect(ChallengeCtaPanel.bottomMargin(390), ChallengeCtaPanel.aboveNav);
      expect(
        ChallengeCtaPanel.bottomMargin(600),
        ChallengeCtaPanel.restingBottom,
      );
      expect(ChallengeCtaPanel.rowGap, 32);
      expect(ChallengeCtaPanel.stackGap, 12);
    });

    test('payment bar labels scale from 15 down to 14 and stop', () {
      expect(paymentBarLabelFontSize(textWidth: 100, maxWidth: 100), 15);
      expect(
        paymentBarLabelFontSize(textWidth: 100, maxWidth: 96),
        closeTo(14.4, 0.001),
      );
      expect(paymentBarLabelFontSize(textWidth: 100, maxWidth: 50), 14);
    });

    testWidgets(
      'a loading button keeps its width and a scaled German label fits',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 168,
                    child: AppButton(
                      label: 'Medaille + Diplom',
                      loading: true,
                      loadingLabel: 'Wird geladen',
                      size: AppButtonSize.m,
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(AppButton)).width, 168);
        expect(
          tester.getSize(find.byType(CircularProgressIndicator)),
          const Size(18, 18),
        );
        expect(find.bySemanticsLabel('Wird geladen'), findsOneWidget);
        final idle = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(idle.onPressed, isNull);
        semantics.dispose();
      },
    );

    testWidgets('a disabled payment bar button is forest at 40 percent', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      useView(tester, width: 390, height: 844);
      final story = sampleStoryChallenge();
      final missingMedal = ChallengeDetail(
        challenge: Challenge(
          id: story.challenge.id,
          slug: story.challenge.slug,
          accessMode: story.challenge.accessMode,
          pricingType: story.challenge.pricingType,
          priceCents: story.challenge.priceCents,
          diplomaPriceCents: story.challenge.diplomaPriceCents,
          medalPriceCents: story.challenge.medalPriceCents,
          currency: story.challenge.currency,
          status: story.challenge.status,
          translations: story.challenge.translations,
          fapiFormUrlDiploma: story.challenge.fapiFormUrlDiploma,
          fapiFormUrlMedal: '',
        ),
        waypoints: story.waypoints,
      );
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: missingMedal),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('challenge-feed-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        Offset.zero,
        reason: 'the floating panel has to be on screen for its semantics',
      );

      final muted = BrandColors.forest.withValues(alpha: 0.4);
      final medal = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('challenge-floating-pay-medal')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(medal.onPressed, isNull);
      expect(
        medal.style?.backgroundColor?.resolve({WidgetState.disabled}),
        muted,
      );
      expect(
        medal.style?.foregroundColor?.resolve({WidgetState.disabled}),
        BrandColors.cream.withValues(alpha: 0.7),
      );
      expect(medal.style?.elevation?.resolve({WidgetState.disabled}), 0);
      expect(
        medal.style?.shadowColor?.resolve({WidgetState.disabled}),
        Colors.transparent,
      );
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('challenge-floating-pay-medal')),
          matching: find.text('Medal + diploma'),
        ),
      );
      expect(label.style?.fontWeight, FontWeight.w600);
      expect(
        tester
            .getSemantics(find.byKey(const Key('challenge-floating-pay-medal')))
            .flagsCollection
            .isEnabled,
        Tristate.isFalse,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: find.byKey(const Key('challenge-floating-pay-diploma')),
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      semantics.dispose();
    });

    testWidgets('tapping a pay CTA opens in-app checkout for that variant', (
      tester,
    ) async {
      useTallView(tester);
      final opened = <Uri>[];
      final purchases = MemoryPurchases(completeOnRefresh: false);
      final story = sampleStoryChallenge();
      await tester.pumpWidget(
        wrapScreen(
          buildServices(
            detail: story,
            purchases: purchases,
            openUrl: (uri) async => opened.add(uri),
          ),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('challenge-pay-medal')));
      await tester.tap(find.byKey(const Key('challenge-pay-medal')));
      await tester.pumpAndSettle();

      expect(purchases.purchases['story-1']!.isPaid, isFalse);
      expect(purchases.purchases['story-1']!.status, PurchaseStatus.pending);
      expect(
        purchases.purchases['story-1']!.rewardVariant,
        RewardVariant.medalAndDiploma,
      );
      expect(opened, isEmpty);
      expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);
      expect(
        find.text(fapiCheckoutUrlFor(RewardVariant.medalAndDiploma)),
        findsOneWidget,
      );
      expect(find.text(AppStrings('en').paymentTitle), findsOneWidget);
    });

    testWidgets('diploma CTA opens the diploma FAPI form in a WebView', (
      tester,
    ) async {
      useTallView(tester);
      final opened = <Uri>[];
      final purchases = MemoryPurchases(completeOnRefresh: false);
      final story = sampleStoryChallenge();
      await tester.pumpWidget(
        wrapScreen(
          buildServices(
            detail: story,
            purchases: purchases,
            openUrl: (uri) async => opened.add(uri),
          ),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-pay-diploma')),
      );
      await tester.tap(find.byKey(const Key('challenge-pay-diploma')));
      await tester.pumpAndSettle();

      expect(purchases.purchases['story-1']!.isPaid, isFalse);
      expect(purchases.purchases['story-1']!.status, PurchaseStatus.pending);
      expect(
        purchases.purchases['story-1']!.rewardVariant,
        RewardVariant.diploma,
      );
      expect(opened, isEmpty);
      expect(find.byKey(const Key('payment-checkout-dialog')), findsOneWidget);
      expect(find.byKey(const Key('payment-checkout-close')), findsOneWidget);
      expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);
      final dialog = tester.getSize(
        find.byKey(const Key('payment-checkout-dialog')),
      );
      expect(dialog.width, 560);
      expect(dialog.height, 860);
      expect(
        find.text(fapiCheckoutUrlFor(RewardVariant.diploma)),
        findsOneWidget,
      );
      expect(find.text(AppStrings('en').paymentTitle), findsOneWidget);
      expect(find.text(AppStrings('en').congratulations), findsNothing);
    });

    testWidgets('paid webhook after FAPI submit shows success then refreshes', (
      tester,
    ) async {
      useTallView(tester);
      final strings = AppStrings('en');
      final purchases = MemoryPurchases();
      final story = sampleStoryChallenge();
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story, purchases: purchases),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-pay-diploma')),
      );
      await tester.tap(find.byKey(const Key('challenge-pay-diploma')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);
      expect(find.byKey(const Key('payment-success')), findsNothing);

      await tester.tap(find.byKey(const Key('payment-fake-submit')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('payment-success')), findsOneWidget);
      expect(find.text(strings.paymentSuccessTitle), findsOneWidget);
      expect(purchases.purchases['story-1']!.isPaid, isTrue);

      await tester.tap(find.byKey(const Key('payment-back-to-challenge')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('challenge-pay-ctas')), findsNothing);
      expect(find.byKey(const Key('challenge-pay-deadline')), findsOneWidget);
      expect(find.text(strings.purchasePending), findsNothing);
      expect(find.text(strings.congratulations), findsNothing);
      expect(find.text(strings.deadlineCompleteBy), findsOneWidget);
      expect(
        find.byKey(const Key('challenge-reward-incomplete')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('challenge-reward-lock')), findsNothing);
    });

    testWidgets('pay CTA without a FAPI form URL is disabled and is a no-op', (
      tester,
    ) async {
      useTallView(tester);
      final opened = <Uri>[];
      final purchases = MemoryPurchases(completeOnRefresh: false);
      final story = sampleStoryChallenge();
      final missingMedal = ChallengeDetail(
        challenge: Challenge(
          id: story.challenge.id,
          slug: story.challenge.slug,
          accessMode: story.challenge.accessMode,
          pricingType: story.challenge.pricingType,
          priceCents: story.challenge.priceCents,
          diplomaPriceCents: story.challenge.diplomaPriceCents,
          medalPriceCents: story.challenge.medalPriceCents,
          currency: story.challenge.currency,
          status: story.challenge.status,
          translations: story.challenge.translations,
          fapiFormUrlDiploma: story.challenge.fapiFormUrlDiploma,
          fapiFormUrlMedal: '',
        ),
        waypoints: story.waypoints,
      );
      await tester.pumpWidget(
        wrapScreen(
          buildServices(
            detail: missingMedal,
            purchases: purchases,
            openUrl: (uri) async => opened.add(uri),
          ),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();

      final diploma = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const Key('challenge-pay-diploma')),
          matching: find.byType(OutlinedButton),
        ),
      );
      final medal = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('challenge-pay-medal')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(diploma.onPressed, isNotNull);
      expect(medal.onPressed, isNull);
      expect(find.text('€4.99'), findsNothing);
      expect(find.text('€9.00'), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('challenge-pay-medal')));
      await tester.tap(find.byKey(const Key('challenge-pay-medal')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(purchases.purchases.containsKey('story-1'), isFalse);
    });

    testWidgets('free challenge shows pay buttons and a locked diploma', (
      tester,
    ) async {
      useTallView(tester);
      final strings = AppStrings('cs');
      await tester.pumpWidget(wrapScreen(buildServices()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-reward-section')),
      );
      expect(find.text(strings.rewardTitle), findsOneWidget);
      expect(find.byKey(const Key('challenge-pay-ctas')), findsOneWidget);
      expect(find.text(strings.payDigitalDiploma), findsNWidgets(2));
      expect(find.text(strings.payMedalAndDiploma), findsNWidgets(2));
      expect(find.byKey(const Key('challenge-reward-lock')), findsOneWidget);
      expect(
        find.byKey(const Key('challenge-reward-lock-overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('challenge-reward-incomplete')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('challenge-reward-diploma-texture')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('challenge-reward-diploma-blur')),
        findsNothing,
      );
      expect(find.byKey(const Key('challenge-reward-diploma')), findsOneWidget);
      expect(find.byKey(const Key('challenge-reward-medal')), findsNothing);
      expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);
      expect(find.text(strings.rewardUnlocksAfterComplete), findsOneWidget);
      expect(find.text(strings.diplomaLabel), findsOneWidget);
      expect(find.byKey(const Key('challenge-save-diploma')), findsNothing);
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const Key('challenge-reward-guard')),
            )
            .ignoring,
        isTrue,
      );
    });

    testWidgets('paid diploma-only locked reward hides the medal slot', (
      tester,
    ) async {
      useTallView(tester);
      final purchases = MemoryPurchases()
        ..pay(
          'open-1',
          paidAt: DateTime(2026, 3, 11),
          rewardVariant: RewardVariant.diploma,
        );
      await tester.pumpWidget(wrapScreen(buildServices(purchases: purchases)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-reward-section')),
      );
      expect(find.byKey(const Key('challenge-reward-diploma')), findsOneWidget);
      expect(find.byKey(const Key('challenge-reward-medal')), findsNothing);
      expect(find.byKey(const Key('challenge-reward-lock')), findsNothing);
      expect(
        find.byKey(const Key('challenge-reward-incomplete')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('challenge-save-diploma')), findsNothing);
      expect(
        find.byKey(const Key('challenge-reward-lock-overlay')),
        findsNothing,
      );
    });

    testWidgets(
      'unlocked paid completion shows save-diploma CTA without a lock',
      (tester) async {
        useTallView(tester);
        final strings = AppStrings('en');
        final open = sampleOpenChallenge();
        final purchases = MemoryPurchases()
          ..pay(
            'open-1',
            paidAt: DateTime(2026, 3, 11),
            rewardVariant: RewardVariant.medalAndDiploma,
          );
        await tester.pumpWidget(
          wrapScreen(
            buildServices(
              detail: open,
              progress: completedProgress(open),
              purchases: purchases,
            ),
            locale: 'en',
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('challenge-save-diploma')),
        );
        expect(find.byKey(const Key('challenge-reward-lock')), findsNothing);
        expect(
          find.byKey(const Key('challenge-reward-diploma-blur')),
          findsNothing,
        );
        expect(find.text(strings.saveDiploma), findsOneWidget);
        expect(find.byKey(const Key('challenge-reward-medal')), findsNothing);
        expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);
        expect(
          find.byKey(const Key('challenge-reward-diploma')),
          findsOneWidget,
        );
        expect(find.text(strings.diplomaLabel), findsOneWidget);

        final cta = tester.widget<FilledButton>(
          find.byKey(const Key('challenge-save-diploma')),
        );
        expect(cta.onPressed, isNotNull);
        expect(
          cta.style?.backgroundColor?.resolve(const {}),
          BrandColors.forest,
        );
        expect(
          cta.style?.foregroundColor?.resolve(const {}),
          BrandColors.cream,
        );
      },
    );

    testWidgets('unpaid paid challenge covers the reward and ignores taps', (
      tester,
    ) async {
      useTallView(tester);
      final semantics = tester.ensureSemantics();
      final strings = AppStrings('cs');
      final story = sampleStoryChallenge();
      final diplomas = MemoryDiplomaClient();
      final purchases = MemoryPurchases(completeOnRefresh: false);
      await tester.pumpWidget(
        wrapScreen(
          buildServices(
            detail: story,
            progress: completedProgress(story),
            diplomas: diplomas,
            purchases: purchases,
          ),
          locale: 'cs',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-reward-lock')),
      );
      expect(
        find.byKey(const Key('challenge-reward-lock-overlay')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('challenge-reward-section')),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('challenge-reward-medal')), findsNothing);
      expect(find.byKey(const Key('challenge-reward-diploma')), findsOneWidget);
      expect(find.byKey(const Key('challenge-save-diploma')), findsNothing);
      expect(
        find.byKey(const Key('challenge-reward-diploma-blur')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('challenge-reward-diploma-texture')),
        findsOneWidget,
      );
      expect(diplomas.imageRequests, isEmpty);
      expect(
        find.bySemanticsLabel(strings.rewardUnlockDiploma),
        findsOneWidget,
      );
      final unlock = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const Key('challenge-reward-section')),
          matching: find.byType(InkWell),
        ),
      );
      expect(unlock.onTap, isNotNull);
      expect(unlock.mouseCursor, SystemMouseCursors.click);

      final lockSize = tester.getSize(
        find.byKey(const Key('challenge-reward-lock')),
      );
      expect(lockSize.width, greaterThanOrEqualTo(44));
      expect(lockSize.height, greaterThanOrEqualTo(44));
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const Key('challenge-reward-guard')),
            )
            .ignoring,
        isTrue,
      );
      final scrim = tester.widget<ColoredBox>(
        find.byKey(const Key('challenge-reward-lock-scrim')),
      );
      expect(scrim.color, BrandColors.cream.withValues(alpha: 0.35));
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('challenge-reward-section')),
          matching: find.byIcon(Icons.lock_outline),
        ),
      );
      expect(icon.color, BrandColors.forest);
      expect(icon.size, 32);
      final clip = tester.widget<ClipRRect>(
        find.byKey(const Key('challenge-reward-clip')),
      );
      expect(clip.borderRadius, BorderRadius.circular(16));

      final diplomaCenter = tester.getCenter(
        find.byKey(const Key('challenge-reward-diploma')),
      );
      expect(
        tester
            .getRect(find.byKey(const Key('challenge-reward-lock-overlay')))
            .contains(diplomaCenter),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('challenge-reward-lock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);
      expect(purchases.purchases['story-1']!.status, PurchaseStatus.pending);
      expect(
        purchases.purchases['story-1']!.rewardVariant,
        RewardVariant.diploma,
      );
      expect(
        find.text(fapiCheckoutUrlFor(RewardVariant.diploma)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('challenge-save-diploma')), findsNothing);
      expect(diplomas.imageRequests, isEmpty);

      final freePurchases = MemoryPurchases();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        wrapScreen(buildServices(purchases: freePurchases)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('challenge-pay-ctas')), findsOneWidget);
      expect(find.byKey(const Key('challenge-reward-lock')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('challenge-reward-lock')),
      );
      await tester.tap(find.byKey(const Key('challenge-reward-lock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payment-checkout-screen')), findsNothing);
      expect(freePurchases.purchases, isEmpty);
      semantics.dispose();
    });

    testWidgets('a zero CMS diploma price still locks the reward', (
      tester,
    ) async {
      useTallView(tester);
      final story = sampleStoryChallenge();
      final challenge = story.challenge;
      final zero = ChallengeDetail(
        challenge: Challenge(
          id: challenge.id,
          slug: challenge.slug,
          accessMode: challenge.accessMode,
          pricingType: PricingType.paid,
          priceCents: challenge.priceCents,
          diplomaPriceCents: 0,
          medalPriceCents: challenge.medalPriceCents,
          currency: challenge.currency,
          status: challenge.status,
          translations: challenge.translations,
          fapiFormUrlDiploma: challenge.fapiFormUrlDiploma,
          fapiFormUrlMedal: challenge.fapiFormUrlMedal,
        ),
        waypoints: story.waypoints,
      );
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: zero),
          locale: 'en',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-reward-section')),
      );
      expect(find.byKey(const Key('challenge-pay-ctas')), findsOneWidget);
      expect(find.byKey(const Key('challenge-reward-lock')), findsOneWidget);
      expect(
        find.byKey(const Key('challenge-reward-lock-overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('challenge-reward-diploma-blur')),
        findsNothing,
      );
      expect(find.byKey(const Key('challenge-reward-medal')), findsNothing);
      expect(find.byKey(const Key('challenge-reward-diploma')), findsOneWidget);
    });

    testWidgets('purchased paid challenge shows the reward without a lock', (
      tester,
    ) async {
      useTallView(tester);
      final story = sampleStoryChallenge();
      final purchases = MemoryPurchases()
        ..pay(
          'story-1',
          paidAt: DateTime(2026, 3, 11),
          rewardVariant: RewardVariant.medalAndDiploma,
        );
      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story, purchases: purchases),
          locale: 'de',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('challenge-reward-section')),
      );
      expect(find.byKey(const Key('challenge-reward-lock')), findsNothing);
      expect(
        find.byKey(const Key('challenge-reward-lock-overlay')),
        findsNothing,
      );
      expect(find.byKey(const Key('challenge-reward-medal')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('challenge-reward-section')),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('challenge-reward-diploma')), findsOneWidget);
      expect(find.text(AppStrings('de').rewardLockedLabel), findsNothing);
    });
  });

  group('reward widget', () {
    test('lock label is localized', () {
      expect(
        AppStrings('cs').rewardLockedLabel,
        'Odměna se odemkne po zaplacení výzvy',
      );
      expect(
        AppStrings('en').rewardLockedLabel,
        'The reward unlocks after you pay for the challenge',
      );
      expect(
        AppStrings('de').rewardLockedLabel,
        'Die Belohnung wird nach der Zahlung der Challenge freigeschaltet',
      );
      expect(AppStrings('cs').rewardUnlockDiploma, 'Odemknout diplom');
      expect(AppStrings('en').rewardUnlockDiploma, 'Unlock diploma');
      expect(AppStrings('de').rewardUnlockDiploma, 'Diplom freischalten');
    });

    testWidgets('locked overlay hides the medal and blocks the diploma CTA', (
      tester,
    ) async {
      useTallView(tester);
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeRewardSection(
              strings: AppStrings('en'),
              completed: true,
              entitled: true,
              locked: true,
              hasDisplayName: true,
              onSaveDiploma: () => taps++,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('challenge-reward-medal')), findsNothing);
      expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);
      expect(find.byKey(const Key('challenge-reward-diploma')), findsOneWidget);
      expect(
        find.byKey(const Key('challenge-reward-lock-overlay')),
        findsOneWidget,
      );
      expect(find.byType(BackdropFilter), findsWidgets);
      final lockSize = tester.getSize(
        find.byKey(const Key('challenge-reward-lock')),
      );
      expect(lockSize.width, greaterThanOrEqualTo(44));
      expect(lockSize.height, greaterThanOrEqualTo(44));
      expect(
        find.bySemanticsLabel(AppStrings('en').rewardUnlockDiploma),
        findsOneWidget,
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('challenge-save-diploma')),
      );
      expect(button.onPressed, isNull);
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const Key('challenge-reward-guard')),
            )
            .ignoring,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('challenge-reward-lock')));
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('challenge-save-diploma'))),
      );
      await tester.pump();
      expect(taps, 0);
      semantics.dispose();
    });

    testWidgets('unlocked reward has no overlay and the diploma CTA works', (
      tester,
    ) async {
      useTallView(tester);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeRewardSection(
              strings: AppStrings('en'),
              completed: true,
              entitled: true,
              locked: false,
              hasDisplayName: true,
              onSaveDiploma: () => taps++,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('challenge-reward-medal')), findsNothing);
      expect(find.byKey(const Key('challenge-reward-lock')), findsNothing);
      expect(
        find.byKey(const Key('challenge-reward-lock-overlay')),
        findsNothing,
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const Key('challenge-reward-guard')),
            )
            .ignoring,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('challenge-save-diploma')));
      expect(taps, 1);
    });
  });

  test(
    'banner and reward panels use only BrandColors cream/beige/forest/bark',
    () {
      final decoration = challengeBrandPanel();
      expect(decoration.color, BrandColors.cream);
      expect(decoration.borderRadius, BorderRadius.circular(16));
      final border = decoration.border! as Border;
      expect(border.top.color, BrandColors.beige);
      expect(border.top.width, 1);
      expect(BrandColors.forest, const Color(0xFF35483C));
      expect(BrandColors.bark, const Color(0xFF756653));
    },
  );

  test('deadline copy uses paid_at + 6 months and the 7-day boundary', () {
    final due = DateTime(2026, 10, 21, 12);
    final cs = AppStrings('cs');
    final en = AppStrings('en');
    final de = AppStrings('de');
    expect(
      cs.rewardDeadlineLabel(formatLocalDate(due, 'cs')),
      'Splň do 21. 10. 2026',
    );
    expect(
      en.rewardDeadlineLabel(formatLocalDate(due, 'en')),
      'Complete by Oct 21, 2026',
    );
    expect(
      de.rewardDeadlineLabel(formatLocalDate(due, 'de')),
      'Abschließen bis 21. Okt. 2026',
    );
    expect(
      cs.rewardDaysLeftSuffix(due, DateTime(2026, 10, 14, 8)),
      '· zbývá 7 dní',
    );
    expect(
      cs.rewardDaysLeftSuffix(due, DateTime(2026, 10, 20, 8)),
      '· zbývá 1 den',
    );
    expect(
      cs.rewardDaysLeftSuffix(due, DateTime(2026, 10, 19, 8)),
      '· zbývá 2 dny',
    );
    expect(cs.rewardDaysLeftSuffix(due, DateTime(2026, 10, 1, 8)), isNull);
    expect(
      en.rewardDaysLeftSuffix(due, DateTime(2026, 10, 20, 8)),
      '· 1 day left',
    );
    expect(
      de.rewardDaysLeftSuffix(due, DateTime(2026, 10, 19, 8)),
      '· noch 2 Tage',
    );
    expect(cs.rewardDeadlinePassed(due, DateTime(2026, 10, 21, 13)), isTrue);
    expect(cs.deadlinePassed, 'Termín vypršel');
    expect(en.deadlinePassed, 'Deadline passed');
    expect(de.deadlinePassed, 'Frist abgelaufen');
  });

  testWidgets('paid reward shows the deadline chip and hides the lock', (
    tester,
  ) async {
    final due = DateTime(2027, 4, 20);
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChallengeRewardSection(
              strings: AppStrings('en'),
              completed: false,
              entitled: false,
              locked: false,
              locale: 'en',
              completeBy: due,
              showDeadline: true,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('challenge-reward-lock')), findsNothing);
    expect(find.byKey(const Key('challenge-reward-deadline')), findsOneWidget);
    expect(find.byKey(const Key('challenge-deadline-date')), findsNothing);
    expect(find.text('Complete by Apr 20, 2027'), findsOneWidget);
  });
}
