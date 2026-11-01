import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/challenge_mapping.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/data/repositories.dart';
import 'package:viateria/data/route_services.dart';
import 'package:viateria/data/verified_places.dart';
import 'package:viateria/domain/photo_verify.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/screens/verify_waypoint_screen.dart';
import 'package:viateria/ui/widgets/app_network_image.dart';
import 'package:viateria/ui/widgets/error_state.dart';
import 'package:viateria/ui/widgets/verify_success_confetti.dart';

import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

const _coverHash = 'L6PZfSi_.AyE_3t7t7R**0o#DgR4';

const _png = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  2,
  0,
  0,
  0,
  144,
  119,
  83,
  222,
  0,
  0,
  0,
  12,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  207,
  192,
  0,
  0,
  3,
  1,
  1,
  0,
  201,
  254,
  146,
  239,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

class _NeverImage extends ImageProvider<_NeverImage> {
  const _NeverImage();

  @override
  Future<_NeverImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_NeverImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(_NeverImage key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}

class _GatedCatalog extends MemoryCatalog {
  _GatedCatalog({
    required super.challenges,
    required super.details,
    required this.gate,
  });

  final Completer<void> gate;

  @override
  Future<ChallengeDetail> fetchChallenge(String id) async {
    await gate.future;
    return super.fetchChallenge(id);
  }
}

AppServices _services({
  CatalogRepository? catalog,
  MemoryProgress? progress,
  DeviceLocation? location,
  PhotoCapture? photoCapture,
  VerifiedPlacesStore? verified,
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
    photoCapture: photoCapture ?? MemoryCapture(),
    deviceLocation: location ?? MemoryDeviceLocation(),
    verifiedPlaces: verified ?? VerifiedPlacesStore(),
    places: MemoryPlaceCatalog(samplePlaces()),
  );
}

Widget _detailApp(AppServices services) {
  return TickerMode(
    enabled: false,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
        ChangeNotifierProvider(
          create: (_) => LastOpenedChallengeStore(initialId: 'open-1'),
        ),
        Provider.value(value: services),
      ],
      child: const MaterialApp(home: ChallengeScreen(challengeId: 'open-1')),
    ),
  );
}

Widget _verifyApp(
  AppServices services, {
  required String location,
  Place? place,
}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Text('home', key: Key('home')),
        routes: [
          GoRoute(
            path: 'verify/:challengeId/:waypointId',
            builder: (context, state) => VerifyWaypointScreen(
              challengeId: state.pathParameters['challengeId'],
              waypointId: state.pathParameters['waypointId'],
              placeId: place?.id,
              place: place,
              places: MemoryPlaceCatalog(samplePlaces()),
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

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 40; i++) {
    if (ready()) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('blurhash column is a nullable text migration without a backfill', () {
    final sql = File(
      'supabase/migrations/20261101120000_challenge_blurhash.sql',
    ).readAsStringSync().toLowerCase();
    expect(sql, contains('add column if not exists blurhash text'));
    expect(sql, contains('c.blurhash'));
    expect(sql, contains('challenge_catalog_v'));
    expect(sql, isNot(contains('service_role')));
    expect(sql, isNot(contains('update public.challenges')));
  });

  test('challenge rows keep a null blurhash and a stored one', () {
    final missing = challengeFromRow({
      'id': 'c',
      'slug': 'c',
      'access_mode': 'open',
      'pricing_type': 'free',
      'status': 'published',
      'title_cs': 'Nazev',
    });
    expect(missing.blurHash, isNull);
    final hashed = challengeFromRow({
      'id': 'c',
      'slug': 'c',
      'access_mode': 'open',
      'pricing_type': 'free',
      'status': 'published',
      'cover_image_url': 'https://example.test/c.jpg',
      'blurhash': '  $_coverHash  ',
      'title_cs': 'Nazev',
    });
    expect(hashed.blurHash, _coverHash);
    expect(usableBlurHash(_coverHash), _coverHash);
    expect(usableBlurHash(''), isNull);
    expect(usableBlurHash('not a hash'), isNull);
    expect(usableBlurHash('abcdef'), isNull);
  });

  test('optimistic add then confirm is idempotent', () async {
    final store = VerifiedPlacesStore();
    store.addOptimistic('pin-1');
    store.addOptimistic('pin-1');
    expect(store.contains('pin-1'), isTrue);
    expect(store.ids, {'pin-1'});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(VerifiedPlacesStore.prefsKey), isNull);

    await store.confirm('pin-1');
    await store.confirm('pin-1');
    expect(store.contains('pin-1'), isTrue);
    expect(store.ids, {'pin-1'});
    expect(prefs.getStringList(VerifiedPlacesStore.prefsKey), ['pin-1']);

    store.rollback('pin-1');
    expect(store.contains('pin-1'), isTrue);
  });

  test('optimistic add then rollback removes the pin', () async {
    final store = VerifiedPlacesStore();
    store.addOptimistic('pin-1');
    expect(store.contains('pin-1'), isTrue);
    store.rollback('pin-1');
    store.rollback('pin-1');
    expect(store.contains('pin-1'), isFalse);
    expect(store.ids, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(VerifiedPlacesStore.prefsKey), isNull);
  });

  test('checkout does not optimistic-update verified places', () {
    for (final path in [
      'lib/ui/screens/payment_checkout_screen.dart',
      'lib/ui/fapi_checkout_window.dart',
      'lib/ui/widgets/fapi_checkout_webview.dart',
      'lib/data/supabase_repositories.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('addOptimistic')),
        reason: path,
      );
    }
  });

  testWidgets('challenge detail shows a skeleton while loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final open = sampleOpenChallenge(
      coverImageUrl: 'asset://assets/challenges/beskydy-autumn.jpg',
      blurHash: _coverHash,
    );
    final gate = Completer<void>();
    final services = _services(
      catalog: _GatedCatalog(
        challenges: [open.challenge],
        details: [open],
        gate: gate,
      ),
      progress: MemoryProgress(details: [open]),
    );
    await tester.pumpWidget(_detailApp(services));
    await tester.pump();

    expect(find.byKey(const Key('challenge-detail-skeleton')), findsOneWidget);
    expect(find.byType(AppSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('challenge-title')), findsNothing);
    final skeletonHero = tester.getRect(
      find.byKey(const Key('challenge-detail-hero-skeleton')),
    );
    final skeletonTitle = tester.getRect(
      find.byKey(const Key('challenge-detail-title-skeleton')),
    );
    expect(skeletonHero.height, greaterThan(8));

    gate.complete();
    await _until(
      tester,
      () => find.byKey(const Key('challenge-title')).evaluate().isNotEmpty,
    );
    final hero = tester.getRect(
      find.byKey(const Key('challenge-hero-expanded')),
    );
    final title = tester.getRect(find.byKey(const Key('challenge-title')));
    expect((hero.height - skeletonHero.height).abs(), lessThanOrEqualTo(8));
    expect((hero.top - skeletonHero.top).abs(), lessThanOrEqualTo(8));
    expect((title.top - skeletonTitle.top).abs(), lessThanOrEqualTo(8));
    expect((title.bottom - skeletonTitle.bottom).abs(), lessThanOrEqualTo(8));
    await _disposeTree(tester);
  });

  testWidgets('a cover with a blurhash is not an empty box', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 80,
            child: AppNetworkImage(
              url: 'https://example.invalid/cover.jpg',
              blurHash: _coverHash,
              image: _NeverImage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BlurHash), findsOneWidget);
    expect(tester.getSize(find.byType(BlurHash)), const Size(120, 80));
    expect(find.byIcon(Icons.landscape), findsOneWidget);
    for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
      expect(box.color, isNot(Colors.grey));
      expect(box.color, isNot(Colors.blueGrey));
    }
  });

  testWidgets('a cover without a blurhash keeps a beige skeleton shape', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 80,
            child: AppNetworkImage(
              url: 'https://example.invalid/cover.jpg',
              image: _NeverImage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BlurHash), findsNothing);
    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.byIcon(Icons.landscape), findsOneWidget);
    expect(tester.getSize(find.byType(AppSkeleton)), const Size(120, 80));
  });

  testWidgets('GPS pass shows the pin before verify_waypoint confirms it', (
    tester,
  ) async {
    const place = Place(
      id: 'pin-1',
      name: 'Start',
      category: PlaceCategory.city,
      location: GeoPoint(50.08, 14.42),
    );
    final open = sampleOpenChallenge();
    final gate = Completer<void>();
    final progress = MemoryProgress(details: [open])
      ..verifyBarrier = gate.future;
    final verified = VerifiedPlacesStore();
    final services = _services(
      progress: progress,
      verified: verified,
      location: MemoryDeviceLocation(
        point: const RouteEndpoint(lat: 50.08, lng: 14.42, label: 'GPS'),
      ),
    );
    await tester.pumpWidget(
      _verifyApp(services, location: '/verify/open-1/ow-1', place: place),
    );
    await _until(tester, () => verified.contains('pin-1'));
    expect(find.byKey(const Key('home')), findsNothing);
    expect(progress.completed['open-1'], isNull);
    await _until(
      tester,
      () => find.byKey(VerifySuccessConfetti.overlayKey).evaluate().isNotEmpty,
    );

    gate.complete();
    await _until(
      tester,
      () => find.byKey(const Key('home')).evaluate().isNotEmpty,
    );
    expect(verified.contains('pin-1'), isTrue);
    expect(progress.completed['open-1'], contains('ow-1'));
    await _disposeTree(tester);
  });

  testWidgets('a failed GPS verify rolls the pin back and shows a snackbar', (
    tester,
  ) async {
    const place = Place(
      id: 'pin-1',
      name: 'Start',
      category: PlaceCategory.city,
      location: GeoPoint(50.08, 14.42),
    );
    final open = sampleOpenChallenge();
    final gate = Completer<void>();
    final progress = MemoryProgress(details: [open])
      ..verifyBarrier = gate.future
      ..verifyError = StateError('rpc');
    final verified = VerifiedPlacesStore();
    final services = _services(
      progress: progress,
      verified: verified,
      location: MemoryDeviceLocation(
        point: const RouteEndpoint(lat: 50.08, lng: 14.42, label: 'GPS'),
      ),
    );
    await tester.pumpWidget(
      _verifyApp(services, location: '/verify/open-1/ow-1', place: place),
    );
    await _until(tester, () => verified.contains('pin-1'));

    gate.complete();
    await _until(
      tester,
      () => find.byKey(const Key('verify-failed')).evaluate().isNotEmpty,
    );
    expect(verified.contains('pin-1'), isFalse);
    expect(progress.completed['open-1'], isNull);
    expect(find.byKey(const Key('home')), findsNothing);
    expect(find.text(AppStrings('cs').verifyFailed), findsWidgets);
    expect(find.text(AppStrings('en').verifyFailed), findsNothing);
    await _disposeTree(tester);
  });

  testWidgets('photo verify does not pin or celebrate before the RPC', (
    tester,
  ) async {
    const place = Place(
      id: 'pin-photo',
      name: 'Far',
      category: PlaceCategory.nature,
      location: GeoPoint(49.0, 14.0),
    );
    final open = sampleOpenChallenge();
    final gate = Completer<void>();
    final progress = MemoryProgress(details: [open])
      ..verifyBarrier = gate.future;
    final verified = VerifiedPlacesStore();
    final services = _services(
      progress: progress,
      verified: verified,
      photoCapture: MemoryCapture(
        photo: const LivePhoto(bytes: _png, mimeType: 'image/png'),
      ),
      location: MemoryDeviceLocation(
        point: const RouteEndpoint(lat: 50.08, lng: 14.42, label: 'GPS'),
      ),
    );
    await tester.pumpWidget(
      _verifyApp(services, location: '/verify/open-1/ow-1', place: place),
    );
    await _until(
      tester,
      () => find.byKey(const Key('verify-submit')).evaluate().isNotEmpty,
    );
    expect(verified.contains('pin-photo'), isFalse);

    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.photo_camera));
    await tester.pump();
    await tester.tap(find.byKey(const Key('verify-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(verified.contains('pin-photo'), isFalse);
    expect(progress.completed['open-1'], isNull);
    expect(find.byKey(VerifySuccessConfetti.overlayKey), findsNothing);
    expect(find.byKey(const Key('home')), findsNothing);

    gate.complete();
    await _until(
      tester,
      () => find.byKey(const Key('home')).evaluate().isNotEmpty,
    );
    expect(verified.contains('pin-photo'), isTrue);
    expect(progress.completed['open-1'], contains('ow-1'));
    await _disposeTree(tester);
  });

  testWidgets('story reveal waits until verify_waypoint returns', (
    tester,
  ) async {
    final story = sampleStoryChallenge();
    final gate = Completer<void>();
    final progress = MemoryProgress(details: [story])
      ..verifyBarrier = gate.future;
    final verified = VerifiedPlacesStore();
    final services = _services(
      catalog: MemoryCatalog(challenges: [story.challenge], details: [story]),
      progress: progress,
      verified: verified,
      purchases: MemoryPurchases(
        purchases: {
          'story-1': Purchase(
            challengeId: 'story-1',
            status: PurchaseStatus.paid,
            paidAt: DateTime.utc(2026, 3, 11),
          ),
        },
      ),
      location: MemoryDeviceLocation(
        point: const RouteEndpoint(lat: 48.97, lng: 14.47, label: 'GPS'),
      ),
    );
    await tester.pumpWidget(
      _verifyApp(services, location: '/verify/story-1/sw-1'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('home')), findsNothing);
    expect(progress.completed['story-1'], isNull);
    expect(find.text(AppStrings('cs').needAccess), findsNothing);

    gate.complete();
    await _until(
      tester,
      () => find.byKey(const Key('home')).evaluate().isNotEmpty,
    );
    expect(progress.completed['story-1'], contains('sw-1'));
    await _disposeTree(tester);
  });
}
