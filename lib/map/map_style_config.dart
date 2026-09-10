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

  static const markerIconSize = 0.45;
  static const selectedMarkerIconSize = 0.55;

  /// POI disk diameter in dp (MapLibre radius is half). Unverified cream;
  /// verified solid bark. Selected is 32 dp, default 28.
  static const diskDiameter = 28.0;
  static const selectedDiskDiameter = 32.0;
  static const diskRadius = diskDiameter / 2;
  static const selectedDiskRadius = selectedDiskDiameter / 2;
  static const diskStrokeWidth = 1.5;
  static const verifiedDiskStrokeWidth = 0.0;

  /// Cream `#F3EFE5` at 94% — unverified / in-challenge disks.
  static const diskFillColor = 'rgba(243, 239, 229, 0.94)';

  static const diskLayerId = 'poi-disks';
  static const forestHex = '#35483C';
  static const sageHex = '#9C9A7B';
  static const barkHex = '#756653';
  static const creamHex = '#F3EFE5';

  /// SDF `placeState`: verified > inChallenge > outside.
  static const placeStateOutside = 'outside';
  static const placeStateInChallenge = 'inChallenge';
  static const placeStateVerified = 'verified';

  /// SDF icon-color for verified places (cream on a solid bark disk).
  /// Not [barkHex] — bark is the disk fill, never the icon tint.
  static const verifiedIconHex = creamHex;

  /// Verified disk fill: solid bark `#756653` at 100%.
  static const verifiedDiskFill = barkHex;

  static const searchDebounce = Duration(milliseconds: 300);
  static const searchLimit = 20;
  static const moveEndThrottle = Duration(milliseconds: 300);

  static const poiSourceId = 'pois';
  static const symbolLayerId = 'poi-symbols';

  static const hikeSourceId = 'challenge-hike';
  static const bikeSourceId = 'challenge-bike';
  static const hikeLayerId = 'challenge-hike-line';
  static const bikeLayerId = 'challenge-bike-line';

  static const CameraPosition defaultCamera = CameraPosition(
    target: czechCenter,
    zoom: defaultZoom,
  );

  /// SDF icon-color: verified cream > inChallenge forest > outside sage.
  static const markerColorExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateVerified,
    verifiedIconHex,
    placeStateInChallenge,
    forestHex,
    sageHex,
  ];

  /// Disk fill: verified solid bark; otherwise cream at 94%.
  static const diskFillExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateVerified,
    verifiedDiskFill,
    diskFillColor,
  ];

  /// Verified disks have no stroke; others keep 1.5 pt sage/forest.
  static const diskStrokeWidthExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateVerified,
    verifiedDiskStrokeWidth,
    diskStrokeWidth,
  ];

  /// Disk stroke matches the unverified icon (sage / forest). Unused when
  /// [diskStrokeWidthExpression] is 0 for verified.
  static const diskStrokeColorExpression = [
    Expressions.match,
    [Expressions.get, 'placeState'],
    placeStateInChallenge,
    forestHex,
    sageHex,
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
}
