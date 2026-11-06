import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';
import '../../theme/motion_tokens.dart';
import 'motion_reduce.dart';

/// Forest outline → Forest fill, with a short scale pop and a Sage dot burst.
///
/// The burst belongs only on like / save. Do not use it for unlock, FAPI,
/// verify, or a redemption-code action.
class LikeSaveButton extends StatefulWidget {
  const LikeSaveButton({
    super.key,
    this.saved,
    this.onChanged,
    required this.saveLabel,
    required this.savedLabel,
  });

  /// Controlled saved flag. Null keeps the flag inside the button.
  final bool? saved;
  final ValueChanged<bool>? onChanged;
  final String saveLabel;
  final String savedLabel;

  static const hitSize = 44.0;

  @override
  State<LikeSaveButton> createState() => _LikeSaveButtonState();
}

class _LikeSaveButtonState extends State<LikeSaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _local = false;
  var _burst = false;

  bool get _saved => widget.saved ?? _local;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: MotionTokens.fast)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _burst && mounted) {
          setState(() => _burst = false);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tap() {
    final next = !_saved;
    if (widget.saved == null) setState(() => _local = next);
    widget.onChanged?.call(next);
    if (motionReduced(context)) {
      setState(() => _burst = false);
      _controller.value = 0;
      return;
    }
    setState(() => _burst = next);
    _controller.forward(from: 0);
  }

  double _scale(double t) {
    if (t <= 0 || t >= 1) return 1;
    if (t < 0.3) {
      return _lerp(1, MotionTokens.likeScaleDown, t / 0.3);
    }
    if (t < 0.7) {
      return _lerp(
        MotionTokens.likeScaleDown,
        MotionTokens.likeScaleUp,
        (t - 0.3) / 0.4,
      );
    }
    return _lerp(MotionTokens.likeScaleUp, 1, (t - 0.7) / 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    final label = saved ? widget.savedLabel : widget.saveLabel;
    return Semantics(
      button: true,
      toggled: saved,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: _tap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: LikeSaveButton.hitSize,
            height: LikeSaveButton.hitSize,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final reduced = motionReduced(context);
                final t = reduced ? 0.0 : _controller.value;
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (_burst && !reduced) _SageBurst(t: t == 0 ? 0.01 : t),
                    Transform.scale(
                      scale: _scale(t),
                      child: Icon(
                        saved ? Icons.favorite : Icons.favorite_border,
                        color: BrandColors.forest,
                        size: 22,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _SageBurst extends StatelessWidget {
  const _SageBurst({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    const iconRadius = 11.0;
    final dist = iconRadius * (1 + (MotionTokens.burstRadiusFactor - 1) * t);
    final opacity = (1 - t).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      key: const Key('like-burst'),
      width: LikeSaveButton.hitSize,
      height: LikeSaveButton.hitSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < MotionTokens.burstDots; i++)
            _dot(i, dist, opacity),
        ],
      ),
    );
  }

  Widget _dot(int index, double dist, double opacity) {
    final angle = -math.pi / 2 + index * 2 * math.pi / MotionTokens.burstDots;
    const dot = 5.0;
    final cx = LikeSaveButton.hitSize / 2;
    return Positioned(
      left: cx + math.cos(angle) * dist - dot / 2,
      top: cx + math.sin(angle) * dist - dot / 2,
      child: Opacity(
        opacity: opacity,
        child: Container(
          key: Key('like-burst-dot-$index'),
          width: dot,
          height: dot,
          decoration: const BoxDecoration(
            color: BrandColors.sage,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
