import 'dart:math' as math;

import '../models/models.dart';

/// Gap between mosaic tiles, in logical pixels.
const challengePhotoGap = 8.0;

/// Corner radius of a mosaic tile and the lightbox image clip.
const challengePhotoRadius = 12.0;

/// Real `waypoint-photos` object path, or null when [photoPath] is blank
/// or a GPS completion sentinel (`{userId}/gps/...`).
///
/// GPS rows are progress, not image objects. Keep this rule aligned with
/// `challenge_waypoint_photos` in
/// `supabase/migrations/0008_challenge_waypoint_photos.sql`.
String? displayablePhotoPath(String? photoPath) {
  if (photoPath == null) return null;
  final trimmed = photoPath.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.contains('/gps/')) return null;
  return trimmed;
}

/// One signed-in-or-not verification photo ready to paint.
class ChallengeGalleryPhoto {
  const ChallengeGalleryPhoto({
    required this.waypointId,
    required this.imageUrl,
  });

  final String waypointId;
  final String imageUrl;
}

/// Keeps [rows] order. Skips paths that are not displayable photos and
/// paths whose signed URL is missing.
///
/// Throws [StateError] when at least one displayable row was requested and
/// every URL failed, so the screen can retry instead of showing the empty
/// gallery copy.
List<ChallengeGalleryPhoto> resolveChallengePhotoGallery({
  required List<ChallengeWaypointPhoto> rows,
  required Map<String, String> urls,
}) {
  final photos = <ChallengeGalleryPhoto>[];
  var displayable = 0;
  for (final row in rows) {
    final path = displayablePhotoPath(row.photoPath);
    if (path == null) continue;
    displayable++;
    final url = urls[path] ?? urls[row.photoPath];
    if (url == null || url.isEmpty) continue;
    photos.add(
      ChallengeGalleryPhoto(waypointId: row.waypointId, imageUrl: url),
    );
  }
  if (displayable > 0 && photos.isEmpty) {
    throw StateError('challenge photo URLs unavailable');
  }
  return photos;
}

/// Place title for a gallery caption. Same lookup the waypoint list uses.
String challengePhotoPlaceName({
  required List<Waypoint> waypoints,
  required String waypointId,
  required String locale,
}) {
  for (final waypoint in waypoints) {
    if (waypoint.id == waypointId) {
      return waypoint.copyFor(locale).title;
    }
  }
  return '';
}

/// Width / height. Cycles 3:4, 1:1, 4:3 by tile index.
double challengePhotoAspectRatio(int index) {
  return switch (index % 3) {
    0 => 3 / 4,
    1 => 1,
    _ => 4 / 3,
  };
}

class ChallengePhotoTileFrame {
  const ChallengePhotoTileFrame({
    required this.index,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int index;
  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
}

class ChallengePhotoMosaicLayout {
  const ChallengePhotoMosaicLayout({
    required this.tiles,
    required this.width,
    required this.height,
  });

  final List<ChallengePhotoTileFrame> tiles;
  final double width;
  final double height;
}

/// Two-column masonry. The next tile goes in the shorter column so the
/// 3:4 / 1:1 / 4:3 cycle does not line up as a uniform grid.
ChallengePhotoMosaicLayout layoutChallengePhotoMosaic({
  required int count,
  required double width,
  double gap = challengePhotoGap,
}) {
  if (count <= 0 || width <= gap) {
    return ChallengePhotoMosaicLayout(tiles: const [], width: width, height: 0);
  }
  final columnWidth = (width - gap) / 2;
  final columnBottom = <double>[0, 0];
  final tiles = <ChallengePhotoTileFrame>[];
  for (var i = 0; i < count; i++) {
    final tileHeight = columnWidth / challengePhotoAspectRatio(i);
    final column = columnBottom[0] <= columnBottom[1] ? 0 : 1;
    final top = columnBottom[column] == 0 ? 0.0 : columnBottom[column] + gap;
    final left = column == 0 ? 0.0 : columnWidth + gap;
    tiles.add(
      ChallengePhotoTileFrame(
        index: i,
        left: left,
        top: top,
        width: columnWidth,
        height: tileHeight,
      ),
    );
    columnBottom[column] = top + tileHeight;
  }
  final height = math.max(columnBottom[0], columnBottom[1]);
  return ChallengePhotoMosaicLayout(tiles: tiles, width: width, height: height);
}

class ChallengePhotoMosaicBand {
  const ChallengePhotoMosaicBand({
    required this.top,
    required this.height,
    required this.tiles,
  });

  final double top;
  final double height;
  final List<ChallengePhotoTileFrame> tiles;
}

/// Vertical slices that never cut a tile, so a sliver list can build only
/// the bands near the viewport.
List<ChallengePhotoMosaicBand> bandChallengePhotoMosaic(
  ChallengePhotoMosaicLayout layout, {
  double targetExtent = 900,
}) {
  if (layout.tiles.isEmpty || layout.height <= 0) return const [];
  final bands = <ChallengePhotoMosaicBand>[];
  var y = 0.0;
  while (y < layout.height - 0.01) {
    var cut = math.min(y + targetExtent, layout.height);
    var extended = true;
    while (extended) {
      extended = false;
      for (final tile in layout.tiles) {
        if (tile.top < cut - 0.01 && tile.bottom > cut + 0.01) {
          cut = tile.bottom;
          extended = true;
        }
      }
    }
    if (cut <= y) cut = layout.height;
    final bandTiles = [
      for (final tile in layout.tiles)
        if (tile.top >= y - 0.01 && tile.bottom <= cut + 0.01) tile,
    ];
    bands.add(
      ChallengePhotoMosaicBand(top: y, height: cut - y, tiles: bandTiles),
    );
    y = cut;
  }
  return bands;
}
