import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../theme/brand_colors.dart';
import '../../theme/motion_tokens.dart';
import 'motion_reduce.dart';

/// Forest track, cream thumb, spring overshoot and a horizontal stretch.
///
/// Prepared for settings or filters. The app has no [Switch] yet, so this
/// control is not mounted on a screen.
class BrandSpringSwitch extends StatefulWidget {
  const BrandSpringSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const hitHeight = 44.0;
  static const trackWidth = 52.0;
  static const trackHeight = 32.0;

  @override
  State<BrandSpringSwitch> createState() => _BrandSpringSwitchState();
}

class _BrandSpringSwitchState extends State<BrandSpringSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.value ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(BrandSpringSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _animateTo(widget.value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionReduced(context)) _snap();
  }

  void _snap() {
    _controller.value = widget.value ? 1 : 0;
  }

  void _animateTo(bool next) {
    if (motionReduced(context)) {
      _snap();
      return;
    }
    final simulation = SpringSimulation(
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: MotionTokens.switchStiffness,
        ratio: MotionTokens.switchDampingRatio,
      ),
      _controller.value,
      next ? 1 : 0,
      0,
    );
    _controller.animateWith(simulation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
        child: SizedBox(
          key: const Key('brand-switch'),
          width: BrandSpringSwitch.trackWidth,
          height: BrandSpringSwitch.hitHeight,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final reduced = motionReduced(context);
              final raw = _controller.value;
              final t = raw.clamp(0.0, 1.0).toDouble();
              final stretching = !reduced && _controller.isAnimating;
              final track = Color.lerp(
                BrandColors.neutral,
                BrandColors.forest,
                t,
              )!;
              final border = Color.lerp(
                BrandColors.beige,
                BrandColors.forest,
                t,
              )!;
              return Center(
                child: Container(
                  key: const Key('brand-switch-track'),
                  width: BrandSpringSwitch.trackWidth,
                  height: BrandSpringSwitch.trackHeight,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Align(
                    alignment: Alignment(-1 + 2 * raw, 0),
                    child: Transform(
                      key: const Key('brand-switch-stretch'),
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        stretching ? MotionTokens.stretchScale : 1,
                        1,
                        1,
                      ),
                      child: const SizedBox(
                        key: Key('brand-switch-thumb'),
                        width: 24,
                        height: 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: BrandColors.cream,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
