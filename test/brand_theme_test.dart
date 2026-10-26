import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  test('heading TextStyle family is Onest', () {
    final theme = AppTheme.light();
    expect(theme.textTheme.displaySmall?.fontFamily, 'Onest');
    expect(theme.textTheme.headlineMedium?.fontFamily, 'Onest');
    expect(theme.textTheme.headlineSmall?.fontFamily, 'Onest');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Onest');
    expect(AppTheme.displayFont, 'Onest');
    expect(BrandTypography.display(fontSize: 20).fontFamily, 'Onest');

    // Former Playfair 600 and 700 both map to Onest 700.
    expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w700);
    expect(BrandTypography.mapPlayfairWeight(FontWeight.w600), FontWeight.w700);
    expect(BrandTypography.mapPlayfairWeight(FontWeight.w700), FontWeight.w700);
    expect(theme.textTheme.displaySmall?.fontVariations, [
      const FontVariation('wght', 700),
    ]);
    expect(BrandTypography.display(fontSize: 20).fontVariations, [
      const FontVariation('wght', 700),
    ]);
    expect(
      BrandTypography.display(
        fontSize: 24,
        fontWeight: FontWeight.w400,
      ).fontVariations,
      [const FontVariation('wght', 400)],
    );
    expect(
      BrandTypography.display(fontSize: 32).fontVariations?.map((v) => v.axis),
      ['wght'],
    );

    // −1% tracking from 24 sp. „Přijmi výzvu“ stays 20 / 26.
    expect(theme.textTheme.displaySmall?.fontSize, 32);
    expect(theme.textTheme.displaySmall?.letterSpacing, closeTo(-0.32, 0.0001));
    expect(
      theme.textTheme.headlineMedium?.letterSpacing,
      closeTo(-0.28, 0.0001),
    );
    expect(theme.textTheme.headlineSmall?.letterSpacing, 0);
    expect(theme.textTheme.headlineSmall?.height, greaterThanOrEqualTo(1.2));
    final cta = BrandTypography.display(fontSize: 20, height: 26 / 20);
    expect(cta.fontSize, 20);
    expect(cta.height, 26 / 20);
    expect(cta.letterSpacing, 0);
    expect(BrandTypography.display(fontSize: 24, height: 1.15).height, 1.2);

    // Body and catalog card titles stay on the Material sans.
    for (final style in [
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.bodySmall,
      theme.textTheme.labelLarge,
      theme.textTheme.titleMedium,
    ]) {
      expect(style?.fontFamily, anyOf(isNull, 'Roboto'));
      expect(style?.fontFamily, isNot('Onest'));
    }

    final license = File(BrandTypography.licenseAsset).readAsStringSync();
    expect(license, contains('SIL OPEN FONT LICENSE'));
    expect(license, contains('Onest'));
    expect(license, isNot(contains('Bricolage')));

    final cards = File('lib/ui/widgets/catalog_cards.dart').readAsStringSync();
    expect(cards.contains('fontFamily'), isFalse);
    expect(cards.contains('Onest'), isFalse);
    expect(cards.contains('BrandTypography'), isFalse);
  });

  test('bundled Onest covers Czech heading diacritics', () {
    final bytes = File(BrandTypography.fontAsset).readAsBytesSync();
    final covered = _cmapCoverage(bytes);
    const sample = 'ěščřžýáíéůúďťňĚŠČŘŽÝÁÍÉŮÚĎŤŇ';
    for (final rune in sample.runes) {
      expect(
        covered.contains(rune),
        isTrue,
        reason: 'U+${rune.toRadixString(16).toUpperCase()} $sample',
      );
    }
    expect(_fvarAxes(bytes), ['wght']);
  });

  testWidgets('wght axis paints Czech headings', (tester) async {
    final loader = FontLoader(BrandTypography.family);
    loader.addFont(rootBundle.load(BrandTypography.fontAsset));
    await tester.runAsync(loader.load);

    const sample = 'ěščřžýáíéůú ďťň ĚŠČŘŽÝÁÍÉŮÚ ĎŤŇ';

    double painted(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: sample, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    final light = painted(
      BrandTypography.display(fontSize: 32, fontWeight: FontWeight.w100),
    );
    final regular = painted(
      BrandTypography.display(fontSize: 32, fontWeight: FontWeight.w400),
    );
    final bold = painted(BrandTypography.display(fontSize: 32));
    final black = painted(
      BrandTypography.display(fontSize: 32, fontWeight: FontWeight.w900),
    );
    // A missing wght axis collapses these to the Regular master.
    expect(regular - light, greaterThan(4));
    expect(bold - regular, greaterThan(4));
    expect(black - bold, greaterThan(4));

    final style = BrandTypography.display(fontSize: 32);
    expect(style.height, greaterThanOrEqualTo(BrandTypography.minLineHeight));
    final painter = TextPainter(
      text: TextSpan(text: sample, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    // Skia rounds the strut. The style multiplier stays at least 1.2.
    expect(
      painter.preferredLineHeight,
      closeTo(style.fontSize! * style.height!, 1),
    );

    final title = AppTheme.light().textTheme.titleLarge!;
    expect(title.fontFamily, 'Onest');
    expect(title.fontVariations, [const FontVariation('wght', 700)]);
    TextStyle weighted(FontWeight weight) => title.copyWith(
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
    expect(
      painted(weighted(FontWeight.w800)) - painted(weighted(FontWeight.w400)),
      greaterThan(2),
    );
  });
}

/// Unicode coverage from the font's cmap (format 4 and 12).
Set<int> _cmapCoverage(List<int> data) {
  int u16(int o) => (data[o] << 8) | data[o + 1];
  int u32(int o) =>
      (data[o] << 24) | (data[o + 1] << 16) | (data[o + 2] << 8) | data[o + 3];
  int i16(int o) {
    final v = u16(o);
    return v >= 0x8000 ? v - 0x10000 : v;
  }

  final numTables = u16(4);
  var cmapOffset = -1;
  var rec = 12;
  for (var i = 0; i < numTables; i++) {
    final tag = String.fromCharCodes(data.sublist(rec, rec + 4));
    if (tag == 'cmap') {
      cmapOffset = u32(rec + 8);
      break;
    }
    rec += 16;
  }
  expect(cmapOffset, greaterThan(0));
  final covered = <int>{};
  final nsub = u16(cmapOffset + 2);
  for (var i = 0; i < nsub; i++) {
    final platform = u16(cmapOffset + 4 + i * 8);
    final encoding = u16(cmapOffset + 6 + i * 8);
    final start = cmapOffset + u32(cmapOffset + 8 + i * 8);
    final unicode =
        platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
    if (!unicode) continue;
    final format = u16(start);
    if (format == 4) {
      final segCount = u16(start + 6) >> 1;
      final ends = start + 14;
      final starts = ends + 2 * segCount + 2;
      final deltas = starts + 2 * segCount;
      final offsets = deltas + 2 * segCount;
      for (var s = 0; s < segCount; s++) {
        final end = u16(ends + 2 * s);
        final first = u16(starts + 2 * s);
        if (first == 0xFFFF) continue;
        final delta = i16(deltas + 2 * s);
        final rangeOffset = u16(offsets + 2 * s);
        for (var code = first; code <= end; code++) {
          var gid = rangeOffset == 0
              ? (code + delta) & 0xFFFF
              : u16(offsets + 2 * s + rangeOffset + 2 * (code - first));
          if (rangeOffset != 0 && gid != 0) gid = (gid + delta) & 0xFFFF;
          if (gid != 0) covered.add(code);
        }
      }
    } else if (format == 12) {
      final groups = u32(start + 12);
      var p = start + 16;
      for (var g = 0; g < groups; g++) {
        final first = u32(p);
        final end = u32(p + 4);
        final glyph = u32(p + 8);
        p += 12;
        for (var code = first; code <= end; code++) {
          if (glyph + (code - first) != 0) covered.add(code);
        }
      }
    }
  }
  return covered;
}

List<String> _fvarAxes(List<int> data) {
  int u16(int o) => (data[o] << 8) | data[o + 1];
  int u32(int o) =>
      (data[o] << 24) | (data[o + 1] << 16) | (data[o + 2] << 8) | data[o + 3];
  final numTables = u16(4);
  var offset = -1;
  var rec = 12;
  for (var i = 0; i < numTables; i++) {
    final tag = String.fromCharCodes(data.sublist(rec, rec + 4));
    if (tag == 'fvar') {
      offset = u32(rec + 8);
      break;
    }
    rec += 16;
  }
  expect(offset, greaterThan(0));
  final axisCount = u16(offset + 8);
  final axisSize = u16(offset + 10);
  final axes = <String>[];
  for (var i = 0; i < axisCount; i++) {
    final at = offset + 16 + i * axisSize;
    axes.add(String.fromCharCodes(data.sublist(at, at + 4)));
  }
  return axes;
}
