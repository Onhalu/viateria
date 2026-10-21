import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/diploma_story_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the story frame defaults to 1080×1920', () {
    expect(diplomaStoryWidth, 1080);
    expect(diplomaStoryHeight, 1920);
    expect(diplomaStoryWidth / diplomaStoryHeight, closeTo(9 / 16, 0.0001));
  });

  testWidgets('golden 9:16 story frame keeps the diploma on forest', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() async {
      final diploma = await _solidPng(const Color(0xFFBA1A1A), 8, 8);
      final framed = await renderDiplomaStoryFrame(
        diploma,
        width: 90,
        height: 160,
      );
      final codec = await ui.instantiateImageCodec(framed);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 90);
      expect(frame.image.height, 160);
      expect(frame.image.width / frame.image.height, closeTo(9 / 16, 0.0001));

      final pixels = await frame.image.toByteData();
      expect(pixels, isNotNull);
      Color at(int x, int y) {
        final i = (y * frame.image.width + x) * 4;
        return Color.fromARGB(
          pixels!.getUint8(i + 3),
          pixels.getUint8(i),
          pixels.getUint8(i + 1),
          pixels.getUint8(i + 2),
        );
      }

      expect(at(0, 0), BrandColors.forest);
      expect(at(89, 0), BrandColors.forest);
      expect(at(0, 159), BrandColors.forest);
      expect(at(45, 80).toARGB32(), const Color(0xFFBA1A1A).toARGB32());
      frame.image.dispose();

      final golden = File('test/goldens/diploma_story_frame.png');
      if (!golden.existsSync()) {
        await golden.parent.create(recursive: true);
        await golden.writeAsBytes(framed, flush: true);
      }
      expect(framed, golden.readAsBytesSync());
      return framed;
    });
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(8));
  }, timeout: const Timeout(Duration(seconds: 30)));
}

Future<ui.Image> _picture(Color color, int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(width, height);
}

Future<Uint8List> _solidPng(Color color, int width, int height) async {
  final image = await _picture(color, width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
