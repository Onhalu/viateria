import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Rewrites a category PNG to a white-alpha silhouette for MapLibre SDF.
///
/// Source files stay forest-tinted on disk (88×88). At register time we keep
/// alpha and set RGB to white so `icon-color` can tint in-challenge (forest)
/// vs out-of-challenge (sage) at runtime.
Future<Uint8List> sdfSilhouettePng(Uint8List pngBytes) async {
  final codec = await ui.instantiateImageCodec(pngBytes);
  final frame = await codec.getNextFrame();
  final source = frame.image;
  final width = source.width;
  final height = source.height;
  final raw = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
  source.dispose();
  if (raw == null) return pngBytes;

  final pixels = Uint8List.fromList(raw.buffer.asUint8List());
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = 255;
    pixels[i + 1] = 255;
    pixels[i + 2] = 255;
  }

  final image = await _imageFromRgba(pixels, width, height);
  final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (encoded == null) return pngBytes;
  return encoded.buffer.asUint8List();
}

Future<ui.Image> _imageFromRgba(Uint8List pixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
