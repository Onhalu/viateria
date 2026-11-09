import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/motion_tokens.dart';
import 'motion_reduce.dart';

/// Horizontal error shake: ±[MotionTokens.shakeAmplitude] px,
/// [MotionTokens.shakeOscillations] cycles, [MotionTokens.shake].
///
/// Plays when [active] flips to true. Reduced motion keeps the child still.
class MotionShake extends StatefulWidget {
  const MotionShake({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<MotionShake> createState() => _MotionShakeState();
}

class _MotionShakeState extends State<MotionShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _armed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.shake,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MotionShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _sync();
  }

  void _sync() {
    if (!widget.active) {
      _armed = false;
      _controller.value = 0;
      return;
    }
    if (_armed) return;
    _armed = true;
    if (motionReduced(context)) {
      _controller.value = 0;
      return;
    }
    _controller.forward(from: 0);
  }

  double _offset(double t) {
    if (t == 0 || t == 1) return 0;
    final wave = math.sin(t * MotionTokens.shakeOscillations * 2 * math.pi);
    return wave * MotionTokens.shakeAmplitude * (1 - t);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final dx = motionReduced(context) ? 0.0 : _offset(_controller.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
