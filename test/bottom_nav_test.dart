import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/app.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/catalog_screen.dart';
import 'package:viateria/ui/screens/last_challenge_screen.dart';
import 'package:viateria/ui/widgets/catalog_cards.dart';
import 'package:viateria/ui/widgets/challenges_overview_map.dart';

import 'helpers/fakes.dart';

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
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => locale ?? LocaleController(initial: 'en'),
      ),
      ChangeNotifierProvider(
        create: (_) => lastOpened ?? LastOpenedChallengeStore(),
      ),
      Provider.value(value: services),
    ],
    child: MaterialApp(home: child),
  );
}

Widget wrapApp(
  AppServices services, {
  LocaleController? locale,
  LastOpenedChallengeStore? lastOpened,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => locale ?? LocaleController(initial: 'en'),
      ),
      ChangeNotifierProvider(
        create: (_) => lastOpened ?? LastOpenedChallengeStore(),
      ),
      Provider.value(value: services),
    ],
    child: const ViateriaApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signed-in shell shows four bottom destinations', (tester) async {
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    final nav = find.byKey(const Key('app-bottom-nav'));
    expect(nav, findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    final strings = AppStrings('en');
    expect(find.text(strings.catalogTitle), findsOneWidget);
    expect(find.text(strings.navLastChallenge), findsOneWidget);
    expect(find.text(strings.navMap), findsOneWidget);
    expect(find.text(strings.navProfile), findsOneWidget);

    final screenSize = tester.getSize(find.byType(Scaffold).first);
    final navTop = tester.getTopLeft(nav).dy;
    expect(navTop, greaterThan(screenSize.height / 2));
    expect(find.text('Weekend hike'), findsOneWidget);
  });

  testWidgets('last-challenge tab shows empty state when none opened', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navLastChallenge));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('last-challenge-empty')), findsOneWidget);
    expect(find.text(strings.lastChallengeEmpty), findsOneWidget);
    expect(find.text(strings.lastChallengeEmptyHint), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('opening a catalog challenge updates last-opened tab', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final store = LastOpenedChallengeStore();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapApp(buildServices(), lastOpened: store));
    await tester.pumpAndSettle();

    final card = find.widgetWithText(ChallengeCard, 'Open trail');
    await tester.scrollUntilVisible(card, 300);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.challengeId, 'open-1');
    expect(find.text('Visit any stop'), findsWidgets);
    expect(find.byType(AppBar), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navLastChallenge));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Open trail'), findsWidgets);
    expect(find.text('Visit any stop'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('map tab empty state when no coordinates', (tester) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(
      wrapApp(
        buildServices(
          challenges: const [],
          promos: const [],
          details: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navMap));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-empty')), findsOneWidget);
    expect(find.text(strings.mapEmpty), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('map tab shows published challenges with waypoint coordinates', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navMap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('map-empty')), findsNothing);
    expect(find.byType(ChallengesOverviewMap), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('profile tab shows identity and sign out', (tester) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navProfile));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text(strings.signOut), findsOneWidget);
    expect(find.text(strings.language), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
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

  testWidgets('map tab shows retry when published details fail to load', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final open = sampleOpenChallenge();
    await tester.pumpWidget(
      wrapApp(
        buildServices(
          catalog: MemoryCatalog(challenges: [open.challenge], details: [open])
            ..fetchChallengeError = Exception('timeout'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navMap));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-empty')), findsNothing);
    expect(find.byKey(const Key('map-load-error')), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
