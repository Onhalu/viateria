import 'dart:typed_data';
import 'dart:ui' as ui;

import 'map_style_config.dart';

/// Fill, ring, and whether the category bevel is drawn for one place state.
class PlacePinSpec {
  const PlacePinSpec({
    required this.fill,
    required this.stroke,
    required this.strokeDp,
  });

  final ui.Color fill;
  final ui.Color stroke;
  final double strokeDp;

  bool get opaque => fill.a == 1 && stroke.a == 1;
}

/// Paint for a baked pin. Fills are opaque so a pin in front hides the one
/// behind it.
PlacePinSpec placePinSpec(String placeState) {
  return switch (placeState) {
    MapStyleConfig.placeStateVerified => PlacePinSpec(
      fill: _hex(MapStyleConfig.verifiedDiskFill),
      stroke: _hex(MapStyleConfig.forestHex),
      strokeDp: MapStyleConfig.verifiedDiskStrokeWidth,
    ),
    MapStyleConfig.placeStateInChallenge => PlacePinSpec(
      fill: _hex(MapStyleConfig.diskFillColor),
      stroke: _hex(MapStyleConfig.forestHex),
      strokeDp: MapStyleConfig.inChallengeDiskStrokeWidth,
    ),
    _ => PlacePinSpec(
      fill: _hex(MapStyleConfig.outsideDiskFill),
      stroke: _hex(MapStyleConfig.sageHex),
      strokeDp: MapStyleConfig.diskStrokeWidth,
    ),
  };
}

/// One map pin: opaque disk and ring, then the category bevel centered on it.
///
/// The bevel PNG is drawn at its native 88 px. At [MapStyleConfig.markerIconSize]
/// (0.36) the disk is 32 dp and the city glyph stays about 20 dp. Transparent
/// pixels of the bevel leave the disk in place, so the ring and cream are part
/// of the same image MapLibre sorts.
Future<ui.Image> placePinImage({required PlacePinSpec spec, ui.Image? glyph}) {
  if (!spec.opaque) {
    throw ArgumentError('Pin disk fill and ring must be opaque');
  }
  final diskPx = MapStyleConfig.diskDiameter / MapStyleConfig.markerIconSize;
  final strokePx = spec.strokeDp / MapStyleConfig.markerIconSize;
  final canvasSide = (diskPx + strokePx).ceil() + 4;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final center = ui.Offset(canvasSide / 2, canvasSide / 2);
  final radius = diskPx / 2;
  canvas.drawCircle(center, radius, ui.Paint()..color = spec.fill);
  canvas.drawCircle(
    center,
    radius,
    ui.Paint()
      ..color = spec.stroke
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokePx,
  );
  if (glyph != null) {
    final source = ui.Rect.fromLTWH(
      0,
      0,
      glyph.width.toDouble(),
      glyph.height.toDouble(),
    );
    final dest = ui.Rect.fromCenter(
      center: center,
      width: source.width,
      height: source.height,
    );
    canvas.drawImageRect(
      glyph,
      source,
      dest,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }
  final picture = recorder.endRecording();
  return picture.toImage(canvasSide, canvasSide);
}

/// PNG bytes for [placePinImage]. [glyphPng] is omitted for verified pins.
Future<Uint8List> placePinPng({
  required PlacePinSpec spec,
  Uint8List? glyphPng,
}) async {
  ui.Image? glyph;
  if (glyphPng != null) {
    final codec = await ui.instantiateImageCodec(glyphPng);
    final frame = await codec.getNextFrame();
    glyph = frame.image;
  }
  final image = await placePinImage(spec: spec, glyph: glyph);
  glyph?.dispose();
  final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (encoded == null) {
    throw StateError('Failed to encode place pin');
  }
  return encoded.buffer.asUint8List();
}

ui.Color _hex(String hex) {
  final rgb = int.parse(hex.substring(1), radix: 16);
  return ui.Color(0xFF000000 | rgb);
}
