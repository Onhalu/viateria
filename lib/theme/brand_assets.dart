import 'package:flutter/material.dart';

/// Raster brand files. Wordmark tracking is baked into the lockup PNGs.
abstract final class BrandAssets {
  static const mark = 'assets/brand/vandery-mark.png';
  static const lockup = 'assets/brand/vandery-lockup.png';
  static const markOnPrimary = 'assets/brand/vandery-mark-on-primary.png';
  static const lockupOnPrimary = 'assets/brand/vandery-lockup-on-primary.png';

  /// Splash / auth hero width in dp.
  static const splashLockupWidth = 148.0;
  static const markMinSize = 24.0;
}

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = BrandAssets.markMinSize,
    this.onPrimary = false,
  });

  final double size;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final resolved = size < BrandAssets.markMinSize
        ? BrandAssets.markMinSize
        : size;
    return Image.asset(
      onPrimary ? BrandAssets.markOnPrimary : BrandAssets.mark,
      width: resolved,
      height: resolved,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'VANDERY',
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.width = BrandAssets.splashLockupWidth,
    this.onPrimary = false,
  });

  final double width;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onPrimary ? BrandAssets.lockupOnPrimary : BrandAssets.lockup,
      width: width,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'VANDERY',
    );
  }
}
