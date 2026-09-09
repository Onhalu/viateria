import 'package:flutter/material.dart';

/// Visual tokens for the Map Screen MVP (screenshot source of truth).
abstract final class MapColors {
  static const accent = Color(0xFFC45C3E);
  static const surface = Color(0xFF1A1A1A);
  static const surfaceOpacity = 0.90;
  static const onSurface = Colors.white;
  static const clusterDot = Color(0xFF2EA043);

  static Color get surfaceFill => surface.withValues(alpha: surfaceOpacity);
}
