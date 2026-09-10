import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/map/map_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SDF silhouette keeps 88×88 and whites out RGB', () async {
    final data = await rootBundle.load('assets/map/icons/city@2x.png');
    final sdf = await sdfSilhouettePng(data.buffer.asUint8List());
    final codec = await ui.instantiateImageCodec(sdf);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 88);
    expect(frame.image.height, 88);
    final raw = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(raw, isNotNull);
    final pixels = raw!.buffer.asUint8List();
    var opaque = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      if (pixels[i + 3] == 255) {
        opaque++;
        expect(pixels[i], 255);
        expect(pixels[i + 1], 255);
        expect(pixels[i + 2], 255);
      }
    }
    expect(opaque, greaterThan(100));
    frame.image.dispose();
  });

  test(
    'category icons are 88×88 white silhouettes with 66 px optical size',
    () async {
      const names = ['city', 'nature', 'technical', 'historical'];
      for (final name in names) {
        final data = await rootBundle.load('assets/map/icons/$name@2x.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 88, reason: name);
        expect(frame.image.height, 88, reason: name);
        final raw = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(raw, isNotNull, reason: name);
        final pixels = raw!.buffer.asUint8List();
        var minX = 88, minY = 88, maxX = -1, maxY = -1;
        var opaque = 0;
        for (var y = 0; y < 88; y++) {
          for (var x = 0; x < 88; x++) {
            final i = (y * 88 + x) * 4;
            final a = pixels[i + 3];
            if (a == 0) continue;
            expect(pixels[i], 255, reason: name);
            expect(pixels[i + 1], 255, reason: name);
            expect(pixels[i + 2], 255, reason: name);
            if (a > 16) {
              if (x < minX) minX = x;
              if (y < minY) minY = y;
              if (x > maxX) maxX = x;
              if (y > maxY) maxY = y;
            }
            if (a == 255) opaque++;
          }
        }
        expect(maxX, greaterThanOrEqualTo(minX), reason: name);
        final contentW = maxX - minX + 1;
        final contentH = maxY - minY + 1;
        final maxSide = contentW >= contentH ? contentW : contentH;
        expect(maxSide, 66, reason: name);
        expect(opaque, greaterThan(100), reason: name);
        frame.image.dispose();
      }
    },
  );
}
