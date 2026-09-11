import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/data/route_services.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/challenge_map.dart';
import 'package:viateria/ui/widgets/map_chrome.dart';

import 'helpers/fakes.dart';

AppServices buildServices({
  RoutingClient? routing,
  PlaceGeocoder? geocoder,
  DeviceLocation? deviceLocation,
  ElevationLookup? elevation,
  ExternalUrlOpener? openUrl,
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
    routing: routing ?? MemoryRoutingClient(),
    geocoder:
        geocoder ??
        MemoryGeocoder(
          places: {
            'praha': const RouteEndpoint(
              lat: 50.0755,
              lng: 14.4378,
              label: 'Praha',
            ),
          },
        ),
    deviceLocation: deviceLocation ?? MemoryDeviceLocation(),
    elevation: elevation ?? MemoryElevationLookup(),
    openUrl: openUrl,
  );
}

Widget wrapScreen(AppServices services, {String locale = 'cs'}) {
  return TickerMode(
    enabled: false,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleController(initial: locale),
        ),
        ChangeNotifierProvider(
          create: (_) => LastOpenedChallengeStore(initialId: 'open-1'),
        ),
        Provider.value(value: services),
      ],
      child: const MaterialApp(home: ChallengeScreen(challengeId: 'open-1')),
    ),
  );
}

Future<void> openStartList(WidgetTester tester) async {
  final picker = find.byKey(const Key('route-start-picker'));
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('route-start-sheet')), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('challenge map shows a single Start picker, not split start UI', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapScreen(buildServices()));
    await tester.pumpAndSettle();

    expect(find.text('Otevřená stezka'), findsOneWidget);
    expect(find.text(strings.routePlanner), findsOneWidget);
    expect(find.byKey(const Key('route-start-picker')), findsOneWidget);
    expect(find.byKey(const Key('route-start-field')), findsNothing);
    expect(find.byKey(const Key('route-use-gps')), findsNothing);
    expect(find.byKey(const Key('route-start-place')), findsNothing);
    expect(find.byKey(const Key('route-destination-place')), findsOneWidget);
    expect(find.byKey(const Key('route-empty')), findsOneWidget);
    expect(find.text(strings.routeNeedTwoPoints), findsOneWidget);
    expect(find.byKey(const Key('route-hike-stats')), findsNothing);
  });

  testWidgets('tapping Start opens custom, GPS, then challenge places', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapScreen(buildServices()));
    await tester.pumpAndSettle();

    await openStartList(tester);

    expect(find.text(strings.routeCustomPlace), findsOneWidget);
    expect(find.text(strings.routeUseGps), findsOneWidget);
    expect(find.text(strings.routePlacesInChallenge), findsOneWidget);
    expect(find.byKey(const Key('route-start-place-ow-1')), findsOneWidget);
    expect(find.byKey(const Key('route-start-place-ow-2')), findsOneWidget);

    final customY = tester
        .getTopLeft(find.byKey(const Key('route-start-custom')))
        .dy;
    final gpsY = tester.getTopLeft(find.byKey(const Key('route-use-gps'))).dy;
    final firstPlaceY = tester
        .getTopLeft(find.byKey(const Key('route-start-place-ow-1')))
        .dy;
    final secondPlaceY = tester
        .getTopLeft(find.byKey(const Key('route-start-place-ow-2')))
        .dy;
    expect(customY, lessThan(gpsY));
    expect(gpsY, lessThan(firstPlaceY));
    expect(firstPlaceY, lessThan(secondPlaceY));
  });

  testWidgets('picking a challenge place as start shows walking and cycling', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapScreen(buildServices()));
    await tester.pumpAndSettle();

    await openStartList(tester);
    await tester.tap(find.byKey(const Key('route-start-place-ow-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
    expect(find.byKey(const Key('route-bike-stats')), findsOneWidget);
    expect(find.text(strings.routeWalking), findsOneWidget);
    expect(find.text(strings.routeCycling), findsOneWidget);
    expect(find.textContaining('1.6 km'), findsOneWidget);
    expect(find.textContaining('1.2 km'), findsOneWidget);
    expect(find.textContaining(' m'), findsWidgets);
    expect(find.text('0 m'), findsNothing);
    expect(find.text(strings.routeElevationFailed), findsNothing);
    expect(find.text('Ridge'), findsWidgets);
  });

  testWidgets('elevation lookup failure shows a clear state, not 0 m', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrapScreen(buildServices(elevation: MemoryElevationLookup(fail: true))),
    );
    await tester.pumpAndSettle();

    await openStartList(tester);
    await tester.tap(find.byKey(const Key('route-start-place-ow-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
    expect(find.byKey(const Key('route-bike-stats')), findsOneWidget);
    expect(find.textContaining('1.6 km'), findsOneWidget);
    expect(find.textContaining('1.2 km'), findsOneWidget);
    expect(find.text('0 m'), findsNothing);
    expect(find.text(strings.routeElevationFailed), findsWidgets);
    expect(
      find.byKey(const Key('route-elevation-missing-hike')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('route-elevation-missing-bike')),
      findsOneWidget,
    );
    expect(find.text(strings.retry), findsOneWidget);
  });

  testWidgets('custom place and GPS can set a start from the Start list', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapScreen(buildServices()));
    await tester.pumpAndSettle();

    await openStartList(tester);
    await tester.tap(find.byKey(const Key('route-start-custom')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-start-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('route-start-field')),
      '50.07, 14.41',
    );
    await tester.tap(find.byKey(const Key('route-start-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
    expect(find.byKey(const Key('route-bike-stats')), findsOneWidget);

    await openStartList(tester);
    final gps = find.byKey(const Key('route-use-gps'));
    await tester.ensureVisible(gps);
    await tester.tap(gps);
    await tester.pumpAndSettle();
    expect(find.text(strings.routeUseGps), findsWidgets);
    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
    expect(find.byKey(const Key('route-start-field')), findsNothing);
  });

  testWidgets('routing failure shows an empty error state', (tester) async {
    final strings = AppStrings('cs');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrapScreen(buildServices(routing: MemoryRoutingClient(fail: true))),
    );
    await tester.pumpAndSettle();

    await openStartList(tester);
    await tester.tap(find.byKey(const Key('route-start-place-ow-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-empty')), findsOneWidget);
    expect(find.text(strings.routeLoadFailed), findsOneWidget);
    expect(find.byKey(const Key('route-hike-stats')), findsNothing);
    expect(find.text(strings.retry), findsOneWidget);
  });

  testWidgets('typed place name uses geocoder after custom start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapScreen(buildServices()));
    await tester.pumpAndSettle();

    await openStartList(tester);
    await tester.tap(find.byKey(const Key('route-start-custom')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('route-start-field')), 'Praha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
    expect(find.text('Praha'), findsWidgets);
  });

  testWidgets(
    'starting navigation stays on the challenge map and can be ended',
    (tester) async {
      final strings = AppStrings('cs');
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final opened = <Uri>[];
      await tester.pumpWidget(
        wrapScreen(
          buildServices(
            openUrl: (uri) async {
              opened.add(uri);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openStartList(tester);
      await tester.tap(find.byKey(const Key('route-start-place-ow-2')));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(0);
      await tester.pump();

      expect(find.text(strings.openInOsm), findsNothing);
      expect(find.byKey(const Key('route-map-nav-actions')), findsOneWidget);
      expect(find.byKey(const Key('route-map-navigate-hike')), findsOneWidget);
      expect(find.byKey(const Key('route-map-navigate-bike')), findsOneWidget);
      expect(find.byKey(const Key('route-navigate-hike')), findsOneWidget);
      expect(find.byKey(const Key('route-navigate-bike')), findsOneWidget);

      await tester.tap(find.byKey(const Key('route-map-navigate-hike')));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.byKey(const Key('route-navigation-active')), findsOneWidget);
      expect(find.text(strings.routeNavigatingWalk), findsOneWidget);
      expect(find.byKey(const Key('route-end-navigation')), findsOneWidget);
      expect(find.byKey(const Key('route-map-navigate-hike')), findsNothing);
      expect(find.byKey(const Key('route-map-navigate-bike')), findsNothing);
      expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
      expect(find.byKey(const Key('route-bike-stats')), findsOneWidget);

      scrollable.position.jumpTo(0);
      await tester.pump();
      await tester.tap(find.byKey(const Key('route-end-navigation')));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.byKey(const Key('route-navigation-active')), findsNothing);
      expect(find.text(strings.routeNavigatingWalk), findsNothing);
      expect(find.byKey(const Key('route-map-navigate-hike')), findsOneWidget);
      expect(find.byKey(const Key('route-map-navigate-bike')), findsOneWidget);
      expect(find.byKey(const Key('route-navigate-hike')), findsOneWidget);
      expect(find.byKey(const Key('route-navigate-bike')), findsOneWidget);
    },
  );

  testWidgets(
    'challenge preview map reuses places chrome without growing the panel',
    (tester) async {
      final strings = AppStrings('cs');
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(buildServices()));
      await tester.pumpAndSettle();

      final map = find.byType(ChallengeMap);
      expect(map, findsOneWidget);
      expect(tester.getSize(map).height, 280);
      expect(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-search-field')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-filter-button')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-view-toggle')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-poi-count')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-locate-fab')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-osm-attribution')),
        ),
        findsOneWidget,
      );
      expect(find.text(strings.searchHint), findsOneWidget);
      expect(find.text(strings.viewList), findsOneWidget);

      final search = tester.widget<TextField>(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-search-field')),
        ),
      );
      expect(search.style?.fontSize, 13);
      expect(search.style?.color, MapPalette.forest);

      final locate = tester.widget<MapIconButton>(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-locate-fab')),
        ),
      );
      expect(locate.size, 36);
      expect(locate.iconSize, 16);

      final zoomIn = tester.widget<MapIconButton>(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-zoom-in')),
        ),
      );
      expect(zoomIn.size, 36);
      expect(zoomIn.iconSize, 16);
      expect(zoomIn.foreground, MapPalette.forest);

      final zoomOut = tester.widget<MapIconButton>(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-zoom-out')),
        ),
      );
      expect(zoomOut.size, 36);
      expect(zoomOut.iconSize, 16);

      await tester.tap(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-view-toggle')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: map,
          matching: find.byKey(const Key('map-poi-list')),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(map).height, 280);
    },
  );
}
