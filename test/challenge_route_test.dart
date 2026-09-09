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

import 'helpers/fakes.dart';

AppServices buildServices({
  RoutingClient? routing,
  PlaceGeocoder? geocoder,
  DeviceLocation? deviceLocation,
  ElevationLookup? elevation,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('challenge map shows selected point and start controls', (
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
    expect(find.byKey(const Key('route-start-field')), findsOneWidget);
    expect(find.byKey(const Key('route-use-gps')), findsOneWidget);
    expect(find.byKey(const Key('route-start-place')), findsOneWidget);
    expect(find.byKey(const Key('route-destination-place')), findsOneWidget);
    expect(find.byKey(const Key('route-empty')), findsOneWidget);
    expect(find.text(strings.routeNeedTwoPoints), findsOneWidget);
    expect(find.byKey(const Key('route-hike-stats')), findsNothing);
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

    await tester.tap(find.byKey(const Key('route-start-place')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ridge').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
    expect(find.byKey(const Key('route-bike-stats')), findsOneWidget);
    expect(find.text(strings.routeWalking), findsOneWidget);
    expect(find.text(strings.routeCycling), findsOneWidget);
    expect(find.textContaining('1.6 km'), findsOneWidget);
    expect(find.textContaining('1.2 km'), findsOneWidget);
    expect(find.textContaining(' m'), findsWidgets);
  });

  testWidgets('typed coordinates and GPS can set a start', (tester) async {
    final strings = AppStrings('cs');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapScreen(buildServices()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('route-start-field')),
      '50.07, 14.41',
    );
    await tester.tap(find.byKey(const Key('route-start-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
    expect(find.byKey(const Key('route-bike-stats')), findsOneWidget);

    await tester.tap(find.byKey(const Key('route-use-gps')));
    await tester.pumpAndSettle();
    expect(find.text(strings.routeUseGps), findsWidgets);
    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('route-start-place')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ridge').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-empty')), findsOneWidget);
    expect(find.text(strings.routeLoadFailed), findsOneWidget);
    expect(find.byKey(const Key('route-hike-stats')), findsNothing);
    expect(find.text(strings.retry), findsOneWidget);
  });

  testWidgets('typed place name uses geocoder', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapScreen(buildServices()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('route-start-field')), 'Praha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
    expect(find.text('Praha'), findsWidgets);
  });
}
