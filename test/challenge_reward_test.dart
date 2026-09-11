import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/challenge_map.dart';
import 'package:viateria/ui/widgets/challenge_reward_section.dart';
import 'package:viateria/ui/widgets/route_planner_panel.dart';

import 'helpers/fakes.dart';

AppServices buildServices({
  MemoryProgress? progress,
  MemoryPurchases? purchases,
  ChallengeDetail? detail,
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
    openUrl: (_) async {},
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
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
          requiresPurchase: false,
        ),
        isTrue,
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
      expect(formatLocalDate(date, 'de'), '11.09.2026');
      expect(formatLocalDate(date, 'en'), 'Sep 11, 2026');
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
      'title, map, planner, info, then places sit above deadline and reward',
      (tester) async {
        useTallView(tester);
        final strings = AppStrings('en');
        await tester.pumpWidget(wrapScreen(buildServices(), locale: 'en'));
        await tester.pumpAndSettle();

        final titleY = tester
            .getTopLeft(find.byKey(const Key('challenge-title')))
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
        expect(titleY, lessThan(mapY));
        expect(mapY, lessThan(plannerY));
        expect(plannerY, lessThan(infoY));
        expect(infoY, lessThan(waypointsY));
        expect(waypointsY, lessThan(deadlineY));
        expect(deadlineY, lessThan(rewardY));
        expect(find.byKey(const Key('challenge-unlock-cta')), findsNothing);
        expect(find.byKey(const Key('challenge-pay-ctas')), findsNothing);
        expect(find.text('Visit any stop'), findsOneWidget);
        expect(find.text('Open trail'), findsOneWidget);
        expect(find.text(strings.waypoints), findsOneWidget);
      },
    );

    testWidgets(
      'info, places, then side-by-side pay CTAs sit above deadline and reward',
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
        expect(find.text(strings.challengeLockedPaid), findsOneWidget);
        expect(find.text(strings.waypoints), findsOneWidget);
        expect(find.text(strings.payDigitalDiploma), findsOneWidget);
        expect(find.text(strings.payMedalAndDiploma), findsOneWidget);
        expect(find.text(strings.unlockWithStripe), findsNothing);
        expect(infoY, lessThan(waypointsY));
        expect(waypointsY, lessThan(diploma.top));
        expect(diploma.left, lessThan(medal.left));
        expect((diploma.center.dy - medal.center.dy).abs(), lessThan(1));
        expect(medal.left - diploma.right, inInclusiveRange(8, 12));
        expect(medal.bottom, lessThan(deadlineY));
        expect(deadlineY, lessThan(rewardY));

        final diplomaButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('challenge-pay-diploma')),
        );
        final medalButton = tester.widget<FilledButton>(
          find.byKey(const Key('challenge-pay-medal')),
        );
        expect(
          diplomaButton.style?.foregroundColor?.resolve(const {}),
          BrandColors.forest,
        );
        expect(
          diplomaButton.style?.side?.resolve(const {})?.color,
          BrandColors.forest,
        );
        expect(
          medalButton.style?.backgroundColor?.resolve(const {}),
          BrandColors.forest,
        );
        expect(
          medalButton.style?.foregroundColor?.resolve(const {}),
          BrandColors.cream,
        );
      },
    );

    testWidgets('pay CTAs use cs / de product labels', (tester) async {
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
      expect(find.text('Digitální diplom'), findsOneWidget);
      expect(find.text('Medaile + diplom'), findsOneWidget);

      await tester.pumpWidget(
        wrapScreen(
          buildServices(detail: story),
          locale: 'de',
          challengeId: 'story-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Digitales Diplom'), findsOneWidget);
      expect(find.text('Medaille + Diplom'), findsOneWidget);
    });

    testWidgets('tapping a pay CTA persists that variant on the purchase', (
      tester,
    ) async {
      useTallView(tester);
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

      await tester.ensureVisible(find.byKey(const Key('challenge-pay-medal')));
      await tester.tap(find.byKey(const Key('challenge-pay-medal')));
      await tester.pumpAndSettle();

      expect(purchases.purchases['story-1']!.isPaid, isTrue);
      expect(
        purchases.purchases['story-1']!.rewardVariant,
        RewardVariant.medalAndDiploma,
      );
      expect(find.byKey(const Key('challenge-pay-ctas')), findsNothing);
      expect(find.byKey(const Key('challenge-reward-medal')), findsOneWidget);
    });

    testWidgets(
      'locked unpaid reward shows both placeholders and is not tappable',
      (tester) async {
        useTallView(tester);
        final strings = AppStrings('cs');
        await tester.pumpWidget(wrapScreen(buildServices()));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('challenge-reward-section')),
        );
        expect(find.text(strings.rewardTitle), findsOneWidget);
        expect(find.byKey(const Key('challenge-reward-lock')), findsOneWidget);
        expect(
          find.byKey(const Key('challenge-reward-diploma')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('challenge-reward-medal')), findsOneWidget);
        expect(find.text(strings.rewardUnlocksAfterComplete), findsOneWidget);
        expect(find.text(strings.rewardDependsOnPaidOption), findsOneWidget);
        expect(find.byKey(const Key('challenge-save-diploma')), findsNothing);
        expect(find.byType(AbsorbPointer), findsWidgets);
      },
    );

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
      expect(find.byKey(const Key('challenge-reward-lock')), findsOneWidget);
      expect(find.byKey(const Key('challenge-save-diploma')), findsNothing);
      expect(
        find.byKey(const Key('challenge-reward-unpaid-hint')),
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
        expect(find.text(strings.saveDiploma), findsOneWidget);
        expect(find.text(strings.woodenMedal), findsOneWidget);
        expect(find.byKey(const Key('challenge-reward-medal')), findsOneWidget);
        expect(
          find.byKey(const Key('challenge-reward-diploma')),
          findsOneWidget,
        );

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
}
