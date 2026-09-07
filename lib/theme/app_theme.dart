import 'package:flutter/material.dart';

class AppTheme {
  static const forest = Color(0xFF1B4332);
  static const moss = Color(0xFF2D6A4F);
  static const gold = Color(0xFFD4A017);
  static const cream = Color(0xFFF7F3E9);
  static const bark = Color(0xFF3D2914);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: moss,
      primary: moss,
      secondary: gold,
      surface: cream,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: moss,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
