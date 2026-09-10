import 'package:flutter/material.dart';

import 'brand_colors.dart';

export 'brand_colors.dart' show BrandColors, MapPalette;

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
    final radius = BorderRadius.circular(12);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: BrandColors.cream,
      canvasColor: BrandColors.cream,
      dividerColor: BrandColors.beige,
      textTheme: ThemeData(brightness: Brightness.light).textTheme.apply(
        bodyColor: BrandColors.ink,
        displayColor: BrandColors.ink,
      ),
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
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.forest,
          foregroundColor: BrandColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: BrandColors.cream,
          foregroundColor: BrandColors.forest,
          side: const BorderSide(color: BrandColors.beige),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BrandColors.forest),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BrandColors.cream,
        selectedColor: BrandColors.forest,
        disabledColor: BrandColors.cream,
        labelStyle: const TextStyle(
          color: BrandColors.bark,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: BrandColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: BrandColors.beige),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        checkmarkColor: BrandColors.onPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrandColors.cream,
        indicatorColor: BrandColors.beige,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? BrandColors.forest : BrandColors.sage,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? BrandColors.forest : BrandColors.bark,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.neutral,
        labelStyle: const TextStyle(color: BrandColors.muted),
        hintStyle: const TextStyle(color: BrandColors.muted),
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
