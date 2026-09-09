import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/app.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/core/l10n/map_strings.dart';
import 'package:viateria/core/theme/map_colors.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/catalog_screen.dart';
import 'package:viateria/ui/screens/challenges_map_screen.dart';
import 'package:viateria/ui/screens/last_challenge_screen.dart';
import 'package:viateria/ui/widgets/catalog_cards.dart';

import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

AppServices buildServices({
  List<Challenge>? challenges,
  List<PromoStripe>? promos,
  List<ChallengeDetail>? details,
  MemoryCatalog? catalog,
  MemoryProgress? progress,
  bool configured = true,
}) {
  final open = sampleOpenChallenge();
  final story = sampleStoryChallenge();
  final draft = Challenge(
    id: 'draft-1',
    slug: 'hidden',
    accessMode: AccessMode.open,
    pricingType: PricingType.free,
    priceCents: 0,
    currency: 'eur',
    status: PublishStatus.draft,
    translations: const [
      LocalizedText(locale: 'en', title: 'Hidden draft', description: ''),
    ],
  );
  final resolvedDetails = details ?? [open, story];
  return AppServices(
    config: AppConfig(
      supabaseUrl: configured ? 'https://example.supabase.co' : '',
      supabaseAnonKey: configured ? 'anon' : '',
      stripePublishableKey: configured ? 'pk_test' : '',
    ),
    auth: MemoryAuth(
      user: const Profile(
        id: 'user-1',
        locale: 'en',
        displayName: 'Ada',
        email: 'ada@example.com',
      ),
    ),
    catalog:
        catalog ??
        MemoryCatalog(
          challenges: challenges ?? [open.challenge, story.challenge, draft],
          details: resolvedDetails,
          promos: promos ?? [samplePromo()],
        ),
    progress: progress ?? MemoryProgress(details: resolvedDetails),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
  );
}

Widget wrapScreen(
  Widget child,
  AppServices services, {
  LocaleController? locale,
  LastOpenedChallengeStore? lastOpened,
}) {
  return wrapWithProviders(
    MaterialApp(home: child),
    services,
    locale: locale,
    lastOpened: lastOpened,
  );
}

Widget wrapApp(
  AppServices services, {
  LocaleController? locale,
  LastOpenedChallengeStore? lastOpened,
}) {
  return wrapWithProviders(
    const ViateriaApp(),
    services,
    locale: locale,
    lastOpened: lastOpened,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureMapWidgetTests();
  });

  testWidgets('signed-in shell shows six destinations and opens on the map', (
    tester,
  ) async {
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    final nav = find.byKey(const Key('app-bottom-nav'));
    expect(nav, findsOneWidget);

    final map = MapStrings('en');
    expect(find.bySemanticsLabel(map.navHome), findsOneWidget);
    expect(find.bySemanticsLabel(map.navMap), findsOneWidget);
    expect(find.bySemanticsLabel(map.navList), findsOneWidget);
    expect(find.bySemanticsLabel(map.navPlanner), findsOneWidget);
    expect(find.bySemanticsLabel(map.navSaved), findsOneWidget);
    expect(find.bySemanticsLabel(map.navProfile), findsOneWidget);
    expect(find.text(map.searchHint), findsOneWidget);

    final screenSize = tester.getSize(find.byType(Scaffold).first);
    final navTop = tester.getTopLeft(nav).dy;
    expect(navTop, greaterThan(screenSize.height / 2));

    final shell = tester.widget<Material>(
      find.byKey(const Key('app-bottom-nav-shell')),
    );
    expect(shell.color, MapColors.surfaceFill);
  });

  testWidgets(
    'bottom nav sits above the home indicator',
    (tester) async {
      const homeIndicator = 34.0;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: homeIndicator);
      tester.view.viewPadding = const FakeViewPadding(bottom: homeIndicator);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      await tester.pumpWidget(wrapApp(buildServices()));
      await tester.pumpAndSettle();

      final navRect = tester.getRect(find.byKey(const Key('app-bottom-nav')));
      final screenSize = tester.getSize(find.byType(Scaffold).first);
      expect(navRect.bottom, lessThanOrEqualTo(screenSize.height - homeIndicator + 0.5));
    },
  );

  testWidgets('home tab still lists the challenge catalog', (tester) async {
    final map = MapStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(map.navHome));
    await tester.pumpAndSettle();

    expect(find.text('Weekend hike'), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
  });

  testWidgets('opening a catalog challenge records last-opened', (tester) async {
    final map = MapStrings('en');
    final store = LastOpenedChallengeStore();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapApp(buildServices(), lastOpened: store));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(map.navHome));
    await tester.pumpAndSettle();

    final card = find.widgetWithText(ChallengeCard, 'Open trail');
    await tester.scrollUntilVisible(card, 300);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.challengeId, 'open-1');
    expect(find.text('Visit any stop'), findsWidgets);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('profile tab shows identity, sign out, and last-challenge entry', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final map = MapStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(map.navProfile));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text(strings.signOut), findsOneWidget);
    expect(find.text(strings.language), findsOneWidget);
    expect(find.text(strings.navLastChallenge), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
  });

  testWidgets(
    'catalog screen still lists published challenges without drafts',
    (tester) async {
      await tester.pumpWidget(
        wrapScreen(const CatalogScreen(), buildServices()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weekend hike'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Open trail'), 400);
      expect(find.text('Open trail'), findsOneWidget);
      expect(find.text('Hidden draft'), findsNothing);
    },
  );

  testWidgets('last challenge missing id is an empty state, not an error', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(
      wrapScreen(
        const LastChallengeScreen(),
        buildServices(),
        lastOpened: LastOpenedChallengeStore(initialId: 'gone-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('last-challenge-missing')), findsOneWidget);
    expect(find.text(strings.lastChallengeMissing), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsNothing);
  });

  testWidgets('last challenge keeps retry when a transient load fails', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final open = sampleOpenChallenge();
    await tester.pumpWidget(
      wrapScreen(
        const LastChallengeScreen(),
        buildServices(
          progress: MemoryProgress(details: [open])
            ..fetchProgressError = Exception('timeout'),
        ),
        lastOpened: LastOpenedChallengeStore(initialId: open.challenge.id),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('last-challenge-missing')), findsNothing);
    expect(find.byKey(const Key('challenge-load-error')), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
  });

  testWidgets('challenge map screen shows retry when published details fail', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final open = sampleOpenChallenge();
    await tester.pumpWidget(
      wrapScreen(
        const ChallengesMapScreen(),
        buildServices(
          catalog: MemoryCatalog(challenges: [open.challenge], details: [open])
            ..fetchChallengeError = Exception('timeout'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-empty')), findsNothing);
    expect(find.byKey(const Key('map-load-error')), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
  });
}
