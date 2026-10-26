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
import 'package:viateria/models/models.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/screens/verify_waypoint_screen.dart';
import 'package:viateria/ui/widgets/verify_success_confetti.dart';

import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

const _gold = Color(0xFFD4A017);

AppServices _services({DeviceLocation? location, MemoryProgress? progress}) {
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
    progress: progress ?? MemoryProgress(details: [open]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    deviceLocation: location ?? MemoryDeviceLocation(),
    verifiedPlaces: VerifiedPlacesStore(),
  );
}

Widget _app(
  AppServices services, {
  required String location,
  bool disableAnimations = false,
  VoidCallback? onHomeTap,
}) {
  final places = samplePlaces();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TextButton(
          key: const Key('home'),
          onPressed: onHomeTap,
          child: const Text('home'),
        ),
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
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: disableAnimations),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

Future<bool> _sawConfetti(
  WidgetTester tester, {
  Finder? until,
  int pumps = 25,
}) async {
  final confetti = find.byKey(VerifySuccessConfetti.overlayKey);
  var seen = false;
  for (var i = 0; i < pumps; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    if (confetti.evaluate().isNotEmpty) seen = true;
    if (until != null && until.evaluate().isNotEmpty && (seen || i > 4)) {
      break;
    }
  }
  return seen;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('burst stays inside the approved palette, count, and duration', () {
    expect(kVerifyConfettiParticleCount, inInclusiveRange(40, 70));
    expect(
      kVerifyConfettiDuration.inMilliseconds,
      inInclusiveRange(1200, 1800),
    );
    expect(verifyConfettiOpacity(0), 1);
    expect(verifyConfettiOpacity(0.5), 1);
    expect(verifyConfettiOpacity(1), 0);
    expect(verifyConfettiOpacity(0.9), lessThan(1));

    final pieces = buildVerifyConfettiPieces();
    expect(pieces, hasLength(kVerifyConfettiParticleCount));
    for (final piece in pieces) {
      expect(kVerifyConfettiColors, contains(piece.color));
      expect(piece.color, isNot(_gold));
      expect(piece.origin.dy, inInclusiveRange(0, 1 / 3));
      expect(piece.origin.dx, inInclusiveRange(0, 1));
    }
    expect(kVerifyConfettiColors, contains(const Color(0xFFE8A090)));
    expect(kVerifyConfettiColors, contains(const Color(0xFF7BA3C4)));
    expect(kVerifyConfettiColors, contains(const Color(0xFFE8D48B)));
    expect(kVerifyConfettiColors, contains(const Color(0xFFB8A0C8)));
    expect(kVerifyConfettiColors, contains(BrandColors.sage));
    expect(kVerifyConfettiColors, contains(BrandColors.forest));
    expect(kVerifyConfettiColors, contains(BrandColors.cream));
    expect(kVerifyConfettiColors, contains(BrandColors.beige));
    expect(kVerifyConfettiColors, isNot(contains(_gold)));
  });

  testWidgets('reduce motion paints no confetti and finishes immediately', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: VerifySuccessConfetti(onFinished: () => finished = true),
        ),
      ),
    );
    expect(find.byKey(VerifySuccessConfetti.overlayKey), findsNothing);
    await tester.pump();
    expect(finished, isTrue);
    expect(find.byKey(VerifySuccessConfetti.overlayKey), findsNothing);
  });

  testWidgets('burst ignores pointers and fades out within the cap', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: VerifySuccessConfetti(onFinished: () => finished = true),
      ),
    );
    await tester.pump();
    expect(find.byKey(VerifySuccessConfetti.overlayKey), findsOneWidget);
    final ignore = tester.widget<IgnorePointer>(
      find.byKey(VerifySuccessConfetti.overlayKey),
    );
    expect(ignore.ignoring, isTrue);
    expect(finished, isFalse);

    // isDone is strict greater-than the duration, so step one frame past it.
    await tester.pump(
      kVerifyConfettiDuration + const Duration(milliseconds: 32),
    );
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('successful place verify shows confetti and does not block', (
    tester,
  ) async {
    var tappedHome = false;
    await tester.pumpWidget(
      _app(
        _services(
          location: MemoryDeviceLocation(
            point: const RouteEndpoint(
              lat: 49.9394,
              lng: 14.1880,
              label: 'GPS',
            ),
          ),
        ),
        location: '/verify/place/karlstejn',
        onHomeTap: () => tappedHome = true,
      ),
    );

    final seen = await _sawConfetti(
      tester,
      until: find.byKey(VerifySuccessConfetti.overlayKey),
    );
    expect(seen, isTrue);
    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(find.text('Ověřeno'), findsNothing);
    expect(find.text('Verified'), findsNothing);

    await tester.tap(find.byKey(const Key('home')));
    await tester.pump();
    expect(tappedHome, isTrue);

    await tester.pump(
      kVerifyConfettiDuration + const Duration(milliseconds: 32),
    );
    await tester.pump();
    expect(find.byKey(VerifySuccessConfetti.overlayKey), findsNothing);
  });

  testWidgets('successful waypoint verify shows confetti', (tester) async {
    await tester.pumpWidget(
      _app(
        _services(
          location: MemoryDeviceLocation(
            point: const RouteEndpoint(lat: 50.08, lng: 14.42, label: 'GPS'),
          ),
        ),
        location: '/verify/open-1/ow-1',
      ),
    );

    final seen = await _sawConfetti(
      tester,
      until: find.byKey(VerifySuccessConfetti.overlayKey),
    );
    expect(seen, isTrue);
    expect(find.byKey(const Key('home')), findsOneWidget);
    final ignore = tester.widget<IgnorePointer>(
      find.byKey(VerifySuccessConfetti.overlayKey),
    );
    expect(ignore.ignoring, isTrue);
  });

  testWidgets('reduce motion skips confetti on a successful verify', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _services(
          location: MemoryDeviceLocation(
            point: const RouteEndpoint(
              lat: 49.9394,
              lng: 14.1880,
              label: 'GPS',
            ),
          ),
        ),
        location: '/verify/place/karlstejn',
        disableAnimations: true,
      ),
    );

    final seen = await _sawConfetti(
      tester,
      until: find.byKey(const Key('home')),
    );
    expect(seen, isFalse);
    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(find.byKey(VerifySuccessConfetti.overlayKey), findsNothing);
  });

  testWidgets('a failed waypoint verify shows no confetti', (tester) async {
    final strings = AppStrings('cs');
    final open = sampleOpenChallenge();
    final progress = MemoryProgress(details: [open])
      ..verifyError = StateError('verify failed');
    await tester.pumpWidget(
      _app(
        _services(
          location: MemoryDeviceLocation(
            point: const RouteEndpoint(lat: 50.08, lng: 14.42, label: 'GPS'),
          ),
          progress: progress,
        ),
        location: '/verify/open-1/ow-1',
      ),
    );

    final seen = await _sawConfetti(tester);
    await tester.pumpAndSettle();
    expect(seen, isFalse);
    expect(find.byKey(VerifySuccessConfetti.overlayKey), findsNothing);
    expect(find.text(strings.errorGeneric), findsOneWidget);
    expect(find.byKey(const Key('home')), findsNothing);
    final stored = await progress.fetchProgress('open-1');
    expect(stored?.completedWaypointIds ?? const {}, isEmpty);
  });

  testWidgets('GPS too far to verify shows no confetti', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(
      _app(_services(), location: '/verify/place/karlstejn'),
    );

    final seen = await _sawConfetti(tester);
    await tester.pumpAndSettle();
    expect(seen, isFalse);
    expect(find.byKey(VerifySuccessConfetti.overlayKey), findsNothing);
    expect(find.text(strings.gpsTooFarFallback), findsOneWidget);
  });
}
