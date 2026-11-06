import 'package:flutter/material.dart';

import '../../theme/brand_colors.dart';

/// Mono line icons for the four benefit slides. Not a generated logo.
class VanderyPlusBenefitIcon extends StatelessWidget {
  const VanderyPlusBenefitIcon({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    if (index == 3) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Icon(
          Icons.explore_outlined,
          size: 32,
          color: BrandColors.forest,
        ),
      );
    }
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(painter: _BenefitPainter(index)),
    );
  }
}

class HiddenDiplomaSilhouette extends StatelessWidget {
  const HiddenDiplomaSilhouette({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x599C9A7B),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Center(
          child: Text(
            '?',
            style: TextStyle(
              color: BrandColors.bark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitPainter extends CustomPainter {
  const _BenefitPainter(this.index);

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BrandColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    switch (index) {
      case 0:
        canvas.drawCircle(c, 16, paint);
        final check = Path()
          ..moveTo(c.dx - 8, c.dy)
          ..lineTo(c.dx - 2, c.dy + 6)
          ..lineTo(c.dx + 9, c.dy - 7);
        canvas.drawPath(check, paint);
      case 1:
        canvas.drawCircle(Offset(c.dx, c.dy - 4), 8, paint);
        final ribbon = Path()
          ..moveTo(c.dx - 7, c.dy + 2)
          ..lineTo(c.dx - 10, c.dy + 16)
          ..lineTo(c.dx, c.dy + 10)
          ..lineTo(c.dx + 10, c.dy + 16)
          ..lineTo(c.dx + 7, c.dy + 2);
        canvas.drawPath(ribbon, paint);
      case 2:
        canvas.drawLine(Offset(14, 34), Offset(22, 34), paint);
        canvas.drawLine(Offset(14, 26), Offset(30, 26), paint);
        canvas.drawLine(Offset(14, 18), Offset(38, 18), paint);
        canvas.drawCircle(const Offset(18, 34), 2, Paint()..color = BrandColors.forest);
      default:
        canvas.drawCircle(c, 16, paint);
    }
  }

  @override
  bool shouldRepaint(_BenefitPainter oldDelegate) => oldDelegate.index != index;
}
