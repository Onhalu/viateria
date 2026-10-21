import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/theme/brand_assets.dart';

const _forbidden = [
  '0xFFD4A017',
  '0xFF2D6A4F',
  '0xFF1B4332',
  '0xFF3D2914',
  '0xFFF7F3E9',
  '#D4A017',
  '#2D6A4F',
  '#1B4332',
  '#3D2914',
  '#F7F3E9',
];

Iterable<String> _codeWithoutComments(String source) sync* {
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//')) continue;
    final index = line.indexOf('//');
    yield index == -1 ? line : line.substring(0, index);
  }
}

void main() {
  test('AppTheme and MapPalette share BrandColors tokens', () {
    expect(BrandColors.forest, const Color(0xFF35483C));
    expect(BrandColors.sage, const Color(0xFF9C9A7B));
    expect(BrandColors.shellFill, const Color(0xFF7D8B6A));
    expect(BrandColors.shellFill, isNot(BrandColors.sage));
    expect(BrandColors.cream, const Color(0xFFF3EFE5));
    expect(BrandColors.neutral, const Color(0xFFFAF8F2));
    expect(BrandColors.beige, const Color(0xFFD8CDB8));
    expect(BrandColors.bark, const Color(0xFF756653));
    expect(BrandColors.onPrimary, BrandColors.cream);
    expect(BrandColors.ink, BrandColors.forest);
    expect(BrandColors.onCream, BrandColors.forest);
    expect(BrandColors.muted, BrandColors.bark);
    expect(BrandColors.success, BrandColors.forest);
    expect(BrandColors.warning, BrandColors.sage);
    expect(BrandColors.error, const Color(0xFFBA1A1A));
    expect(BrandColors.creamPill, BrandColors.cream.withValues(alpha: 0.22));
    expect(BrandColors.shellShadow, BrandColors.forest.withValues(alpha: 0.13));

    expect(AppTheme.forest, MapPalette.forest);
    expect(AppTheme.cream, MapPalette.cream);
    expect(AppTheme.bark, MapPalette.bark);
    expect(AppTheme.sage, MapPalette.sage);
    expect(AppTheme.beige, MapPalette.beige);
    expect(AppTheme.neutral, MapPalette.neutral);
    expect(AppTheme.onPrimary, BrandColors.onPrimary);
    expect(identical(MapPalette.forest, BrandColors.forest), isTrue);
  });

  test('light ColorScheme uses forest primary and cream surfaces', () {
    final scheme = AppTheme.light().colorScheme;
    expect(scheme.primary, BrandColors.forest);
    expect(scheme.onPrimary, BrandColors.onPrimary);
    expect(scheme.secondary, BrandColors.sage);
    expect(scheme.surface, BrandColors.cream);
    expect(scheme.onSurface, BrandColors.ink);
    expect(scheme.error, BrandColors.error);
    expect(scheme.outline, BrandColors.beige);

    final theme = AppTheme.light();
    expect(theme.scaffoldBackgroundColor, BrandColors.cream);
    expect(theme.appBarTheme.backgroundColor, BrandColors.cream);
    expect(theme.appBarTheme.foregroundColor, BrandColors.forest);
    expect(theme.navigationBarTheme.backgroundColor, BrandColors.shellFill);
    expect(theme.navigationBarTheme.indicatorColor, BrandColors.creamPill);
    expect(
      theme.navigationBarTheme.iconTheme?.resolve({
        WidgetState.selected,
      })?.color,
      BrandColors.cream,
    );
    expect(
      theme.navigationBarTheme.iconTheme?.resolve({})?.color,
      BrandColors.forest.withValues(alpha: 0.75),
    );
    expect(
      theme.navigationBarTheme.labelTextStyle?.resolve({
        WidgetState.selected,
      })?.color,
      BrandColors.cream,
    );
    expect(
      theme.navigationBarTheme.labelTextStyle?.resolve({
        WidgetState.selected,
      })?.fontWeight,
      FontWeight.w600,
    );
    expect(
      theme.navigationBarTheme.labelTextStyle?.resolve({})?.color,
      BrandColors.forest.withValues(alpha: 0.75),
    );
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      BrandColors.forest,
    );
    expect(
      theme.filledButtonTheme.style?.foregroundColor?.resolve({}),
      BrandColors.onPrimary,
    );
    expect(
      theme.outlinedButtonTheme.style?.backgroundColor?.resolve({}),
      BrandColors.cream,
    );
    expect(
      theme.outlinedButtonTheme.style?.foregroundColor?.resolve({}),
      BrandColors.forest,
    );
    expect(theme.chipTheme.backgroundColor, BrandColors.beige);
    expect(theme.chipTheme.selectedColor, BrandColors.forest);
    expect(theme.chipTheme.labelStyle?.color, BrandColors.forest);
    expect(theme.chipTheme.secondaryLabelStyle?.color, BrandColors.cream);
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({}),
      const Size(64, 44),
    );
    expect(
      theme.filledButtonTheme.style?.animationDuration,
      const Duration(milliseconds: 120),
    );
    expect(theme.extension<AppButtonSizes>()?.lHeight, 52);
    expect(theme.extension<AppButtonSizes>()?.gapFloating, 32);
  });

  test('user-facing appName is VANDERY in cs, en and de', () {
    for (final locale in AppStrings.supported) {
      expect(AppStrings(locale).appName, 'VANDERY');
    }
  });

  test('brand raster assets exist for mark, lockup and on-primary', () {
    const files = [
      'assets/brand/vandery-mark.png',
      'assets/brand/vandery-lockup.png',
      'assets/brand/vandery-mark-on-primary.png',
      'assets/brand/vandery-lockup-on-primary.png',
      'assets/brand/vandery-mark@2x.png',
      'assets/brand/vandery-lockup@2x.png',
      'assets/brand/2.0x/vandery-mark.png',
      'assets/brand/3.0x/vandery-lockup.png',
    ];
    for (final path in files) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(BrandAssets.splashLockupWidth, inInclusiveRange(120, 160));
    expect(BrandAssets.markMinSize, 24);
  });

  test('lib UI sources do not use retired gold/moss/old forest/bark/cream', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in dartFiles) {
      final code = _codeWithoutComments(file.readAsStringSync()).join('\n');
      for (final token in _forbidden) {
        expect(
          code.contains(token),
          isFalse,
          reason: '${file.path} still contains $token',
        );
      }
      expect(code.contains('AppTheme.gold'), isFalse, reason: file.path);
      expect(code.contains('AppTheme.moss'), isFalse, reason: file.path);
    }
  });

  testWidgets('splash lockup is 120–160 dp wide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandLockup())),
      ),
    );
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(BrandLockup));
    expect(size.width, inInclusiveRange(120, 160));
  });

  testWidgets('brand mark is at least 24 dp', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandMark())),
      ),
    );
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(BrandMark));
    expect(size.width, greaterThanOrEqualTo(24));
    expect(size.height, greaterThanOrEqualTo(24));
  });

  test('heading TextStyle family is Manrope', () {
    final theme = AppTheme.light();
    expect(theme.textTheme.displaySmall?.fontFamily, 'Manrope');
    expect(theme.textTheme.headlineMedium?.fontFamily, 'Manrope');
    expect(theme.textTheme.headlineSmall?.fontFamily, 'Manrope');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Manrope');
    expect(AppTheme.displayFont, 'Manrope');
    expect(BrandTypography.display(fontSize: 20).fontFamily, 'Manrope');

    // Playfair 600 becomes Manrope 700. Playfair 700 stays 700.
    expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w700);
    expect(
      BrandTypography.mapPlayfairWeight(FontWeight.w600),
      FontWeight.w700,
    );
    expect(
      BrandTypography.mapPlayfairWeight(FontWeight.w700),
      FontWeight.w700,
    );

    // −1% tracking from 24 sp. „Přijmi výzvu“ stays 20 / 26.
    expect(theme.textTheme.displaySmall?.fontSize, 32);
    expect(theme.textTheme.displaySmall?.letterSpacing, closeTo(-0.32, 0.0001));
    expect(theme.textTheme.headlineMedium?.letterSpacing, closeTo(-0.28, 0.0001));
    expect(theme.textTheme.headlineSmall?.letterSpacing, 0);
    expect(theme.textTheme.headlineSmall?.height, greaterThanOrEqualTo(1.2));
    final cta = BrandTypography.display(fontSize: 20, height: 26 / 20);
    expect(cta.fontSize, 20);
    expect(cta.height, 26 / 20);
    expect(cta.letterSpacing, 0);
    expect(BrandTypography.display(fontSize: 24, height: 1.15).height, 1.2);

    // Body stays on the Material sans, not Manrope.
    expect(theme.textTheme.bodyLarge?.fontFamily, isNot('Manrope'));
    expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Manrope'));
    expect(theme.textTheme.bodySmall?.fontFamily, isNot('Manrope'));
    expect(theme.textTheme.labelLarge?.fontFamily, isNot('Manrope'));

    final license = File('assets/licenses/OFL.txt').readAsStringSync();
    expect(license, contains('SIL OPEN FONT LICENSE'));
    expect(license, contains('Manrope'));
  });
}
