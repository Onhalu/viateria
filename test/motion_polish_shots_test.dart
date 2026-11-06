import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/repositories.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/motion/like_save_button.dart';
import 'package:viateria/ui/widgets/places_map_panels.dart';

import 'auth_register_form_test.dart';
import 'bottom_nav_test.dart';
import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

/// Pixel frames for the motion polish.
///
/// `CAPTURE_MOTION=1 flutter test test/motion_polish_shots_test.dart`
void main() {
  if (Platform.environment['CAPTURE_MOTION'] != '1') return;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('motion polish frames at 390 and 1280', (tester) async {
    debugDisableShadows = false;
    try {
      await _capture(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

Future<void> _capture(WidgetTester tester) async {
  await tester.runAsync(_loadFonts);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  Future<void> shot(String name) async {
    await tester.pump();
    goldenFileComparator = _ArtifactGolden();
    await expectLater(find.byType(MaterialApp).first, matchesGoldenFile(name));
  }

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final tag = size.width.round();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      wrapApp(buildServices(), locale: LocaleController(initial: 'cs')),
    );
    await tester.pumpAndSettle();
    final strings = AppStrings('cs');
    final nav = find.byKey(
      Key(size.width >= 840 ? 'app-nav-rail' : 'app-bottom-nav'),
    );
    await tester.tap(
      find.descendant(of: nav, matching: find.text(strings.navLastChallenge)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    await shot('motion-tab-$tag.png');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: BrandColors.cream,
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  const SizedBox(height: 48),
                  LikeSaveButton(
                    key: const Key('shot-like'),
                    saved: saved,
                    saveLabel: strings.savePlace,
                    savedLabel: strings.placeSaved,
                    onChanged: (value) => setState(() => saved = value),
                  ),
                  Expanded(
                    child: PlaceListPanel(
                      places: samplePlaces(),
                      strings: strings,
                      userLocation: null,
                      onSelect: (_) {},
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shot-like')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await shot('motion-like-$tag.png');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final auth = MemoryAuth()
      ..signInError = const AuthFailure('Nesprávné heslo.');
    await tester.pumpWidget(wrapAuth(auth: auth));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'spatne');
    await tester.tap(find.byKey(const Key('auth-sign-in')));
    await tester.pump();
    await tester.pumpAndSettle();
    await shot('motion-auth-$tag.png');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }
}

Future<void> _loadFonts() async {
  await _loadFamily('Roboto', const [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
  ]);
  await _loadFamily('Onest', const [
    'assets/fonts/Onest[wght].ttf',
  ], fromBundle: true);
  const icons = [
    '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in icons) {
    if (File(path).existsSync()) {
      await _loadFamily('MaterialIcons', [path]);
      break;
    }
  }
}

Future<void> _loadFamily(
  String family,
  List<String> paths, {
  bool fromBundle = false,
}) async {
  final loader = FontLoader(family);
  var added = false;
  for (final path in paths) {
    if (!fromBundle && !File(path).existsSync()) continue;
    final Future<ByteData> data = fromBundle
        ? rootBundle.load(path)
        : _fileBytes(path);
    loader.addFont(data);
    added = true;
  }
  if (added) await loader.load();
}

Future<ByteData> _fileBytes(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
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
    // Touch the codec so a truncated write fails the shot.
    final codec = await ui.instantiateImageCodec(imageBytes);
    await codec.getNextFrame();
    codec.dispose();
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    return compare(imageBytes, golden);
  }
}
