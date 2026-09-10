import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/places_map_screen.dart';
import 'package:viateria/ui/widgets/map_chrome.dart';
import 'package:viateria/ui/widgets/places_map_host.dart';
import 'package:viateria/ui/widgets/places_map_surface.dart';

import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

AppServices _services() {
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
  );
}

Widget _mapApp({MemoryPlaceCatalog? catalog}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: PlacesMapScreen(
            catalog: catalog ?? MemoryPlaceCatalog(samplePlaces()),
          ),
        ),
      ),
      GoRoute(
        path: '/verify/place/:placeId',
        builder: (context, state) => Text(
          'verify-place-${state.pathParameters['placeId']}',
          key: const Key('verify-place-route'),
        ),
      ),
      GoRoute(
        path: '/verify/:challengeId/:waypointId',
        builder: (context, state) => Text(
          'verify-${state.pathParameters['challengeId']}-${state.pathParameters['waypointId']}',
          key: const Key('verify-route'),
        ),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider.value(value: _services()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('filter changes the visible POI count chip', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-poi-count')), findsOneWidget);
    expect(find.text(strings.monumentCount(3)), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-filter-historical')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(2)), findsOneWidget);
    expect(find.text(strings.monumentCount(3)), findsNothing);
  });

  testWidgets('standalone list is empty without a challenge', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-view-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-poi-list')), findsOneWidget);
    expect(find.text(strings.listNoChallenge), findsOneWidget);
    expect(find.text('Karlštejn'), findsNothing);
  });

  testWidgets('map count chip still filters the full catalog', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-filter-city')));
    await tester.tap(find.byKey(const Key('map-filter-nature')));
    await tester.tap(find.byKey(const Key('map-filter-technical')));
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(1)), findsOneWidget);
  });

  testWidgets('Czech search copy and empty catalog error banner', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(
      _mapApp(catalog: const MemoryPlaceCatalog([], error: 'offline')),
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.searchHint), findsOneWidget);
    expect(find.text(strings.viewList), findsOneWidget);
    expect(find.text(strings.catalogLoadError), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
    expect(find.byKey(const Key('map-osm-attribution')), findsOneWidget);
    expect(find.byKey(const Key('map-locate-fab')), findsOneWidget);
    expect(find.byKey(const Key('map-zoom-in')), findsOneWidget);
    expect(find.byKey(const Key('map-zoom-out')), findsOneWidget);
  });

  testWidgets('Mapa tab chrome uses Batch A cream/forest sizes', (
    tester,
  ) async {
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    final search = tester.widget<TextField>(
      find.byKey(const Key('map-search-field')),
    );
    expect(search.style?.color, MapPalette.forest);
    expect(search.style?.fontSize, 15);
    expect(search.decoration?.prefixIcon, isA<Icon>());
    expect((search.decoration!.prefixIcon! as Icon).size, 18);
    expect((search.decoration!.prefixIcon! as Icon).color, MapPalette.forest);

    final locate = tester.widget<MapIconButton>(
      find.byKey(const Key('map-locate-fab')),
    );
    expect(locate.size, 44);
    expect(locate.iconSize, 18);
    expect(locate.foreground, MapPalette.forest);
    expect(locate.background ?? MapOverlayColors.fill, MapPalette.creamFill);

    final zoomIn = tester.widget<MapIconButton>(
      find.byKey(const Key('map-zoom-in')),
    );
    expect(zoomIn.size, 44);
    expect(zoomIn.iconSize, 18);
    expect(zoomIn.foreground, MapPalette.forest);
    expect(zoomIn.background ?? MapOverlayColors.fill, MapPalette.creamFill);

    final zoomOut = tester.widget<MapIconButton>(
      find.byKey(const Key('map-zoom-out')),
    );
    expect(zoomOut.size, 44);
    expect(zoomOut.iconSize, 18);
    expect(zoomOut.foreground, MapPalette.forest);

    final filter = tester.widget<MapIconButton>(
      find.byKey(const Key('map-filter-button')),
    );
    expect(filter.size, 44);
    expect(filter.iconSize, 18);

    final count = tester.widget<Text>(find.byKey(const Key('map-poi-count')));
    expect(count.style?.color, MapPalette.bark);
    expect(count.style?.fontSize, 13);
  });

  testWidgets('in-challenge verify opens the verify route', (tester) async {
    final places = samplePlaces();
    const waypoint = Waypoint(
      id: 'wp-karlstejn',
      challengeId: 'open-1',
      sortOrder: 0,
      lat: 49.9394,
      lng: 14.1880,
      elevationM: 300,
      translations: [LocalizedText(locale: 'cs', title: 'Karlštejn')],
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: PlacesMapSurface(
              catalog: MemoryPlaceCatalog(places),
              geometry: const ChallengeMapGeometry(waypoints: [waypoint]),
            ),
          ),
        ),
        GoRoute(
          path: '/verify/:challengeId/:waypointId',
          builder: (context, state) => Text(
            'verify-${state.pathParameters['challengeId']}-${state.pathParameters['waypointId']}',
            key: const Key('verify-route'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'cs'),
          ),
          ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
          Provider.value(value: _services()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Karlštejn'), findsOneWidget);
    expect(find.text('Staroměstské náměstí'), findsNothing);
    final listIcon = tester.widget<ColorFiltered>(
      find.descendant(
        of: find.byKey(const Key('map-poi-list-karlstejn')),
        matching: find.byType(ColorFiltered),
      ),
    );
    expect(
      listIcon.colorFilter,
      const ColorFilter.mode(MapPalette.forest, BlendMode.srcIn),
    );
    await tester.tap(find.text('Karlštejn'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-poi-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-poi-verify')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verify-route')), findsOneWidget);
    expect(find.text('verify-open-1-wp-karlstejn'), findsOneWidget);
  });

  testWidgets('standalone challenge-only filter empties the map', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(3)), findsOneWidget);
    expect(
      find.byKey(const Key('map-filter-challenge-only-empty')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-filter-challenge-only')), findsOneWidget);
    expect(find.text(strings.filterChallengeOnly), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-filter-challenge-only')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(0)), findsOneWidget);
    expect(find.text(strings.filterChallengeOnlyEmpty), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-filter-challenge-only')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(3)), findsOneWidget);
    expect(
      find.byKey(const Key('map-filter-challenge-only-empty')),
      findsNothing,
    );
  });

  testWidgets('challenge-only filter keeps challenge stops on the map', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    final places = samplePlaces();
    const waypoint = Waypoint(
      id: 'wp-karlstejn',
      challengeId: 'open-1',
      sortOrder: 0,
      lat: 49.9394,
      lng: 14.1880,
      elevationM: 300,
      translations: [LocalizedText(locale: 'cs', title: 'Karlštejn')],
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: PlacesMapSurface(
              catalog: MemoryPlaceCatalog(places),
              geometry: const ChallengeMapGeometry(waypoints: [waypoint]),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'cs'),
          ),
          ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
          Provider.value(value: _services()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(3)), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-filter-challenge-only')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(1)), findsOneWidget);
    expect(
      find.byKey(const Key('map-filter-challenge-only-empty')),
      findsNothing,
    );

    await tester.enterText(find.byKey(const Key('map-search-field')), 'Starom');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('map-search-staromestske')), findsNothing);

    await tester.enterText(find.byKey(const Key('map-search-field')), 'Karl');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('map-search-karlstejn')), findsOneWidget);
  });
}
