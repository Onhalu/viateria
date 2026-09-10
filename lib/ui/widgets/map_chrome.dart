import 'package:flutter/material.dart';

/// Map UI tokens (Batch A/B). App shell / catalog still use [AppTheme].
///
/// Map primary is forest `#35483C`. Cream surfaces stay `#F3EFE5`.
/// SDF icon-color: sage outside a challenge, forest in-challenge
/// unverified, bark when verified. Forbidden: `#D4A017` gold,
/// `#B8860B` goldenrod, `#2D6A4F` moss, `#1B4332` old forest,
/// `#3D2914` old bark.
abstract final class MapPalette {
  static const forest = Color(0xFF35483C);
  static const sage = Color(0xFF9C9A7B);
  static const cream = Color(0xFFF3EFE5);
  static const neutral = Color(0xFFFAF8F2);
  static const beige = Color(0xFFD8CDB8);
  static const bark = Color(0xFF756653);

  /// Cream at ~94% opacity for overlay chrome and POI disks.
  static const creamFill = Color(0xF0F3EFE5);
  static const creamRgba94 = 'rgba(243, 239, 229, 0.94)';

  static const forestHex = '#35483C';
  static const sageHex = '#9C9A7B';
  static const barkHex = '#756653';
  static const creamHex = '#F3EFE5';
  static const verifiedHex = barkHex;
  static const verified = bark;
}

abstract final class MapOverlayColors {
  static const fill = MapPalette.creamFill;
  static const accent = MapPalette.forest;
  static const surface = MapPalette.cream;
}

abstract final class MapChromeSizes {
  static const searchRadius = 24.0;
  static const toggleRadius = 20.0;
  static const attributionIcon = 16.0;
  static const listRowIcon = 22.0;

  static double inset(bool compact) => compact ? 8 : 12;
  static double searchHeight(bool compact) => compact ? 40 : 48;
  static double searchFont(bool compact) => compact ? 13 : 15;
  static double searchIcon(bool compact) => compact ? 16 : 18;
  static double circleButton(bool compact) => compact ? 36 : 44;
  static double circleIcon(bool compact) => compact ? 16 : 18;
  static double countFont(bool compact) => compact ? 11 : 13;
  static double toggleFont(bool compact) => compact ? 12 : 13;
  static double toggleIcon(bool compact) => compact ? 14 : 16;
}

class MapGlass extends StatelessWidget {
  const MapGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.shape,
    this.onTap,
    this.color,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedShape =
        shape ??
        RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(28),
        );
    return Material(
      color: color ?? MapOverlayColors.fill,
      shape: resolvedShape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? child
          : InkWell(onTap: onTap, customBorder: resolvedShape, child: child),
    );
  }
}

class MapIconButton extends StatelessWidget {
  const MapIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.background,
    this.foreground = MapPalette.forest,
    this.size = 44,
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? background;
  final Color foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: background ?? MapOverlayColors.fill,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: foreground, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class OsmAttributionChip extends StatelessWidget {
  const OsmAttributionChip({
    super.key,
    required this.label,
    required this.longLabel,
  });

  final String label;
  final String longLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MapOverlayColors.fill,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const Key('map-osm-attribution'),
        customBorder: const StadiumBorder(),
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(label),
              content: Text(longLabel),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.info_outline,
            color: MapPalette.bark,
            size: MapChromeSizes.attributionIcon,
          ),
        ),
      ),
    );
  }
}
