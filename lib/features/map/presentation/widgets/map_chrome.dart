import 'package:flutter/material.dart';

import '../../../../core/theme/map_colors.dart';

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
      color: color ?? MapColors.surfaceFill,
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
        color: background ?? MapColors.surfaceFill,
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
