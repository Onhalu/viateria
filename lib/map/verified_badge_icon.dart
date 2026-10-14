import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../theme/brand_colors.dart';

/// Cream check drawn for the verified-place badge. Not a logo.
Future<Uint8List> verifiedBadgePng({int size = 64}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final side = size.toDouble();
  final paint = Paint()
    ..color = BrandColors.cream
    ..style = PaintingStyle.stroke
    ..strokeWidth = side * 0.16
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final path = Path()
    ..moveTo(side * 0.18, side * 0.52)
    ..lineTo(side * 0.40, side * 0.74)
    ..lineTo(side * 0.84, side * 0.26);
  canvas.drawPath(path, paint);
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
