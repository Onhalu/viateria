import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// Padlock motion from UX-unlock-animation. One controller, 450 ms.
///
/// Lift uses a 34% overshoot. Rotation is clockwise around the right shackle
/// leg and settles at 42.5° (inside 40–45). The body does not move.
abstract final class PadlockPose {
  static const duration = Duration(milliseconds: 450);
  static const endDegrees = 42.5;

  static PadlockPoseSample at(double t, {double glyph = 20}) {
    final clamped = t.clamp(0.0, 1.0);
    return PadlockPoseSample(
      liftPx: _liftPx(clamped, glyph),
      radians: _radians(clamped),
      glow: _glow(clamped),
    );
  }

  /// Peak lift factor during phase 1. Spec overshoot is 34%.
  static double get liftOvershoot => 1.34;

  static Color keyholeColor(double t) {
    final glow = _glow(t.clamp(0.0, 1.0));
    if (glow <= 0) return BrandColors.forest.withValues(alpha: 0.15);
    return BrandColors.sage.withValues(alpha: glow);
  }

  static double _liftPx(double t, double glyph) {
    final scale = glyph / 20.0;
    if (t <= 0) return 0;
    if (t <= 0.55) {
      return -18 * scale * _liftProgress(t / 0.55);
    }
    final descend = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    return -18 * scale * (1 - descend);
  }

  static double _liftProgress(double u) {
    if (u <= 0) return 0;
    if (u >= 1) return 1;
    const peakAt = 0.72;
    if (u < peakAt) {
      final x = u / peakAt;
      return liftOvershoot * (1 - (1 - x) * (1 - x));
    }
    final x = (u - peakAt) / (1 - peakAt);
    return liftOvershoot + (1 - liftOvershoot) * x;
  }

  static double _radians(double t) {
    if (t <= 0.45) return 0;
    final u = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    final eased = 1 - (1 - u) * (1 - u);
    return endDegrees * math.pi / 180 * eased;
  }

  static double _glow(double t) {
    if (t <= 0) return 0;
    return (t / 0.55).clamp(0.0, 1.0);
  }
}

class PadlockPoseSample {
  const PadlockPoseSample({
    required this.liftPx,
    required this.radians,
    required this.glow,
  });

  final double liftPx;
  final double radians;
  final double glow;

  double get degrees => radians * 180 / math.pi;
}
