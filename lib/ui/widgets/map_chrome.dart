import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Overlay chrome for map surfaces. Dark pills match the map reference
/// screenshot; gold accent comes from the existing app theme.
abstract final class MapOverlayColors {
  static const fill = Color(0xE61A1A1A);
  static const accent = AppTheme.gold;
  static const surface = Color(0xF21A1A1A);
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
    this.foreground = Colors.white,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? background;
  final Color foreground;
  final double size;

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
            child: Icon(icon, color: foreground, size: 22),
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
          child: Icon(Icons.info_outline, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
