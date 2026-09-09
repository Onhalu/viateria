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

  static const clusterRadius = 45;
  static const clusterMaxZoom = 13;

  static const searchDebounce = Duration(milliseconds: 300);
  static const searchLimit = 20;
  static const moveEndThrottle = Duration(milliseconds: 300);

  static const poiSourceId = 'pois';
  static const clusterLayerId = 'poi-clusters';
  static const clusterCountLayerId = 'poi-cluster-count';
  static const symbolLayerId = 'poi-symbols';

  static const CameraPosition defaultCamera = CameraPosition(
    target: czechCenter,
    zoom: defaultZoom,
  );
}
