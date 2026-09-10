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

  test('historical icon is 88×88 with content at most 48 px', () async {
    final data = await rootBundle.load('assets/map/icons/historical@2x.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 88);
    expect(frame.image.height, 88);
    final raw = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(raw, isNotNull);
    final pixels = raw!.buffer.asUint8List();
    var minX = 88, minY = 88, maxX = -1, maxY = -1;
    for (var y = 0; y < 88; y++) {
      for (var x = 0; x < 88; x++) {
        final a = pixels[(y * 88 + x) * 4 + 3];
        if (a == 0) continue;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    expect(maxX, greaterThanOrEqualTo(minX));
    final contentW = maxX - minX + 1;
    final contentH = maxY - minY + 1;
    expect(contentW, lessThanOrEqualTo(48));
    expect(contentH, lessThanOrEqualTo(48));
    expect(contentW >= contentH ? contentW : contentH, 48);
    frame.image.dispose();
  });
}
