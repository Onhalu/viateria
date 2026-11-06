import 'package:flutter/material.dart';

import '../../domain/padlock_pose.dart';
import '../../theme/brand_colors.dart';

/// Two layers: a static [LockBody] and a transformed [Shackle].
/// Not an [AnimatedSwitcher] of two icons.
class PadlockUnlock extends StatefulWidget {
  const PadlockUnlock({
    super.key,
    required this.play,
    required this.lockedLabel,
    required this.unlockedLabel,
    this.glyph = 20,
    this.onCompleted,
  });

  final bool play;
  final String lockedLabel;
  final String unlockedLabel;
  final double glyph;
  final VoidCallback? onCompleted;

  @override
  State<PadlockUnlock> createState() => PadlockUnlockState();
}

class PadlockUnlockState extends State<PadlockUnlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  var _announced = false;
  var _started = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: PadlockPose.duration,
    );
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || !widget.play || _announced) {
        return;
      }
      setState(() => _announced = true);
      widget.onCompleted?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PadlockUnlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  bool get _reduceMotion {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  void _sync() {
    if (!widget.play || _started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.play || controller.status != AnimationStatus.dismissed) {
        return;
      }
      if (_reduceMotion) {
        controller.value = 1;
        return;
      }
      controller.forward();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opened = widget.play && (_reduceMotion || controller.value >= 1);
    return Semantics(
      label: opened ? widget.unlockedLabel : widget.lockedLabel,
      liveRegion: _announced,
      child: SizedBox(
        width: widget.glyph,
        height: widget.glyph,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = widget.play && _reduceMotion ? 1.0 : controller.value;
            final pose = PadlockPose.at(t, glyph: widget.glyph);
            final pivot = Offset(
              widget.glyph * 13.5 / 20,
              widget.glyph * 10 / 20,
            );
            final shackle = Matrix4.identity()
              ..translateByDouble(pivot.dx, pivot.dy, 0, 1)
              ..rotateZ(pose.radians)
              ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1)
              ..translateByDouble(0, pose.liftPx, 0, 1);
            return Stack(
              children: [
                LockBody(glyph: widget.glyph, keyhole: PadlockPose.keyholeColor(t)),
                Shackle(glyph: widget.glyph, transform: shackle),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LockBody extends StatelessWidget {
  const LockBody({super.key, required this.glyph, required this.keyhole});

  final double glyph;
  final Color keyhole;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(glyph),
      painter: _LockBodyPainter(keyhole: keyhole),
    );
  }
}

class Shackle extends StatelessWidget {
  const Shackle({super.key, required this.glyph, required this.transform});

  final double glyph;
  final Matrix4 transform;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.topLeft,
      transform: transform,
      child: CustomPaint(
        size: Size.square(glyph),
        painter: const _ShacklePainter(),
      ),
    );
  }
}

class _LockBodyPainter extends CustomPainter {
  const _LockBodyPainter({required this.keyhole});

  final Color keyhole;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 20;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(4 * s, 10 * s, 12 * s, 8.5 * s),
      Radius.circular(1.6 * s),
    );
    final fill = Paint()
      ..color = BrandColors.forest
      ..style = PaintingStyle.fill;
    canvas.drawRRect(body, fill);
    canvas.drawCircle(Offset(10 * s, 13.6 * s), 1.35 * s, Paint()..color = keyhole);
    final slot = Path()
      ..moveTo(9.4 * s, 14.4 * s)
      ..lineTo(10.6 * s, 14.4 * s)
      ..lineTo(10.2 * s, 16.4 * s)
      ..lineTo(9.8 * s, 16.4 * s)
      ..close();
    canvas.drawPath(slot, Paint()..color = keyhole);
  }

  @override
  bool shouldRepaint(_LockBodyPainter oldDelegate) => oldDelegate.keyhole != keyhole;
}

class _ShacklePainter extends CustomPainter {
  const _ShacklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 20;
    final path = Path()
      ..moveTo(6.5 * s, 10.4 * s)
      ..lineTo(6.5 * s, 7.2 * s)
      ..arcToPoint(
        Offset(13.5 * s, 7.2 * s),
        radius: Radius.circular(3.5 * s),
      )
      ..lineTo(13.5 * s, 10.4 * s);
    canvas.drawPath(
      path,
      Paint()
        ..color = BrandColors.forest
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ShacklePainter oldDelegate) => false;
}
