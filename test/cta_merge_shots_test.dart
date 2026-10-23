import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_typography.dart';

import 'bottom_nav_test.dart';
import 'helpers/catalog_finders.dart';
import 'helpers/fakes.dart';

/// Merged payment-bar frames.
///
/// `CAPTURE_CTA=1 flutter test test/cta_merge_shots_test.dart`
void main() {
  if (Platform.environment['CAPTURE_CTA'] != '1') return;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDisableShadows = false;
  });

  tearDown(() {
    debugDisableShadows = true;
  });

  testWidgets('closed, open, and mid payment bar at 390 and 1280', (
    tester,
  ) async {
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = '${details.exception}';
      if (message.contains('PlacesMapController')) return;
      if (message.contains('HttpException')) return;
      previousError?.call(details);
    };

    try {
      for (final width in const [390.0, 1280.0]) {
        final height = width < 600 ? 844.0 : 900.0;
        for (final locale in const ['cs', 'en', 'de']) {
          await _openDetail(tester, Size(width, height), locale);
          await _saveShot(tester, 'cta-closed-$locale-${width.toInt()}.png');

          await _revealPayBar(tester);
          if (locale == 'cs') {
            await tester.pump(const Duration(milliseconds: 120));
            await _saveShot(tester, 'cta-mid-cs-${width.toInt()}.png');
          }
          await tester.pump(const Duration(milliseconds: 400));
          await _saveShot(tester, 'cta-open-$locale-${width.toInt()}.png');
        }
      }
    } finally {
      FlutterError.onError = previousError;
      debugDisableShadows = true;
    }
  });
}

Future<void> _openDetail(WidgetTester tester, Size size, String locale) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    wrapApp(_shotServices(), locale: LocaleController(initial: locale)),
  );
  await tester.pumpAndSettle();
  final card = find.byKey(const Key('catalog-hero-open-1'));
  await tester.scrollUntilVisible(
    card,
    400,
    scrollable: catalogVerticalScrollable(),
  );
  await tester.tap(card);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

/// A long description parks the in-page buttons below a 900 dp window, and
/// extra stops give the wide feed enough scroll to cross the show threshold.
ChallengeDetail _shotOpenChallenge() {
  final base = sampleOpenChallenge();
  const sentence =
      'The trail crosses open meadows, a quiet ridge, and two village squares before the last gate. ';
  final description = sentence * 36;
  final challenge = Challenge(
    id: base.challenge.id,
    slug: base.challenge.slug,
    accessMode: base.challenge.accessMode,
    pricingType: base.challenge.pricingType,
    priceCents: base.challenge.priceCents,
    diplomaPriceCents: base.challenge.diplomaPriceCents,
    medalPriceCents: base.challenge.medalPriceCents,
    currency: base.challenge.currency,
    status: base.challenge.status,
    countryCode: base.challenge.countryCode,
    fapiFormUrlDiploma: 'https://form.fapi.cz/diploma-test',
    fapiFormUrlMedal: 'https://form.fapi.cz/medal-test',
    translations: [
      LocalizedText(
        locale: 'en',
        title: 'Open trail',
        description: description,
      ),
      LocalizedText(
        locale: 'cs',
        title: 'Otevřená stezka',
        description: description,
      ),
      LocalizedText(
        locale: 'de',
        title: 'Offener Pfad',
        description: description,
      ),
    ],
  );
  final waypoints = [
    ...base.waypoints,
    for (var index = 0; index < 8; index++)
      Waypoint(
        id: 'ow-extra-$index',
        challengeId: 'open-1',
        sortOrder: index + 2,
        lat: 50.1 + index * 0.01,
        lng: 14.5 + index * 0.01,
        elevationM: 300 + index * 20,
        translations: [
          LocalizedText(locale: 'en', title: 'Stop ${index + 3}'),
          LocalizedText(locale: 'cs', title: 'Zastávka ${index + 3}'),
          LocalizedText(locale: 'de', title: 'Halt ${index + 3}'),
        ],
      ),
  ];
  return ChallengeDetail(challenge: challenge, waypoints: waypoints);
}

AppServices _shotServices() {
  final open = _shotOpenChallenge();
  final story = sampleStoryChallenge();
  return buildServices(
    challenges: [open.challenge, story.challenge],
    details: [open, story],
  );
}

Future<void> _revealPayBar(WidgetTester tester) async {
  final feed = find.byKey(const Key('challenge-feed-scroll'));
  if (feed.evaluate().isNotEmpty) {
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: feed, matching: find.byType(Scrollable)).first,
    );
    final position = scrollable.position;
    final target = position.viewportDimension * 0.55;
    if (position.maxScrollExtent > 0) {
      position.jumpTo(target.clamp(0, position.maxScrollExtent));
    }
  }
  await tester.pump();
}

Future<void> _loadFonts() async {
  Future<void> family(
    String name,
    List<String> paths, {
    bool fromBundle = false,
  }) async {
    final loader = FontLoader(name);
    for (final path in paths) {
      final Future<ByteData> data = fromBundle
          ? rootBundle.load(path)
          : File(path).readAsBytes().then(
              (bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
            );
      loader.addFont(data);
    }
    await loader.load();
  }

  await family('Roboto', const [
    '/usr/share/fonts/truetype/macos/Inter-Regular.ttf',
    '/usr/share/fonts/truetype/macos/Inter-Medium.ttf',
    '/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf',
    '/usr/share/fonts/truetype/macos/Inter-Bold.ttf',
  ]);
  await family('Onest', const [BrandTypography.fontAsset], fromBundle: true);
  await family('MaterialIcons', const [
    '/home/ubuntu/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _saveShot(WidgetTester tester, String name) async {
  await tester.pump();
  goldenFileComparator = _ArtifactGolden();
  await expectLater(find.byType(MaterialApp).first, matchesGoldenFile(name));
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
