import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/domain/challenge_photos.dart';
import 'package:viateria/domain/stop_verify.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/challenge_photos_section.dart';

import 'helpers/fakes.dart';

final _png = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugChallengePhotoImageProvider = (_) => _png;
  });

  tearDown(() {
    debugChallengePhotoImageProvider = null;
  });

  group('displayable paths', () {
    test('keeps real photo objects and drops blank or GPS sentinels', () {
      expect(displayablePhotoPath(null), isNull);
      expect(displayablePhotoPath(''), isNull);
      expect(displayablePhotoPath('   '), isNull);
      expect(
        displayablePhotoPath(
          VerifyProximity.gpsPhotoPath(
            userId: 'user-1',
            challengeId: 'open-1',
            waypointId: 'ow-1',
          ),
        ),
        isNull,
      );
      expect(
        displayablePhotoPath(' user-2/open-1/ow-1/a.jpg '),
        'user-2/open-1/ow-1/a.jpg',
      );
    });

    test('resolve keeps row order and throws when every URL fails', () {
      final rows = [
        ChallengeWaypointPhoto(
          challengeId: 'open-1',
          waypointId: 'ow-2',
          photoPath: 'user-b/open-1/ow-2/b.jpg',
          completedAt: DateTime.utc(2026, 9, 3),
        ),
        ChallengeWaypointPhoto(
          challengeId: 'open-1',
          waypointId: 'ow-1',
          photoPath: 'user-a/gps/open-1/ow-1',
          completedAt: DateTime.utc(2026, 9, 4),
        ),
        ChallengeWaypointPhoto(
          challengeId: 'open-1',
          waypointId: 'ow-1',
          photoPath: 'user-a/open-1/ow-1/a.jpg',
          completedAt: DateTime.utc(2026, 9, 2),
        ),
      ];
      final photos = resolveChallengePhotoGallery(
        rows: rows,
        urls: {
          'user-b/open-1/ow-2/b.jpg': 'https://photos.test/b',
          'user-a/open-1/ow-1/a.jpg': 'https://photos.test/a',
        },
      );
      expect(photos.map((photo) => photo.imageUrl), [
        'https://photos.test/b',
        'https://photos.test/a',
      ]);
      expect(
        () => resolveChallengePhotoGallery(rows: rows, urls: const {}),
        throwsStateError,
      );
      expect(
        resolveChallengePhotoGallery(rows: const [], urls: const {}),
        isEmpty,
      );
    });
  });

  group('mosaic', () {
    test('cycles 3:4, 1:1, 4:3 across two staggered columns', () {
      expect(challengePhotoGap, 8);
      expect(challengePhotoRadius, 12);
      expect(challengePhotoAspectRatio(0), 3 / 4);
      expect(challengePhotoAspectRatio(1), 1);
      expect(challengePhotoAspectRatio(2), 4 / 3);
      expect(challengePhotoAspectRatio(3), 3 / 4);

      const width = 768.0;
      final layout = layoutChallengePhotoMosaic(count: 3, width: width);
      expect(layout.tiles, hasLength(3));
      final tile0 = layout.tiles[0];
      final tile1 = layout.tiles[1];
      final tile2 = layout.tiles[2];
      expect(tile0.width, (width - challengePhotoGap) / 2);
      expect(tile0.height / tile0.width, closeTo(4 / 3, 0.001));
      expect(tile1.height / tile1.width, closeTo(1, 0.001));
      expect(tile2.width / tile2.height, closeTo(4 / 3, 0.001));
      expect(tile1.left - tile0.right, closeTo(challengePhotoGap, 0.001));
      expect(tile0.top, 0);
      expect(tile1.top, 0);
      // Shorter right column receives the third tile before the left column ends.
      expect(tile2.left, closeTo(tile1.left, 0.001));
      expect(tile2.top - tile1.bottom, closeTo(challengePhotoGap, 0.001));
      expect(tile2.top, lessThan(tile0.bottom));

      final bands = bandChallengePhotoMosaic(layout, targetExtent: 200);
      final seen = <int>[];
      var covered = 0.0;
      for (final band in bands) {
        covered += band.height;
        for (final tile in band.tiles) {
          expect(seen, isNot(contains(tile.index)));
          expect(tile.top, greaterThanOrEqualTo(band.top - 0.01));
          expect(tile.bottom, lessThanOrEqualTo(band.top + band.height + 0.01));
          seen.add(tile.index);
        }
      }
      expect(seen, [0, 1, 2]);
      expect(covered, closeTo(layout.height, 0.01));
    });
  });

  test('community query includes every user on this challenge only', () async {
    final progress = MemoryProgress(details: [sampleOpenChallenge()])
      ..photos.addAll([
        ChallengeWaypointPhoto(
          challengeId: 'open-1',
          waypointId: 'ow-1',
          photoPath: 'user-a/open-1/ow-1/a.jpg',
          completedAt: DateTime.utc(2026, 9, 2),
        ),
        ChallengeWaypointPhoto(
          challengeId: 'open-1',
          waypointId: 'ow-2',
          photoPath: 'user-b/open-1/ow-2/b.jpg',
          completedAt: DateTime.utc(2026, 9, 3),
        ),
        ChallengeWaypointPhoto(
          challengeId: 'open-1',
          waypointId: 'ow-1',
          photoPath: VerifyProximity.gpsPhotoPath(
            userId: 'user-a',
            challengeId: 'open-1',
            waypointId: 'ow-1',
          ),
          completedAt: DateTime.utc(2026, 9, 4),
        ),
        ChallengeWaypointPhoto(
          challengeId: 'open-1',
          waypointId: 'ow-1',
          photoPath: '   ',
          completedAt: DateTime.utc(2026, 9, 4),
        ),
        ChallengeWaypointPhoto(
          challengeId: 'story-1',
          waypointId: 'sw-1',
          photoPath: 'user-c/story-1/sw-1/c.jpg',
          completedAt: DateTime.utc(2026, 9, 5),
        ),
      ]);
    final rows = await progress.fetchChallengePhotos('open-1');
    expect(rows.map((row) => row.photoPath), [
      'user-b/open-1/ow-2/b.jpg',
      'user-a/open-1/ow-1/a.jpg',
    ]);
  });

  test('migration exposes published verification photos, not auth.uid()', () {
    final sql = File('supabase/migrations/0008_challenge_waypoint_photos.sql')
        .readAsStringSync();
    expect(sql, contains('challenge_waypoint_photos'));
    expect(sql, contains('photo_path is not null'));
    expect(sql, contains("bucket_id = 'waypoint-photos'"));
    expect(sql, contains('%/gps/%'));
    expect(
      sql,
      contains(
        'grant select on table public.challenge_waypoint_photos to authenticated',
      ),
    );
    expect(sql, isNot(contains('auth.uid()')));
    expect(
      sql,
      contains(
        'revoke all on table public.challenge_waypoint_photos from anon',
      ),
    );
  });

  testWidgets('empty gallery sits under the reward block', (tester) async {
    usePhotoView(tester);
    final strings = AppStrings('cs');
    await tester.pumpWidget(wrapChallenge(buildPhotoServices(), locale: 'cs'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('challenge-photos-title')));
    expect(find.text(strings.challengePhotosTitle), findsOneWidget);
    expect(find.text(strings.challengePhotosEmpty), findsOneWidget);
    expect(find.byKey(const Key('challenge-photo-tile-0')), findsNothing);
    final title = tester.widget<Text>(
      find.byKey(const Key('challenge-photos-title')),
    );
    final empty = tester.widget<Text>(
      find.byKey(const Key('challenge-photos-empty')),
    );
    expect(title.style?.color, BrandColors.forest);
    expect(empty.style?.color, BrandColors.bark);
    expect(
      tester.getTopLeft(find.byKey(const Key('challenge-reward-section'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('challenge-photos-section'))).dy,
      ),
    );
  });

  testWidgets('mosaic opens a swipeable lightbox of this challenge', (
    tester,
  ) async {
    usePhotoView(tester);
    final open = sampleOpenChallenge();
    final progress = MemoryProgress(details: [open])
      ..photos.addAll(sampleGalleryRows());
    final photos = MemoryPhotos();
    await tester.pumpWidget(
      wrapChallenge(
        buildPhotoServices(progress: progress, photos: photos, detail: open),
        locale: 'en',
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('challenge-photo-tile-2')));

    expect(find.byKey(const Key('challenge-photo-tile-0')), findsOneWidget);
    expect(find.byKey(const Key('challenge-photo-tile-1')), findsOneWidget);
    expect(find.byKey(const Key('challenge-photo-tile-2')), findsOneWidget);
    expect(find.byKey(const Key('challenge-photo-tile-3')), findsNothing);
    expect(photos.signedPhotoCalls.single, [
      'user-b/open-1/ow-2/b.jpg',
      'user-a/open-1/ow-1/a.jpg',
      'user-c/open-1/ow-1/c.jpg',
    ]);

    final tile0 = tester.getRect(
      find.byKey(const Key('challenge-photo-tile-0')),
    );
    final tile1 = tester.getRect(
      find.byKey(const Key('challenge-photo-tile-1')),
    );
    final tile2 = tester.getRect(
      find.byKey(const Key('challenge-photo-tile-2')),
    );
    expect(tile0.height / tile0.width, closeTo(4 / 3, 0.02));
    expect(tile1.height / tile1.width, closeTo(1, 0.02));
    expect(tile2.width / tile2.height, closeTo(4 / 3, 0.02));
    expect(tile1.left - tile0.right, closeTo(8, 0.6));
    expect(tile2.left, closeTo(tile1.left, 0.6));
    expect(tile2.top, lessThan(tile0.bottom));
    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byKey(const Key('challenge-photo-tile-0')),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(
      clip.borderRadius,
      const BorderRadius.all(Radius.circular(challengePhotoRadius)),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('challenge-photo-tile-0')),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('challenge-photo-tile-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenge-photo-lightbox')), findsOneWidget);
    expect(find.text('Ridge'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('challenge-photo-caption')))
          .data,
      'Ridge',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('challenge-photo-caption')))
          .style
          ?.color,
      BrandColors.forest,
    );
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const Key('challenge-photo-caption-bar')),
          )
          .color,
      BrandColors.cream,
    );
    expect(
      tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .map((barrier) => barrier.color),
      contains(BrandColors.forest.withValues(alpha: 0.8)),
    );

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('challenge-photo-caption')))
          .data,
      'Start',
    );

    await tester.tap(find.byKey(const Key('challenge-photo-lightbox-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenge-photo-lightbox')), findsNothing);
  });
}

List<ChallengeWaypointPhoto> sampleGalleryRows() {
  return [
    ChallengeWaypointPhoto(
      challengeId: 'open-1',
      waypointId: 'ow-2',
      photoPath: 'user-b/open-1/ow-2/b.jpg',
      completedAt: DateTime.utc(2026, 9, 3),
    ),
    ChallengeWaypointPhoto(
      challengeId: 'open-1',
      waypointId: 'ow-1',
      photoPath: 'user-a/open-1/ow-1/a.jpg',
      completedAt: DateTime.utc(2026, 9, 2),
    ),
    ChallengeWaypointPhoto(
      challengeId: 'open-1',
      waypointId: 'ow-1',
      photoPath: 'user-c/open-1/ow-1/c.jpg',
      completedAt: DateTime.utc(2026, 8, 1),
    ),
    ChallengeWaypointPhoto(
      challengeId: 'open-1',
      waypointId: 'ow-1',
      photoPath: VerifyProximity.gpsPhotoPath(
        userId: 'user-a',
        challengeId: 'open-1',
        waypointId: 'ow-1',
      ),
      completedAt: DateTime.utc(2026, 9, 4),
    ),
    ChallengeWaypointPhoto(
      challengeId: 'story-1',
      waypointId: 'sw-1',
      photoPath: 'user-z/story-1/sw-1/z.jpg',
      completedAt: DateTime.utc(2026, 9, 6),
    ),
  ];
}

AppServices buildPhotoServices({
  MemoryProgress? progress,
  MemoryPhotos? photos,
  ChallengeDetail? detail,
}) {
  final open = detail ?? sampleOpenChallenge();
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
    photos: photos ?? MemoryPhotos(),
    photoCapture: MemoryCapture(),
    openUrl: (_) async {},
  );
}

Widget wrapChallenge(AppServices services, {String locale = 'cs'}) {
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
      child: MaterialApp(home: const ChallengeScreen(challengeId: 'open-1')),
    ),
  );
}

void usePhotoView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
