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
            expect(a, 255, reason: name);
            expect(pixels[i], 255, reason: name);
            expect(pixels[i + 1], 255, reason: name);
            expect(pixels[i + 2], 255, reason: name);
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
            opaque++;
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

  test('category icon filenames match their silhouettes', () async {
    // On-disk graphic contract. Category → filename stays 1:1 in code;
    // these bytes are what each name must contain:
    // city = town/skyline, nature = tree, technical = derrick + gear,
    // historical = castle. A previous batch had the three non-nature
    // files rotated relative to those names.
    const expected = <String, (int, int)>{
      'city': (707, 0x58703650),
      'nature': (1030, 0x007a7bce),
      'technical': (780, 0xaecae4f1),
      'historical': (526, 0x56e7ca30),
    };
    for (final entry in expected.entries) {
      final data = await rootBundle.load(
        'assets/map/icons/${entry.key}@2x.png',
      );
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(bytes.length, entry.value.$1, reason: entry.key);
      expect(_fnv1a(bytes), entry.value.$2, reason: entry.key);
    }
  });
}

int _fnv1a(Uint8List bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
