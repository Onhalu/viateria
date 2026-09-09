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
    final raw = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
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
}
