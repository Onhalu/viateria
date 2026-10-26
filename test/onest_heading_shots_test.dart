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

import 'bottom_nav_test.dart';

/// Widget frames for the Onest heading swap.
///
/// `CAPTURE_ONEST=1 flutter test test/onest_heading_shots_test.dart`
void main() {
  if (Platform.environment['CAPTURE_ONEST'] != '1') return;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDisableShadows = false;
  });

  tearDown(() {
    debugDisableShadows = true;
  });

  testWidgets('cs challenge detail and catalog', (tester) async {
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> frame(Size size, Widget app, String name) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await _saveShot(tester, name);
    }

    const diacritics = 'ěščřžýáíéůú ďťň\nĚŠČŘŽÝÁÍÉŮÚ ĎŤŇ';
    await frame(
      const Size(390, 280),
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Text(
              diacritics,
              textAlign: TextAlign.center,
              style: BrandTypography.display(
                fontSize: 28,
                color: BrandColors.forest,
              ),
            ),
          ),
        ),
      ),
      'onest-heading-diacritics.png',
    );

    final services = buildServices();
    Widget challenge() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'cs'),
          ),
          ChangeNotifierProvider(
            create: (_) => LastOpenedChallengeStore(initialId: 'open-1'),
          ),
          Provider.value(value: services),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ChallengeScreen(challengeId: 'open-1'),
        ),
      );
    }

    for (final size in const [Size(390, 844), Size(1280, 900)]) {
      await frame(
        size,
        challenge(),
        'challenge-detail-cs-${size.width.toInt()}.png',
      );
      expect(find.text('Otevřená stezka'), findsWidgets);
      expect(find.text('Přijmi výzvu'), findsWidgets);
      final title = tester.widget<Text>(
        find.byKey(const Key('challenge-title')),
      );
      expect(title.style?.fontFamily, 'Onest');
      final cta = tester.widget<Text>(
        find.byKey(const Key('challenge-paybar-heading')),
      );
      expect(cta.style?.fontFamily, 'Onest');
      expect(cta.style?.fontVariations, [const FontVariation('wght', 700)]);
    }

    await frame(
      const Size(390, 844),
      wrapApp(services, locale: LocaleController(initial: 'cs')),
      'catalog-cs-390.png',
    );
    expect(find.text('Vítej zpět'), findsOneWidget);
    expect(find.text('Otevřená stezka'), findsWidgets);
    final cardTitle = tester.widget<Text>(find.text('Otevřená stezka').first);
    expect(cardTitle.style?.fontFamily, anyOf(isNull, 'Roboto'));
    debugDisableShadows = true;
  });
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
  const iconCandidates = [
    '/tmp/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/tmp/flutter-sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  final icons = iconCandidates.firstWhere(
    (path) => File(path).existsSync(),
    orElse: () => iconCandidates.first,
  );
  await family('MaterialIcons', [icons]);
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
