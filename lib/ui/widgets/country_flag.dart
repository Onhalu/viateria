import 'package:flutter/material.dart';

import '../../domain/catalog_query.dart';

/// 22×16 SVG-geometry flags for catalog region chips. Not emoji.
class CountryFlag extends StatelessWidget {
  const CountryFlag({
    super.key,
    required this.code,
    this.width = 22,
    this.height = 16,
  });

  final String code;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final resolved = parseCountryCode(code) ?? code.toUpperCase();
    return Semantics(
      label: resolved,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRect(child: CustomPaint(painter: _FlagPainter(resolved))),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter(this.code);

  final String code;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (code) {
      case 'CZ':
        _rect(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFD7141A));
        _rect(canvas, Rect.fromLTWH(0, 0, w, h / 2), const Color(0xFFFFFFFF));
        final triangle = Path()
          ..moveTo(0, 0)
          ..lineTo(w / 2, h / 2)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(triangle, Paint()..color = const Color(0xFF11457E));
      case 'SK':
        _rect(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFEE1C25));
        _rect(
          canvas,
          Rect.fromLTWH(0, 0, w, h * 2 / 3),
          const Color(0xFF0B4EA2),
        );
        _rect(canvas, Rect.fromLTWH(0, 0, w, h / 3), const Color(0xFFFFFFFF));
        _slovakShield(canvas, size);
      case 'AT':
        _rect(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFED2939));
        _rect(
          canvas,
          Rect.fromLTWH(0, h / 3, w, h / 3),
          const Color(0xFFFFFFFF),
        );
      case 'DE':
        _rect(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFFFCC00));
        _rect(
          canvas,
          Rect.fromLTWH(0, 0, w, h * 2 / 3),
          const Color(0xFFDD0000),
        );
        _rect(canvas, Rect.fromLTWH(0, 0, w, h / 3), const Color(0xFF000000));
      case 'PL':
        _rect(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFDC143C));
        _rect(canvas, Rect.fromLTWH(0, 0, w, h / 2), const Color(0xFFFFFFFF));
      default:
        _rect(canvas, Rect.fromLTWH(0, 0, w, h), const Color(0xFFD8CDB8));
    }
  }

  void _slovakShield(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shield = Path()
      ..moveTo(w * 0.24, h * 0.21)
      ..lineTo(w * 0.44, h * 0.21)
      ..lineTo(w * 0.44, h * 0.62)
      ..quadraticBezierTo(w * 0.34, h * 0.82, w * 0.34, h * 0.82)
      ..quadraticBezierTo(w * 0.24, h * 0.62, w * 0.24, h * 0.62)
      ..close();
    canvas.drawPath(shield, Paint()..color = const Color(0xFFEE1C25));
    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (h * 0.04).clamp(0.6, 1.2),
    );
    final cross = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = (h * 0.07).clamp(0.8, 1.6)
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final cx = w * 0.34;
    canvas.drawLine(Offset(cx, h * 0.32), Offset(cx, h * 0.64), cross);
    canvas.drawLine(
      Offset(w * 0.275, h * 0.40),
      Offset(w * 0.405, h * 0.40),
      cross,
    );
    canvas.drawLine(
      Offset(w * 0.285, h * 0.51),
      Offset(w * 0.395, h * 0.51),
      cross,
    );
  }

  void _rect(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.code != code;
}
