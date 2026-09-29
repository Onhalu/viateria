import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/memory_leaderboard.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/profile_screen.dart';

import 'bottom_nav_test.dart';
import 'helpers/fakes.dart';

/// Phone frames for the leaderboard UX review.
///
/// `CAPTURE_LEADERBOARD=1 flutter test test/leaderboard_shots_test.dart`
void main() {
  if (Platform.environment['CAPTURE_LEADERBOARD'] != '1') return;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDisableShadows = false;
  });

  tearDown(() {
    debugDisableShadows = true;
  });

  Future<void> loadFonts() async {
    await _loadFamily('Roboto', const [
      '/usr/share/fonts/truetype/macos/Inter-Regular.ttf',
      '/usr/share/fonts/truetype/macos/Inter-Medium.ttf',
      '/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf',
      '/usr/share/fonts/truetype/macos/Inter-Bold.ttf',
    ]);
    await _loadFamily('Playfair Display', const [
      'assets/fonts/PlayfairDisplay-Variable.ttf',
    ], fromBundle: true);
    await _loadFamily('MaterialIcons', const [
      '/tmp/flutter-sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  }

  void usePhone(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final me = _row('user-1', 'Tereza Malá', 27, 9, 18, 3);
  final board = MemoryLeaderboardRepository(
    me: me,
    entries: [
      _row('a', 'Eliška Králová', 48, 18, 30, 1),
      _row('b', 'Jan Novák', 36, 12, 24, 2),
      me,
      _row('d', 'Petr Svoboda', 22, 7, 15, 4),
      _row('e', 'Anna Dvořáková', 19, 4, 15, 5),
      _row('f', 'Martin Černý', 15, 6, 9, 6),
      _row('g', 'Lucie Němcová', 12, 3, 9, 7),
      _row('h', 'Tomáš Kučera', 9, 4, 5, 8),
      _row('i', 'Barbora Veselá', 7, 2, 5, 9),
      _row('j', 'Ondřej Horák', 5, 2, 3, 10),
      _row('k', 'Kateřina Marková', 4, 1, 3, 11),
      _row('l', 'Filip Beneš', 3, 0, 3, 12),
    ],
  );

  AppServices servicesFor(MemoryLeaderboardRepository leaderboard) {
    final open = sampleOpenChallenge();
    final progress = MemoryProgress(details: [open]);
    progress.statuses[open.challenge.id] = ChallengeRunStatus.completed;
    progress.completed[open.challenge.id] = {'ow-1'};
    return buildServices(
      user: const Profile(
        id: 'user-1',
        locale: 'cs',
        displayName: 'Tereza Malá',
        email: 'tereza@example.com',
      ),
      details: [open],
      challenges: [open.challenge],
      progress: progress,
      leaderboard: leaderboard,
      places: const MemoryPlaceCatalog([
        Place(
          id: 'karlstejn',
          name: 'Karlštejn',
          category: PlaceCategory.historical,
          location: GeoPoint(49.939, 14.188),
        ),
        Place(
          id: 'prazsky-hrad',
          name: 'Pražský hrad',
          category: PlaceCategory.city,
          location: GeoPoint(50.091, 14.401),
        ),
      ]),
    );
  }

  testWidgets('leaderboard review frames', (tester) async {
    await tester.runAsync(loadFonts);
    usePhone(tester);
    final services = servicesFor(board);
    await tester.pumpWidget(
      wrapApp(services, locale: LocaleController(initial: 'cs')),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byIcon(Icons.military_tech_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('catalog-welcome-avatar')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsNothing);
    await saveShot(tester, 'nav-header-lb.png');
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-bottom-nav')),
        matching: find.text('Poslední výzva'),
      ),
    );
    await tester.pumpAndSettle();
    await saveShot(tester, 'nav-bottom-profile-inactive.png');
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-bottom-nav')),
        matching: find.text('Výzvy'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'lb-full.png');

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-bottom-nav')),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(ProfileScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-leaderboard')),
      240,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    final titleTop = tester
        .getTopLeft(find.byKey(const Key('profile-completed-title')))
        .dy;
    if (titleTop < 24) {
      await tester.drag(scrollable, Offset(0, 24 - titleTop));
      await tester.pumpAndSettle();
    }
    final navTop = tester
        .getTopLeft(find.byKey(const Key('app-bottom-nav')))
        .dy;
    final cardBottom = tester
        .getBottomLeft(find.byKey(const Key('profile-leaderboard')))
        .dy;
    if (cardBottom > navTop - 16) {
      await tester.drag(scrollable, Offset(0, navTop - cardBottom - 24));
      await tester.pumpAndSettle();
    }
    expect(find.text('Otevřená stezka'), findsOneWidget);
    expect(find.text('Dokončené výzvy'), findsOneWidget);
    await saveShot(tester, 'lb-profile-teaser.png');
    await saveShot(tester, 'nav-bottom-profile-active.png');
    debugDisableShadows = true;
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('empty leaderboard frame', (tester) async {
    await tester.runAsync(loadFonts);
    usePhone(tester);
    await tester.pumpWidget(
      wrapApp(
        servicesFor(MemoryLeaderboardRepository()),
        locale: LocaleController(initial: 'cs'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'lb-empty.png');
    debugDisableShadows = true;
  }, timeout: const Timeout(Duration(seconds: 40)));

  testWidgets('error leaderboard frame', (tester) async {
    await tester.runAsync(loadFonts);
    usePhone(tester);
    await tester.pumpWidget(
      wrapApp(
        servicesFor(MemoryLeaderboardRepository()..error = StateError('down')),
        locale: LocaleController(initial: 'cs'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-welcome-leaderboard')));
    await tester.pumpAndSettle();
    await saveShot(tester, 'lb-error.png');
    debugDisableShadows = true;
  }, timeout: const Timeout(Duration(seconds: 40)));
}

LeaderboardEntry _row(
  String id,
  String name,
  int total,
  int place,
  int challenge,
  int rank,
) {
  return LeaderboardEntry(
    userId: id,
    displayName: name,
    totalPoints: total,
    placePoints: place,
    challengePoints: challenge,
    rank: rank,
  );
}

Future<void> _loadFamily(
  String family,
  List<String> paths, {
  bool fromBundle = false,
}) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final Future<ByteData> data = fromBundle
        ? rootBundle.load(path)
        : _fileBytes(path);
    loader.addFont(data);
  }
  await loader.load();
}

Future<ByteData> _fileBytes(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

Future<void> saveShot(WidgetTester tester, String name) async {
  await tester.pump();
  final element = tester.element(find.byType(MaterialApp));
  RenderObject renderObject = element.renderObject!;
  while (!renderObject.isRepaintBoundary) {
    renderObject = renderObject.parent!;
  }
  goldenFileComparator = _ArtifactGolden();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(name));
}

class _ArtifactGolden extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final name = golden.pathSegments.isEmpty
        ? golden.toString()
        : golden.pathSegments.last;
    final file = File('/opt/cursor/artifacts/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes, flush: true);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    return compare(imageBytes, golden);
  }
}
