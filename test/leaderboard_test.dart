import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/data/memory_leaderboard.dart';
import 'package:viateria/data/place_visit_sync.dart';
import 'package:viateria/data/verified_places.dart';
import 'package:viateria/domain/leaderboard_score.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/screens/leaderboard_screen.dart';
import 'package:viateria/ui/screens/profile_screen.dart';
import 'package:viateria/ui/screens/verify_waypoint_screen.dart';

import 'bottom_nav_test.dart';
import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('completed challenge points follow difficulty', () {
    expect(pointsForCompletedChallenge(null), 3);
    expect(pointsForCompletedChallenge(CatalogDifficulty.easy), 3);
    expect(pointsForCompletedChallenge(CatalogDifficulty.normal), 4);
    expect(pointsForCompletedChallenge(CatalogDifficulty.hard), 5);
    expect(leaderboardTotal(placePoints: 2, challengePoints: 3 + 4 + 5), 14);
  });

  test(
    'rank prefers higher points, then earlier first visit, then user id',
    () {
      final ranked = rankScores([
        ScoreCandidate(
          userId: 'b',
          totalPoints: 5,
          firstVisit: DateTime.utc(2026, 2),
        ),
        ScoreCandidate(
          userId: 'a',
          totalPoints: 5,
          firstVisit: DateTime.utc(2026, 1),
        ),
        ScoreCandidate(
          userId: 'c',
          totalPoints: 9,
          firstVisit: DateTime.utc(2026, 5),
        ),
        const ScoreCandidate(userId: 'd', totalPoints: 5),
        ScoreCandidate(
          userId: 'e',
          totalPoints: 5,
          firstVisit: DateTime.utc(2026, 1),
        ),
        const ScoreCandidate(userId: 'z', totalPoints: 0),
      ]);
      expect(ranked.map((row) => row.row.userId).toList(), [
        'c',
        'a',
        'e',
        'b',
        'd',
      ]);
      expect(ranked.map((row) => row.rank).toList(), [1, 2, 3, 4, 5]);
    },
  );

  test('limit clamps to 50 and names never fall back to email', () {
    expect(clampLeaderboardLimit(50), 50);
    expect(clampLeaderboardLimit(80), 50);
    expect(clampLeaderboardLimit(0), 0);
    expect(clampLeaderboardLimit(-4), 0);
    expect(
      leaderboardPersonName(displayName: null, isSelf: true, selfLabel: 'Já'),
      'Já',
    );
    expect(
      leaderboardPersonName(displayName: '  ', isSelf: false, selfLabel: 'Já'),
      '—',
    );
    expect(
      leaderboardPersonName(displayName: 'Ada', isSelf: true, selfLabel: 'Já'),
      'Ada',
    );
    expect(isPlaceUuid('karlstejn'), isFalse);
    expect(isPlaceUuid('11111111-1111-4111-8111-111111111111'), isTrue);
  });

  test('rpc row mapping ignores email', () {
    final entry = LeaderboardEntry.fromRpc({
      'user_id': 'user-1',
      'display_name': 'Ada',
      'email': 'ada@example.com',
      'avatar_url': '  ',
      'total_points': 4,
      'place_points': 1,
      'challenge_points': 3,
      'rank': 2,
    });
    expect(entry.displayName, 'Ada');
    expect(entry.avatarUrl, isNull);
    expect(entry.totalPoints, 4);
    expect(entry.placePoints, 1);
    expect(entry.challengePoints, 3);
    expect(entry.rank, 2);
    expect(entry.hasRank, isTrue);
    expect('$entry', isNot(contains('ada@example.com')));
  });

  test('migration exposes the leaderboard RPC contract', () {
    final sql = File('supabase/migrations/0011_leaderboard.sql')
        .readAsStringSync()
        .toLowerCase();
    expect(sql, contains('create table if not exists public.place_visits'));
    expect(sql, contains('primary key (user_id, place_id)'));
    expect(sql, contains("references auth.users"));
    expect(sql, contains('references public.places'));
    expect(sql, contains("source in ('map', 'verify', 'prefs_sync')"));
    expect(sql, contains('place_visits_select_own'));
    expect(sql, contains('place_visits_insert_own'));
    expect(sql, contains('user_id = auth.uid()'));
    expect(sql, contains('function public.record_place_visit'));
    expect(sql, contains('function public.record_place_visits_batch'));
    expect(sql, contains("default 'prefs_sync'"));
    expect(sql, contains('function public.get_leaderboard'));
    expect(sql, contains('function public.get_my_score'));
    expect(sql, contains('least(greatest(coalesce(p_limit, 50), 0), 50)'));
    expect(sql, contains("when c.difficulty = 'hard' then 5"));
    expect(sql, contains("when c.difficulty = 'normal' then 4"));
    expect(sql, contains('else 3'));
    expect(sql, contains("cp.status = 'completed'"));
    expect(sql, contains('comb.total_points desc'));
    expect(sql, contains('comb.first_visit asc nulls last'));
    expect(sql, contains('comb.user_id asc'));
    expect(sql, contains("<= 50"));
    expect(sql, contains("'verify'"));
    expect(sql, contains('on conflict (user_id, place_id) do nothing'));
    expect(sql, contains('grant execute on function public.get_leaderboard'));
    expect(sql, contains('grant execute on function public.get_my_score'));
    expect(
      sql,
      contains(
        'revoke all on function public.leaderboard_rows() from public, anon, authenticated',
      ),
    );
    expect(sql, contains('email is never selected'));
    expect(sql, isNot(contains('auth.users.email')));
    expect(sql, isNot(contains('u.email')));
  });

  test(
    'prefs sync uploads uuid visits once and retries after failure',
    () async {
      const userId = 'user-a';
      const placeId = '11111111-1111-4111-8111-111111111111';
      final store = VerifiedPlacesStore(initial: {placeId, 'karlstejn'});
      final board = MemoryLeaderboardRepository();
      final prefs = await SharedPreferences.getInstance();
      final sync = const PlaceVisitSync();

      expect(
        await sync.syncStored(
          userId: userId,
          store: store,
          leaderboard: board,
          preferences: prefs,
        ),
        isTrue,
      );
      expect(board.batches, [
        [placeId],
      ]);
      expect(board.visits.single.source, PlaceVisitSource.prefsSync);
      expect(prefs.getBool('${PlaceVisitSync.syncedFlag}.$userId'), isTrue);

      final again = MemoryLeaderboardRepository();
      expect(
        await sync.syncStored(
          userId: userId,
          store: store,
          leaderboard: again,
          preferences: prefs,
        ),
        isFalse,
      );
      expect(again.batches, isEmpty);

      final failing = MemoryLeaderboardRepository()..error = StateError('down');
      await expectLater(
        sync.syncStored(
          userId: 'user-b',
          store: store,
          leaderboard: failing,
          preferences: prefs,
        ),
        throwsStateError,
      );
      expect(prefs.getBool('${PlaceVisitSync.syncedFlag}.user-b'), isNot(true));
    },
  );

  testWidgets('leaderboard shows me, breakdown, and highlighted row', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final board = MemoryLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          userId: 'other',
          displayName: 'Bela',
          totalPoints: 9,
          placePoints: 4,
          challengePoints: 5,
          rank: 1,
        ),
        LeaderboardEntry(
          userId: 'user-1',
          displayName: 'Ada',
          totalPoints: 4,
          placePoints: 1,
          challengePoints: 3,
          rank: 2,
        ),
      ],
      me: const LeaderboardEntry(
        userId: 'user-1',
        displayName: 'Ada',
        totalPoints: 4,
        placePoints: 1,
        challengePoints: 3,
        rank: 2,
      ),
    );
    await tester.pumpWidget(
      wrapApp(
        buildServices(
          leaderboard: board,
          user: const Profile(
            id: 'user-1',
            locale: 'en',
            displayName: 'Ada',
            email: 'ada@example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leaderboard-title')), findsOneWidget);
    final title = tester.widget<Text>(
      find.byKey(const Key('leaderboard-title')),
    );
    expect(title.style?.fontFamily, 'Playfair Display');
    expect(title.style?.color, BrandColors.forest);
    expect(find.text('ada@example.com'), findsNothing);
    expect(find.byIcon(Icons.emoji_events), findsNothing);
    expect(find.byIcon(Icons.military_tech), findsNothing);
    expect(find.byIcon(Icons.workspace_premium), findsNothing);

    final me = tester.widget<DecoratedBox>(
      find.byKey(const Key('leaderboard-me')),
    );
    final decoration = me.decoration as BoxDecoration;
    expect(decoration.color, BrandColors.neutral);
    expect(
      decoration.border,
      const Border.fromBorderSide(BorderSide(color: BrandColors.beige)),
    );
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(find.byKey(const Key('leaderboard-me-points')), findsOneWidget);
    expect(find.text('#2 · 4 points'), findsOneWidget);
    expect(find.text('Places: 1 · Challenges: 3'), findsOneWidget);

    expect(find.byKey(const Key('leaderboard-how-body')), findsNothing);
    await tester.tap(find.byKey(const Key('leaderboard-how')));
    await tester.pumpAndSettle();
    expect(find.text(strings.leaderboardHowBody), findsOneWidget);

    final mine = tester.widget<ColoredBox>(
      find.byKey(const Key('leaderboard-row-user-1')),
    );
    expect(mine.color, BrandColors.neutral);
    final other = tester.widget<ColoredBox>(
      find.byKey(const Key('leaderboard-row-other')),
    );
    expect(other.color, BrandColors.cream);
    expect(tester.getSize(find.byType(LeaderboardAvatar).at(1)).width, 40);

    final page = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(LeaderboardScreen),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(page.color, BrandColors.cream);
    expect(page.color, isNot(BrandColors.shellFill));

    final viewport =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final sheet = tester.getSize(find.byKey(const Key('leaderboard-sheet')));
    expect(sheet.height, closeTo(LeaderboardSheet.heightFor(viewport), 0.5));
    expect(sheet.height, inInclusiveRange(viewport * 0.70, viewport * 0.88));
    expect(sheet.height, lessThan(viewport));

    final surface = tester.widget<Material>(
      find.byKey(const Key('leaderboard-sheet-surface')),
    );
    final shape = surface.shape! as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      const BorderRadius.vertical(
        top: Radius.circular(LeaderboardSheet.radius),
      ),
    );
    expect(LeaderboardSheet.radius, inInclusiveRange(16, 20));
    expect(surface.color, BrandColors.cream);
    expect(surface.color, isNot(BrandColors.shellFill));

    final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(
      barriers.map((barrier) => barrier.color),
      contains(LeaderboardSheet.barrierColor),
    );

    final close = tester.getSize(find.byKey(const Key('leaderboard-close')));
    expect(close.width, greaterThanOrEqualTo(LeaderboardSheet.closeHit));
    expect(close.height, greaterThanOrEqualTo(LeaderboardSheet.closeHit));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
      BrandColors.forest,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('leaderboard-sheet-body')),
        matching: find.byIcon(Icons.close),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('catalog-welcome-header')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('arrow and barrier dismiss the sheet without leaving catalog', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();
    expect(find.byTooltip(strings.closeCta), findsOneWidget);

    await tester.tap(find.byKey(const Key('leaderboard-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leaderboard-title')), findsNothing);
    expect(find.byKey(const Key('catalog-welcome-header')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leaderboard-title')), findsNothing);
    expect(find.byKey(const Key('catalog-welcome-header')), findsOneWidget);
  });

  testWidgets('empty board explains that nobody is ranked yet', (tester) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(
      wrapApp(buildServices(leaderboard: MemoryLeaderboardRepository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();
    expect(find.text(strings.leaderboardEmpty), findsOneWidget);
    expect(find.text(strings.leaderboardEmptyBody), findsOneWidget);
    expect(find.text(strings.leaderboardEmptyHint), findsOneWidget);
    expect(find.text(strings.leaderboardNoPoints), findsOneWidget);
  });

  testWidgets('error offers a forest retry and then shows the score', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final failing = MemoryLeaderboardRepository()..error = StateError('down');
    await tester.pumpWidget(wrapApp(buildServices(leaderboard: failing)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();
    expect(find.text(strings.leaderboardError), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('leaderboard-error')))
          .style
          ?.color,
      BrandColors.error,
    );
    final retry = tester.widget<FilledButton>(
      find.byKey(const Key('leaderboard-retry')),
    );
    expect(retry.style?.backgroundColor?.resolve({}), BrandColors.forest);

    failing.error = null;
    failing.me = const LeaderboardEntry(
      userId: 'user-1',
      totalPoints: 1,
      placePoints: 1,
      challengePoints: 0,
      rank: 8,
    );
    await tester.tap(find.byKey(const Key('leaderboard-retry')));
    await tester.pumpAndSettle();
    expect(find.text(strings.leaderboardError), findsNothing);
    expect(find.text(strings.leaderboardRankLine(8, 1)), findsOneWidget);
  });

  testWidgets('missing display name stays Me and never shows email', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(
      wrapApp(
        buildServices(
          user: const Profile(
            id: 'user-1',
            locale: 'en',
            email: 'ada@example.com',
          ),
          leaderboard: MemoryLeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('leaderboard-me-name'))).data,
      'Me',
    );
    expect(find.text('ada@example.com'), findsNothing);
    expect(find.text(strings.leaderboardNoPoints), findsOneWidget);
  });

  testWidgets('czech nav semantics say Žebříček and profile card opens it', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    final board = MemoryLeaderboardRepository(
      me: const LeaderboardEntry(
        userId: 'user-1',
        displayName: 'Ada',
        totalPoints: 3,
        placePoints: 0,
        challengePoints: 3,
        rank: 4,
      ),
    );
    await tester.pumpWidget(
      wrapApp(
        buildServices(leaderboard: board),
        locale: LocaleController(initial: 'cs'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bottom-nav')),
        matching: find.text('Žebříček'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('app-bottom-nav')),
        matching: find.text('Profil'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Žebříček'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byIcon(Icons.military_tech_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('app-bottom-nav')),
        matching: find.byIcon(Icons.military_tech_outlined),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('catalog-welcome-avatar')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-leaderboard')),
      300,
    );
    expect(find.byKey(const Key('profile-leaderboard')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-leaderboard-score')))
          .data,
      strings.leaderboardRankLine(4, 3),
    );
    expect(find.text(strings.leaderboardNoPoints), findsNothing);

    final completed = tester.getTopLeft(
      find.byKey(const Key('profile-completed-title')),
    );
    final cardFinder = find.byKey(const Key('profile-leaderboard'));
    expect(tester.getTopLeft(cardFinder).dy, greaterThan(completed.dy));

    final navTop = tester
        .getTopLeft(find.byKey(const Key('app-bottom-nav')))
        .dy;
    final cardBottom = tester.getBottomLeft(cardFinder).dy;
    if (cardBottom > navTop - 8) {
      await tester.drag(
        find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        ),
        Offset(0, navTop - cardBottom - 32),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(cardFinder);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leaderboard-title')), findsOneWidget);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
    expect(find.bySemanticsLabel('Zavřít'), findsOneWidget);
    expect(find.bySemanticsLabel('Zpět'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('leaderboard-close'))).shortestSide,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(const Key('leaderboard-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leaderboard-title')), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('map place visit records source map and ignores fixture ids', (
    tester,
  ) async {
    const placeId = '11111111-1111-4111-8111-111111111111';
    const place = Place(
      id: placeId,
      name: 'Hrad',
      category: PlaceCategory.historical,
      location: GeoPoint(49.9394, 14.1880),
    );
    final board = MemoryLeaderboardRepository();
    final verified = VerifiedPlacesStore();
    final services = _verifyServices(
      board: board,
      verified: verified,
      location: const RouteEndpoint(lat: 49.9394, lng: 14.1880, label: 'GPS'),
    );
    await tester.pumpWidget(
      _verifyApp(services, place: place, placeId: placeId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(verified.contains(placeId), isTrue);
    expect(board.visits, [(placeId: placeId, source: PlaceVisitSource.map)]);

    final fixture = MemoryLeaderboardRepository();
    final fixtureVerified = VerifiedPlacesStore();
    await tester.pumpWidget(
      _verifyApp(
        _verifyServices(
          board: fixture,
          verified: fixtureVerified,
          location: const RouteEndpoint(
            lat: 49.9394,
            lng: 14.1880,
            label: 'GPS',
          ),
        ),
        place: const Place(
          id: 'karlstejn',
          name: 'Karlštejn',
          category: PlaceCategory.historical,
          location: GeoPoint(49.9394, 14.1880),
        ),
        placeId: 'karlstejn',
      ),
    );
    await tester.pumpAndSettle();
    expect(fixtureVerified.contains('karlstejn'), isTrue);
    expect(fixture.visits, isEmpty);
  });

  testWidgets('a failed map score call still closes the visit sheet', (
    tester,
  ) async {
    const placeId = '11111111-1111-4111-8111-111111111111';
    final board = MemoryLeaderboardRepository()..error = StateError('down');
    final verified = VerifiedPlacesStore();
    await tester.pumpWidget(
      _verifyApp(
        _verifyServices(
          board: board,
          verified: verified,
          location: const RouteEndpoint(
            lat: 49.9394,
            lng: 14.1880,
            label: 'GPS',
          ),
        ),
        place: const Place(
          id: placeId,
          name: 'Hrad',
          category: PlaceCategory.historical,
          location: GeoPoint(49.9394, 14.1880),
        ),
        placeId: placeId,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(verified.contains(placeId), isTrue);
  });
}

AppServices _verifyServices({
  required MemoryLeaderboardRepository board,
  required VerifiedPlacesStore verified,
  required RouteEndpoint location,
}) {
  final open = sampleOpenChallenge();
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
    progress: MemoryProgress(details: [open]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    deviceLocation: MemoryDeviceLocation(point: location),
    verifiedPlaces: verified,
    leaderboard: board,
  );
}

Widget _verifyApp(
  AppServices services, {
  required Place place,
  required String placeId,
}) {
  final router = GoRouter(
    initialLocation: '/verify/place/$placeId',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Text('home', key: Key('home')),
        routes: [
          GoRoute(
            path: 'verify/place/:placeId',
            builder: (context, state) => VerifyWaypointScreen(
              placeId: state.pathParameters['placeId'],
              place: place,
              places: MemoryPlaceCatalog([place]),
            ),
          ),
        ],
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider.value(value: services),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
