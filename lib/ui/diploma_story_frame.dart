import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// Instagram and Facebook Stories frame. 9:16, diploma centered on forest.
const diplomaStoryWidth = 1080;
const diplomaStoryHeight = 1920;

/// Paints [diplomaPng] on a brand-colour ground. The default size is 9:16.
/// Tests pass a smaller [width] and [height] that keep the same ratio.
Future<Uint8List> renderDiplomaStoryFrame(
  Uint8List diplomaPng, {
  int width = diplomaStoryWidth,
  int height = diplomaStoryHeight,
  Color background = BrandColors.forest,
}) async {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('story frame size');
  }
  final codec = await ui.instantiateImageCodec(diplomaPng);
  final frame = await codec.getNextFrame();
  final diploma = frame.image;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = background,
  );
  final side = width * 0.78;
  final dst = Rect.fromCenter(
    center: Offset(width / 2, height / 2),
    width: side,
    height: side,
  );
  canvas.drawImageRect(
    diploma,
    Rect.fromLTWH(0, 0, diploma.width.toDouble(), diploma.height.toDouble()),
    dst,
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  diploma.dispose();
  image.dispose();
  if (bytes == null) throw StateError('story frame encode');
  return bytes.buffer.asUint8List();
}
