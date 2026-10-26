import 'package:maplibre_gl/maplibre_gl.dart';

/// MapLibre style + camera constants shared by every map surface.
///
/// Production style is injected at compile time:
/// `flutter run --dart-define=MAP_STYLE_URL=https://…/style.json`
///
/// TODO: Before release, set [MAP_STYLE_URL] to a production vector-tile
/// style from MapTiler, Stadia Maps, or a self-hosted OpenMapTiles stack.
/// Never point a raster tile layer at `https://tile.openstreetmap.org` —
/// that is OSM's tile usage policy, not a production CDN.
abstract final class MapStyleConfig {
  static const styleUrlFromEnv = String.fromEnvironment('MAP_STYLE_URL');

  /// Non-prod fallback: OpenFreeMap Liberty (OSM data via a public vector
  /// style). Used only when [MAP_STYLE_URL] is empty so local/dev builds
  /// still render a Czech basemap.
  static const nonProdFallbackStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';

  static bool get usingFallbackStyle => styleUrlFromEnv.isEmpty;

  static String get styleUrl =>
      usingFallbackStyle ? nonProdFallbackStyleUrl : styleUrlFromEnv;

  static const czechCenter = LatLng(49.8, 15.5);
  static const prague = LatLng(50.0755, 14.4378);
  static const defaultZoom = 7.0;

  /// Scale for the 88 px plastic bevels. City content is 56 px, so 0.36
  /// draws a 20 dp glyph inside the 32 dp disk (~6 dp of air).
  static const markerIconSize = 0.36;

  /// Selected disk is 36.8 dp. Same air ratio: 0.36 × 36.8 / 32.
  static const selectedMarkerIconSize = 0.41;

  /// POI disk diameter in dp (MapLibre radius is half). Selected is 1.15×.
  static const diskDiameter = 32.0;
  static const selectedDiskDiameter = 36.8;
  static const diskRadius = diskDiameter / 2;
  static const selectedDiskRadius = selectedDiskDiameter / 2;

  /// Rings: verified and outside are 1.5 dp. In-challenge is thicker.
  static const diskStrokeWidth = 1.5;
  static const inChallengeDiskStrokeWidth = 2.0;
  static const verifiedDiskStrokeWidth = 1.5;

  /// Opaque cream `#F3EFE5` for in-challenge disks. Full opacity so the pin
  /// in front covers the disk and glyph of the pin behind it.
  static const diskFillColor = '#F3EFE5';

  /// Opaque neutral `#FAF8F2` for places outside the open challenge.
  static const outsideDiskFill = '#FAF8F2';

  static const diskLayerId = 'poi-disks';
  static const forestHex = '#35483C';
  static const sageHex = '#9C9A7B';
  static const barkHex = '#756653';
  static const creamHex = '#F3EFE5';
  static const neutralHex = '#FAF8F2';

  /// `placeState`: verified > inChallenge > outside. Disk fill and ring use it.
  /// Category glyphs are not tinted.
  static const placeStateOutside = 'outside';
  static const placeStateInChallenge = 'inChallenge';
  static const placeStateVerified = 'verified';

  /// Verified disks draw no category icon (opacity 0).
  static const verifiedIconHex = creamHex;

  /// Verified disk fill `#A7B78C`, with a forest ring.
  static const verifiedDiskFill = '#A7B78C';

  /// Session route on the main map. Separate from challenge hike/bike lines.
  static const catalogRouteSourceId = 'catalog-route';
  static const catalogRouteLayerId = 'catalog-route-line';

  static const searchDebounce = Duration(milliseconds: 300);
  static const searchLimit = 20;
  static const moveEndThrottle = Duration(milliseconds: 300);

  static const poiSourceId = 'pois';
  static const symbolLayerId = 'poi-symbols';

  static const hikeSourceId = 'challenge-hike';
  static const bikeSourceId = 'challenge-bike';
  static const hikeLayerId = 'challenge-hike-line';
  static const bikeLayerId = 'challenge-bike-line';

  /// Locked story stops. Sage `?` at a fog offset, never the true coordinate.
  static const fogSourceId = 'story-fog';
  static const fogLayerId = 'story-fog-symbols';
  static const fogIconId = 'story-fog-question';

  static const CameraPosition defaultCamera = CameraPosition(
    target: czechCenter,
    zoom: defaultZoom,
  );

  /// Old SDF glyph tint. The symbol layer does not apply it; plastic bevels
  /// keep their own facets, and place state stays on the disk.
  static const markerColorExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateVerified,
    verifiedIconHex,
    placeStateInChallenge,
    forestHex,
    barkHex,
  ];

  /// Disk fill: verified sage-green, in-challenge cream, outside neutral @ 90%.
  static const diskFillExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateVerified,
    verifiedDiskFill,
    placeStateInChallenge,
    diskFillColor,
    outsideDiskFill,
  ];

  /// Verified ring is 1.5 dp. In-challenge ring is 2 dp. Outside is 1.5.
  static const diskStrokeWidthExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateVerified,
    verifiedDiskStrokeWidth,
    placeStateInChallenge,
    inChallengeDiskStrokeWidth,
    diskStrokeWidth,
  ];

  /// Verified and in-challenge rings are forest. Outside ring is sage.
  static const diskStrokeColorExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateVerified,
    forestHex,
    placeStateInChallenge,
    forestHex,
    sageHex,
  ];

  /// Verified places keep the disk and drop the category glyph. The baked
  /// pin leaves the glyph out and the symbol stays fully opaque — applying
  /// this match on the symbol would hide the disk as well.
  static const symbolOpacityExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateVerified,
    0,
    1,
  ];

  static const diskRadiusExpression = [
    Expressions.caseExpression,
    [
      Expressions.equal,
      [Expressions.get, 'selected'],
      1,
    ],
    selectedDiskRadius,
    diskRadius,
  ];

  static const markerSizeExpression = [
    Expressions.caseExpression,
    [
      Expressions.equal,
      [Expressions.get, 'selected'],
      1,
    ],
    selectedMarkerIconSize,
    markerIconSize,
  ];

  /// Shared image for every verified pin (disk only, no category glyph).
  static const verifiedPinImageId = 'pin-verified';

  /// Image id for one baked pin. Verified ignores [icon] and shares one disk.
  static String pinImageId(String icon, String placeState) {
    if (placeState == placeStateVerified) return verifiedPinImageId;
    return 'pin-$icon-$placeState';
  }

  /// Picks the baked pin. Disk and glyph are one image so MapLibre can
  /// occlude a whole pin at a time.
  static const pinImageExpression = [
    Expressions.caseExpression,
    [
      Expressions.equal,
      [Expressions.get, 'placeState'],
      placeStateVerified,
    ],
    verifiedPinImageId,
    [
      Expressions.concat,
      'pin-',
      [Expressions.get, 'icon'],
      '-',
      [Expressions.get, 'placeState'],
    ],
  ];
}
