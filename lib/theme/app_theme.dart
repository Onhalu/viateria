import 'package:flutter/material.dart';

import 'app_button.dart';
import 'brand_colors.dart';
import 'brand_typography.dart';

export 'app_button.dart';
export 'brand_colors.dart' show BrandColors, MapPalette;
export 'brand_typography.dart' show BrandTypography, registerOnestLicense;

/// App-wide Material theme. Colors come from [BrandColors] / [MapPalette].
abstract final class AppTheme {
  static const forest = BrandColors.forest;
  static const sage = BrandColors.sage;
  static const cream = BrandColors.cream;
  static const bark = BrandColors.bark;
  static const beige = BrandColors.beige;
  static const neutral = BrandColors.neutral;
  static const onPrimary = BrandColors.onPrimary;
  static const ink = BrandColors.ink;
  static const muted = BrandColors.muted;
  static const success = BrandColors.success;
  static const warning = BrandColors.warning;

  /// Type scale. Nothing is smaller than [captionSize].
  static const displaySize = 32.0;
  static const titleSize = 22.0;
  static const bodySize = 16.0;
  static const labelSize = 14.0;
  static const captionSize = 12.0;

  static const radiusCard = 12.0;
  static const radiusPill = 999.0;
  static const radiusSheet = 20.0;

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  /// Primary pill height. Secondary controls stay at least [minTap].
  static const ctaHeight = 52.0;
  static const minTap = 48.0;

  /// Heading family. Body styles leave the family unset and stay Roboto.
  static const displayFont = BrandTypography.family;

  static const cardShadow = [
    BoxShadow(color: Color(0x1435483C), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.forest,
      onPrimary: BrandColors.onPrimary,
      primaryContainer: BrandColors.beige,
      onPrimaryContainer: BrandColors.forest,
      secondary: BrandColors.sage,
      onSecondary: BrandColors.cream,
      secondaryContainer: BrandColors.beige,
      onSecondaryContainer: BrandColors.forest,
      tertiary: BrandColors.beige,
      onTertiary: BrandColors.forest,
      error: BrandColors.error,
      onError: Color(0xFFFFFFFF),
      surface: BrandColors.cream,
      onSurface: BrandColors.ink,
      surfaceTint: BrandColors.cream,
      onSurfaceVariant: BrandColors.muted,
      outline: BrandColors.beige,
      outlineVariant: BrandColors.beige,
      surfaceContainerLowest: BrandColors.cream,
      surfaceContainerLow: BrandColors.cream,
      surfaceContainer: BrandColors.cream,
      surfaceContainerHigh: BrandColors.neutral,
      surfaceContainerHighest: BrandColors.neutral,
    );
    final radius = BorderRadius.circular(radiusCard);
    const ink = BrandColors.ink;
    TextStyle heading(double fontSize) =>
        BrandTypography.display(fontSize: fontSize, color: ink);
    const sans = TextStyle(color: ink, height: 1.35);
    final textTheme = TextTheme(
      displaySmall: heading(displaySize),
      headlineMedium: heading(28),
      headlineSmall: heading(titleSize),
      titleLarge: heading(titleSize),
      titleMedium: sans.copyWith(
        fontSize: bodySize,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: sans.copyWith(fontSize: bodySize),
      bodyMedium: sans.copyWith(fontSize: bodySize),
      bodySmall: sans.copyWith(fontSize: captionSize, color: BrandColors.bark),
      labelLarge: sans.copyWith(
        fontSize: labelSize,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: sans.copyWith(fontSize: labelSize),
      labelSmall: sans.copyWith(fontSize: captionSize, color: BrandColors.bark),
    );
    const buttonSizes = AppButtonSizes.standard;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: const [buttonSizes],
      scaffoldBackgroundColor: BrandColors.cream,
      canvasColor: BrandColors.cream,
      dividerColor: BrandColors.beige,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.cream,
        foregroundColor: BrandColors.forest,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: BrandColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BrandColors.beige),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppButtonThemes.filled(buttonSizes),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppButtonThemes.outlined(buttonSizes),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppButtonThemes.text(buttonSizes),
      ),
      iconButtonTheme: IconButtonThemeData(style: AppButtonThemes.icon()),
      chipTheme: ChipThemeData(
        backgroundColor: BrandColors.beige,
        selectedColor: BrandColors.forest,
        disabledColor: BrandColors.beige,
        labelStyle: const TextStyle(
          color: BrandColors.forest,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        secondaryLabelStyle: const TextStyle(
          color: BrandColors.onPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        checkmarkColor: BrandColors.onPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrandColors.shellFill,
        indicatorColor: BrandColors.creamPill,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return BrandColors.cream.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? BrandColors.cream
                : BrandColors.forest.withValues(alpha: 0.75),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected
                ? BrandColors.cream
                : BrandColors.forest.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.neutral,
        labelStyle: const TextStyle(
          color: BrandColors.muted,
          fontSize: labelSize,
        ),
        hintStyle: const TextStyle(
          color: BrandColors.muted,
          fontSize: labelSize,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: BrandColors.beige),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: BrandColors.forest, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: BrandColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: BrandColors.error, width: 1.5),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.forest,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BrandColors.forest,
        foregroundColor: BrandColors.onPrimary,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.forest,
        contentTextStyle: TextStyle(color: BrandColors.onPrimary),
      ),
    );
  }
}
