import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/data/route_services.dart';
import 'package:viateria/data/verified_places.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/verify_waypoint_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

AppServices _services({
  DeviceLocation? location,
  VerifiedPlacesStore? verified,
  MemoryCatalog? catalog,
  MemoryProgress? progress,
  MemoryPurchases? purchases,
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
    catalog:
        catalog ?? MemoryCatalog(challenges: [open.challenge], details: [open]),
    progress: progress ?? MemoryProgress(details: [open]),
    purchases: purchases ?? MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    deviceLocation: location ?? MemoryDeviceLocation(),
    verifiedPlaces: verified ?? VerifiedPlacesStore(),
  );
}

Widget _app(AppServices services, {required String location}) {
  final places = samplePlaces();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Text('home', key: Key('home')),
        routes: [
          GoRoute(
            path: 'verify/place/:placeId',
            builder: (context, state) => VerifyWaypointScreen(
              placeId: state.pathParameters['placeId'],
              place: places.first,
              places: MemoryPlaceCatalog(places),
            ),
          ),
          GoRoute(
            path: 'verify/:challengeId/:waypointId',
            builder: (context, state) => VerifyWaypointScreen(
              challengeId: state.pathParameters['challengeId'],
              waypointId: state.pathParameters['waypointId'],
              places: MemoryPlaceCatalog(places),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GPS within radius verifies a standalone place', (tester) async {
    final verified = VerifiedPlacesStore();
    final services = _services(
      location: MemoryDeviceLocation(
        point: const RouteEndpoint(lat: 49.9394, lng: 14.1880, label: 'GPS'),
      ),
      verified: verified,
    );
    await tester.pumpWidget(
      _app(services, location: '/verify/place/karlstejn'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(verified.contains('karlstejn'), isTrue);
  });

  testWidgets('GPS outside radius falls back to live photo', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(
      _app(_services(), location: '/verify/place/karlstejn'),
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.gpsTooFarFallback), findsOneWidget);
    expect(find.text(strings.takePhoto), findsWidgets);
    expect(find.byKey(const Key('verify-submit')), findsOneWidget);
  });

  testWidgets('GPS within radius completes a challenge waypoint', (
    tester,
  ) async {
    final services = _services(
      location: MemoryDeviceLocation(
        point: const RouteEndpoint(lat: 50.08, lng: 14.42, label: 'GPS'),
      ),
    );
    await tester.pumpWidget(_app(services, location: '/verify/open-1/ow-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home')), findsOneWidget);
    final progress = await services.progress.fetchProgress('open-1');
    expect(progress?.completedWaypointIds, contains('ow-1'));
  });

  testWidgets('denied GPS falls back to live photo', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(
      _app(
        _services(
          location: MemoryDeviceLocation(
            error: const LocationFailure('denied'),
          ),
        ),
        location: '/verify/place/karlstejn',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.gpsDeniedFallback), findsOneWidget);
  });

  testWidgets('GPS still respects story unlock order', (tester) async {
    final strings = AppStrings('cs');
    final story = sampleStoryChallenge();
    final services = _services(
      location: MemoryDeviceLocation(
        point: const RouteEndpoint(lat: 48.98, lng: 14.48, label: 'GPS'),
      ),
      catalog: MemoryCatalog(challenges: [story.challenge], details: [story]),
      progress: MemoryProgress(details: [story]),
      purchases: MemoryPurchases(
        purchases: {
          'story-1': const Purchase(
            challengeId: 'story-1',
            status: PurchaseStatus.paid,
          ),
        },
      ),
    );
    await tester.pumpWidget(_app(services, location: '/verify/story-1/sw-2'));
    await tester.pumpAndSettle();

    expect(find.text(strings.needAccess), findsOneWidget);
    expect(find.byKey(const Key('verify-submit')), findsOneWidget);
    final progress = await services.progress.fetchProgress('story-1');
    expect(progress?.completedWaypointIds ?? const {}, isEmpty);
  });
}
