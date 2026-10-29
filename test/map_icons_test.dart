import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'category icons are 88×88 plastic bevels sized for the 32 dp disk',
    () async {
      // Official Kompas map_bevel set (optical scale 0.75). City is the
      // widest glyph; markerIconSize 0.36 turns 56 px into a 20 dp bbox.
      // city = houses, nature = tree, technical = gear on pedestal,
      // historical = castle.
      const expectedMaxSide = <String, int>{
        'city': 56,
        'nature': 53,
        'technical': 53,
        'historical': 51,
      };
      const facets = <int>[
        0x374833, // base
        0x5E7457, // light edge
        0xA3B59D, // lightest edge
        0x24301F, // shadow
      ];
      for (final entry in expectedMaxSide.entries) {
        final name = entry.key;
        final data = await rootBundle.load('assets/map/icons/$name@2x.png');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
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
        var nonWhite = 0;
        final tones = <int>{};
        for (var y = 0; y < 88; y++) {
          for (var x = 0; x < 88; x++) {
            final i = (y * 88 + x) * 4;
            if (pixels[i + 3] == 0) continue;
            opaque++;
            final rgb =
                (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
            if (rgb != 0xFFFFFF) nonWhite++;
            tones.add(rgb);
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
          }
        }
        expect(maxX, greaterThanOrEqualTo(minX), reason: name);
        final contentW = maxX - minX + 1;
        final contentH = maxY - minY + 1;
        final maxSide = contentW >= contentH ? contentW : contentH;
        expect(maxSide, entry.value, reason: name);
        expect(maxSide, inInclusiveRange(46, 58), reason: name);
        expect(opaque, greaterThan(100), reason: name);
        expect(nonWhite, opaque, reason: name);
        expect(tones.length, greaterThan(8), reason: name);
        for (final facet in facets) {
          expect(
            tones.contains(facet),
            isTrue,
            reason: '$name #${facet.toRadixString(16)}',
          );
        }
        frame.image.dispose();
      }
    },
  );
}
