import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/motion_tokens.dart';
import 'motion_reduce.dart';

/// One row in [BrandOverflowMenu]. Labels stay Forest on a Cream surface.
class BrandMenuAction {
  const BrandMenuAction({required this.label, required this.onSelected});

  final String label;
  final VoidCallback onSelected;
}

/// Overflow „⋯“ menu that scales and fades from the trigger hit box.
///
/// Not used for the VANDERY+ sheet. The app has no overflow trigger yet, so
/// this control is not mounted.
class BrandOverflowMenu extends StatelessWidget {
  const BrandOverflowMenu({
    super.key,
    required this.actions,
    this.tooltip = '⋯',
  });

  final List<BrandMenuAction> actions;
  final String tooltip;

  static const hitSize = 44.0;
  static const radius = 12.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: hitSize,
      height: hitSize,
      child: IconButton(
        key: const Key('brand-overflow-trigger'),
        tooltip: tooltip,
        onPressed: () => _open(context),
        style: IconButton.styleFrom(
          minimumSize: const Size(hitSize, hitSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: BrandColors.forest,
        ),
        icon: const Icon(Icons.more_horiz),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = overlay.localToGlobal(Offset.zero);
    final topLeft = box.localToGlobal(Offset.zero) - origin;
    final reduced = motionReduced(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x00000000),
      transitionDuration: reduced ? Duration.zero : MotionTokens.menu,
      pageBuilder: (dialogContext, animation, _) {
        return _SpatialMenu(
          animation: animation,
          anchor: topLeft,
          anchorSize: box.size,
          overlaySize: overlay.size,
          actions: actions,
          reduced: reduced,
        );
      },
    );
  }
}

class _SpatialMenu extends StatelessWidget {
  const _SpatialMenu({
    required this.animation,
    required this.anchor,
    required this.anchorSize,
    required this.overlaySize,
    required this.actions,
    required this.reduced,
  });

  final Animation<double> animation;
  final Offset anchor;
  final Size anchorSize;
  final Size overlaySize;
  final List<BrandMenuAction> actions;
  final bool reduced;

  static const _width = 200.0;

  @override
  Widget build(BuildContext context) {
    final height = actions.length * AppTheme.minTap;
    final opensUp =
        anchor.dy + anchorSize.height + 4 + height > overlaySize.height - 8;
    final top = opensUp
        ? anchor.dy - 4 - height
        : anchor.dy + anchorSize.height + 4;
    var left = anchor.dx + anchorSize.width - _width;
    if (left < 8) left = 8;
    if (left + _width > overlaySize.width - 8) {
      left = overlaySize.width - 8 - _width;
    }
    final triggerRight = anchor.dx + anchorSize.width;
    final alignX = (triggerRight - left) > _width / 2 ? 1.0 : -1.0;
    final alignment = Alignment(alignX, opensUp ? 1 : -1);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = reduced ? 1.0 : animation.value.clamp(0.0, 1.0).toDouble();
        final scale =
            MotionTokens.menuScaleFrom + (1 - MotionTokens.menuScaleFrom) * t;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: _width,
              child: Transform(
                key: const Key('brand-overflow-motion'),
                alignment: alignment,
                transform: Matrix4.diagonal3Values(scale, scale, 1),
                child: Opacity(opacity: t, child: child),
              ),
            ),
          ],
        );
      },
      child: Material(
        key: const Key('brand-overflow-surface'),
        color: BrandColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandOverflowMenu.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  action.onSelected();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: _width,
                    minHeight: AppTheme.minTap,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        action.label,
                        style: const TextStyle(
                          color: BrandColors.forest,
                          fontSize: AppTheme.bodySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
