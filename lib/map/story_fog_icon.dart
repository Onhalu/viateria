import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../theme/brand_colors.dart';

/// Sage circle with a cream `?`, registered as a MapLibre icon.
///
/// Locked story stops use this image at a fog offset. It is not a logo.
Future<Uint8List> storyQuestionMarkPng({int size = 128}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final side = size.toDouble();
  canvas.drawCircle(
    Offset(side / 2, side / 2),
    side / 2 - 1,
    Paint()..color = BrandColors.sage,
  );
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: TextAlign.center,
            fontSize: side * 0.62,
            fontWeight: FontWeight.w700,
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            color: BrandColors.cream,
            fontSize: side * 0.62,
            fontWeight: FontWeight.w700,
          ),
        )
        ..addText('?');
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: side));
  canvas.drawParagraph(paragraph, Offset(0, (side - paragraph.height) / 2));
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
