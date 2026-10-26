import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/map/map_style_config.dart';
import 'package:viateria/map/place_pin_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pin disk paint is opaque and keeps the bevel', () async {
    for (final state in const [
      MapStyleConfig.placeStateInChallenge,
      MapStyleConfig.placeStateOutside,
      MapStyleConfig.placeStateVerified,
    ]) {
      final spec = placePinSpec(state);
      expect(spec.opaque, isTrue, reason: state);
      expect(spec.fill.a, 1, reason: state);
      expect(spec.stroke.a, 1, reason: state);
    }

    final glyph = await rootBundle.load('assets/map/icons/city@2x.png');
    final pin = await _decode(
      await placePinPng(
        spec: placePinSpec(MapStyleConfig.placeStateInChallenge),
        glyphPng: glyph.buffer.asUint8List(),
      ),
    );
    final center = ui.Offset(pin.width / 2, pin.height / 2);
    final padding = _at(pin, center.dx.round() + 34, center.dy.round());
    expect(padding.a, 255);
    expect(padding.rgb, 0xF3EFE5);

    var bevel = 0;
    for (final pixel in pin.pixels) {
      if (pixel.rgb == 0x374833 && pixel.a == 255) bevel++;
    }
    expect(bevel, greaterThan(20));

    final verified = await _decode(
      await placePinPng(spec: placePinSpec(MapStyleConfig.placeStateVerified)),
    );
    final verifiedCenter = _at(
      verified,
      (verified.width / 2).round(),
      (verified.height / 2).round(),
    );
    expect(verifiedCenter.a, 255);
    expect(verifiedCenter.rgb, 0xA7B78C);
    expect(verified.pixels.where((pixel) => pixel.rgb == 0x374833), isEmpty);
  });

  test('the pin in front hides the glyph of the pin behind it', () async {
    final gear = await rootBundle.load('assets/map/icons/technical@2x.png');
    final castle = await rootBundle.load('assets/map/icons/historical@2x.png');
    final behind = await _decode(
      await placePinPng(
        spec: placePinSpec(MapStyleConfig.placeStateInChallenge),
        glyphPng: gear.buffer.asUint8List(),
      ),
    );
    final front = await _decode(
      await placePinPng(
        spec: placePinSpec(MapStyleConfig.placeStateInChallenge),
        glyphPng: castle.buffer.asUint8List(),
      ),
    );

    final behindGlyph = behind.pixels.firstWhere(
      (pixel) => pixel.rgb == 0x374833 && pixel.a == 255,
    );
    final frontDisk = front.pixels.firstWhere((pixel) {
      final dx = pixel.x - front.width / 2;
      final dy = pixel.y - front.height / 2;
      return pixel.rgb == 0xF3EFE5 &&
          pixel.a == 255 &&
          dx * dx + dy * dy < 34 * 34;
    });
    final stacked = _over(
      _at(behind, behindGlyph.x, behindGlyph.y),
      _at(front, frontDisk.x, frontDisk.y),
    );
    expect(stacked.a, 255);
    expect(stacked.rgb, 0xF3EFE5);
    expect(stacked.rgb, isNot(behindGlyph.rgb));
  });
}

class _Pixel {
  const _Pixel(this.x, this.y, this.rgb, this.a);

  final int x;
  final int y;
  final int rgb;
  final int a;
}

class _Raster {
  _Raster(this.width, this.height, this.pixels);

  final int width;
  final int height;
  final List<_Pixel> pixels;
}

Future<_Raster> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final width = image.width;
  final height = image.height;
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final bytes = raw!.buffer.asUint8List();
  final pixels = <_Pixel>[];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      pixels.add(
        _Pixel(
          x,
          y,
          (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2],
          bytes[i + 3],
        ),
      );
    }
  }
  return _Raster(width, height, pixels);
}

_Pixel _at(_Raster raster, int x, int y) {
  return raster.pixels[y * raster.width + x];
}

_Pixel _over(_Pixel dst, _Pixel src) {
  final sa = src.a / 255;
  final da = dst.a / 255;
  final outA = sa + da * (1 - sa);
  int channel(int s, int d) {
    if (outA == 0) return 0;
    return (((s * sa) + (d * da * (1 - sa))) / outA).round();
  }

  final sr = (src.rgb >> 16) & 255;
  final sg = (src.rgb >> 8) & 255;
  final sb = src.rgb & 255;
  final dr = (dst.rgb >> 16) & 255;
  final dg = (dst.rgb >> 8) & 255;
  final db = dst.rgb & 255;
  return _Pixel(
    dst.x,
    dst.y,
    (channel(sr, dr) << 16) | (channel(sg, dg) << 8) | channel(sb, db),
    (outA * 255).round(),
  );
}
