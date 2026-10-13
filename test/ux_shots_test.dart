import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';

import 'auth_register_form_test.dart';
import 'bottom_nav_test.dart';

/// Before/after frames for the UX audit.
///
/// `CAPTURE_UX=1 UX_SHOT_PREFIX=after flutter test test/ux_shots_test.dart`
void main() {
  if (Platform.environment['CAPTURE_UX'] != '1') return;

  TestWidgetsFlutterBinding.ensureInitialized();
  final prefix = Platform.environment['UX_SHOT_PREFIX'] ?? 'after';

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
      '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  }

  void useView(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
  }

  testWidgets('ux audit frames', (tester) async {
    await tester.runAsync(loadFonts);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shot(String name) => saveShot(tester, '$prefix-$name.png');

    Future<void> resetTree() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    for (final frame in const [
      (name: 'login-mobile', size: Size(390, 844)),
      (name: 'login-desktop', size: Size(1280, 800)),
    ]) {
      useView(tester, frame.size);
      await resetTree();
      await tester.pumpWidget(wrapAuth());
      await tester.pumpAndSettle();
      await shot(frame.name);
    }

    for (final frame in const [
      (name: 'catalog-mobile', size: Size(390, 844)),
      (name: 'catalog-desktop', size: Size(1280, 900)),
    ]) {
      useView(tester, frame.size);
      await resetTree();
      await tester.pumpWidget(
        wrapApp(buildServices(), locale: LocaleController(initial: 'cs')),
      );
      await tester.pumpAndSettle();
      await shot(frame.name);
    }

    for (final frame in const [
      (name: 'challenge-mobile', size: Size(390, 1400)),
      (name: 'challenge-desktop', size: Size(1280, 1200)),
    ]) {
      useView(tester, frame.size);
      await resetTree();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LocaleController(initial: 'cs'),
            ),
            ChangeNotifierProvider(
              create: (_) => LastOpenedChallengeStore(initialId: 'story-1'),
            ),
            Provider.value(value: buildServices()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const ChallengeScreen(challengeId: 'story-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('challenge-pay-diploma')), findsOneWidget);
      expect(find.byKey(const Key('challenge-pay-medal')), findsOneWidget);
      await shot(frame.name);
    }

    for (final frame in const [
      (name: 'map-mobile', size: Size(390, 844)),
      (name: 'map-desktop', size: Size(1280, 800)),
    ]) {
      useView(tester, frame.size);
      await resetTree();
      await tester.pumpWidget(
        wrapApp(buildServices(), locale: LocaleController(initial: 'cs')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.map_outlined).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await shot(frame.name);
    }
    debugDisableShadows = true;
  });
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
