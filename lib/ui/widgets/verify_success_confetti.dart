import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';

/// How long the verify burst stays on screen, including its fade-out.
///
/// Inside the 1.2–1.6 s window (hard cap 1.8 s).
const kVerifyConfettiDuration = Duration(milliseconds: 1500);

/// Light density. Spec band is 40–70 pieces.
const kVerifyConfettiParticleCount = 56;

/// Downward acceleration in logical pixels per second squared.
const kVerifyConfettiGravity = 780.0;

/// Muted paper colors. Gold, neon, and fluorescent are intentionally absent.
const kVerifyConfettiColors = <Color>[
  Color(0xFFE8A090), // soft coral
  Color(0xFF7BA3C4), // sky
  Color(0xFFE8D48B), // butter
  Color(0xFFB8A0C8), // lilac
  BrandColors.sage,
  BrandColors.forest,
  BrandColors.cream,
  BrandColors.beige,
];

/// Opacity of the whole burst. Holds, then fades to zero before [t] reaches 1.
double verifyConfettiOpacity(double t) {
  const fadeStart = 0.68;
  if (t <= fadeStart) return 1;
  final fade = (t - fadeStart) / (1 - fadeStart);
  return (1 - fade).clamp(0.0, 1.0);
}

/// One paper scrap. Origin is a fraction of the overlay (0–1).
class VerifyConfettiPiece {
  const VerifyConfettiPiece({
    required this.color,
    required this.origin,
    required this.velocity,
    required this.width,
    required this.height,
    required this.rotation,
    required this.spin,
    required this.delay,
    required this.alpha,
  });

  final Color color;
  final Offset origin;
  final Offset velocity;
  final double width;
  final double height;
  final double rotation;
  final double spin;
  final double delay;
  final double alpha;
}

/// Fixed-seed burst so the confirmation looks the same every time.
///
/// Pieces start in the upper third, clustered around the horizontal center
/// (the success area), and fall. Shapes are small rounded rectangles only.
List<VerifyConfettiPiece> buildVerifyConfettiPieces({int seed = 20261007}) {
  final random = math.Random(seed);
  // Colorful scraps lead; sage, forest, cream, and beige stay in the mix.
  const weighted = <Color>[
    Color(0xFFE8A090),
    Color(0xFF7BA3C4),
    Color(0xFFE8D48B),
    Color(0xFFB8A0C8),
    Color(0xFFE8A090),
    Color(0xFF7BA3C4),
    Color(0xFFE8D48B),
    Color(0xFFB8A0C8),
    BrandColors.sage,
    BrandColors.forest,
    BrandColors.cream,
    BrandColors.beige,
  ];
  return List<VerifyConfettiPiece>.generate(kVerifyConfettiParticleCount, (i) {
    final spread = (random.nextDouble() - 0.5) * 1.7;
    final speed = 150 + random.nextDouble() * 170;
    return VerifyConfettiPiece(
      color: weighted[i % weighted.length],
      origin: Offset(
        (0.5 + (random.nextDouble() - 0.5) * 0.58).clamp(0.12, 0.88),
        0.08 + random.nextDouble() * 0.22,
      ),
      velocity: Offset(
        math.sin(spread) * speed,
        -math.cos(spread) * speed * 0.42,
      ),
      width: 6 + random.nextDouble() * 7,
      height: 3.5 + random.nextDouble() * 3.5,
      rotation: random.nextDouble() * math.pi,
      spin: (random.nextDouble() - 0.5) * 7,
      delay: random.nextDouble() * 0.12,
      alpha: 0.82 + random.nextDouble() * 0.18,
    );
  });
}

/// Full-screen paper burst after a successful place or waypoint verify.
///
/// [IgnorePointer] so the success UI underneath (dismiss, diploma, map)
/// stays tappable. Renders nothing when animations are disabled.
class VerifySuccessConfetti extends StatefulWidget {
  const VerifySuccessConfetti({super.key, this.pieces, this.onFinished});

  static const overlayKey = Key('verify-success-confetti');

  final List<VerifyConfettiPiece>? pieces;
  final VoidCallback? onFinished;

  /// Inserts a burst above [overlay]. Caller skips this when animations
  /// are disabled; the widget also paints nothing in that case.
  static void insertInto(OverlayState overlay) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: VerifySuccessConfetti(
          onFinished: () {
            if (entry.mounted) entry.remove();
          },
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<VerifySuccessConfetti> createState() => _VerifySuccessConfettiState();
}

class _VerifySuccessConfettiState extends State<VerifySuccessConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<VerifyConfettiPiece> _pieces;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _pieces = widget.pieces ?? buildVerifyConfettiPieces();
    _controller = AnimationController(
      vsync: this,
      duration: kVerifyConfettiDuration,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted || _finished) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _complete();
      return;
    }
    unawaited(_controller.forward().whenComplete(_complete));
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    // Remove the overlay after this frame so the controller is not disposed
    // from inside its own completion callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFinished?.call();
    });
    // ensureVisualUpdate no-ops during the ticker phase, which is when the
    // burst finishes. scheduleFrame still requests the removal frame.
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return ExcludeSemantics(
      child: IgnorePointer(
        key: VerifySuccessConfetti.overlayKey,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: VerifyConfettiPainter(
                progress: _controller.value,
                pieces: _pieces,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class VerifyConfettiPainter extends CustomPainter {
  const VerifyConfettiPainter({required this.progress, required this.pieces});

  final double progress;
  final List<VerifyConfettiPiece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = verifyConfettiOpacity(progress);
    if (opacity <= 0 || size.isEmpty) return;
    final seconds = progress * kVerifyConfettiDuration.inMilliseconds / 1000;
    final paint = Paint();
    for (final piece in pieces) {
      final local = seconds - piece.delay;
      if (local <= 0) continue;
      final dx = piece.origin.dx * size.width + piece.velocity.dx * local;
      final dy =
          piece.origin.dy * size.height +
          piece.velocity.dy * local +
          0.5 * kVerifyConfettiGravity * local * local;
      paint.color = piece.color.withValues(alpha: opacity * piece.alpha);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(piece.rotation + piece.spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.width,
            height: piece.height,
          ),
          const Radius.circular(1.2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(VerifyConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pieces != pieces;
  }
}
