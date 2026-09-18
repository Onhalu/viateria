import 'package:flutter/material.dart';

/// Shared VANDERY tokens. [AppTheme] and map chrome both read these.
///
/// Forbidden in UI: gold `#D4A017`, moss `#2D6A4F`, old forest `#1B4332`,
/// old bark `#3D2914`, old cream `#F7F3E9`.
abstract final class BrandColors {
  static const forest = Color(0xFF35483C);
  static const sage = Color(0xFF9C9A7B);
  static const cream = Color(0xFFF3EFE5);

  /// Fill for the floating bottom nav and inset catalog welcome header.
  /// Greeting, search, and filter chips share this bar with the nav.
  static const shellFill = Color(0xFF7D8B6A);

  /// Cream at 22% — selected nav pill, header round-button fill, and
  /// unselected chips on [shellFill].
  static Color get creamPill => cream.withValues(alpha: 0.22);

  /// Nav elevation tint (forest at 13%, within the 12–14% spec).
  static Color get shellShadow => forest.withValues(alpha: 0.13);
  static const neutral = Color(0xFFFAF8F2);
  static const beige = Color(0xFFD8CDB8);
  static const bark = Color(0xFF756653);

  static const onPrimary = cream;
  static const ink = forest;
  static const onCream = forest;
  static const muted = bark;
  static const success = forest;
  static const warning = sage;

  /// Material 3 system error. Never outdoor orange.
  static const error = Color(0xFFBA1A1A);

  /// Cream at ~94% opacity for catalog search on [shellFill], overlay
  /// chrome, and unverified POI disks.
  static const creamFill = Color(0xF0F3EFE5);
  static const creamRgba94 = 'rgba(243, 239, 229, 0.94)';

  static const forestHex = '#35483C';
  static const sageHex = '#9C9A7B';
  static const shellFillHex = '#7D8B6A';
  static const barkHex = '#756653';
  static const creamHex = '#F3EFE5';

  /// Verified disk fill (solid bark). Icon tint is cream, not this.
  static const verifiedDiskHex = barkHex;
  static const verified = bark;
}

/// Historical name used by map widgets. Same object as [BrandColors].
typedef MapPalette = BrandColors;
