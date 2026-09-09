import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../domain/route_planner.dart';
import '../models/models.dart';

/// Identify this app to public OSM services (Nominatim / FOSSGIS OSRM).
const osmClientUserAgent = 'Viateria/1.0 (https://github.com/Onhalu/viateria)';

class RoutingFailure implements Exception {
  const RoutingFailure([this.message = 'routing failed']);

  final String message;

  @override
  String toString() => message;
}

class LocationFailure implements Exception {
  const LocationFailure([this.message = 'location failed']);

  final String message;

  @override
  String toString() => message;
}

class RoutedPath {
  const RoutedPath({
    required this.points,
    required this.distanceMeters,
    required this.duration,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final Duration duration;

  double get distanceKm => distanceMeters / 1000.0;
}

class DualRoutePlan {
  const DualRoutePlan({
    this.hike,
    this.bike,
    this.hikeLine = const [],
    this.bikeLine = const [],
  });

  final RouteSummary? hike;
  final RouteSummary? bike;
  final List<LatLng> hikeLine;
  final List<LatLng> bikeLine;

  bool get isEmpty => hike == null && bike == null;
}

abstract class RoutingClient {
  Future<RoutedPath> route({
    required TravelMode mode,
    required LatLng start,
    required LatLng end,
  });
}

abstract class PlaceGeocoder {
  Future<RouteEndpoint?> findPlace(String query, {LatLng? near});
}

abstract class DeviceLocation {
  Future<RouteEndpoint> current();
}

abstract class ElevationLookup {
  Future<List<double?>> lookup(List<LatLng> points);
}

/// FOSSGIS OSRM — same engines already used in OSM directions links.
class OsrmRoutingClient implements RoutingClient {
  OsrmRoutingClient({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'routing.openstreetmap.de';

  final http.Client _client;

  @override
  Future<RoutedPath> route({
    required TravelMode mode,
    required LatLng start,
    required LatLng end,
  }) async {
    final profile = mode == TravelMode.bike ? 'bike' : 'foot';
    final coords =
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    final uri = Uri.https(
      _host,
      '/routed-$profile/route/v1/driving/$coords',
      const {
        'overview': 'full',
        'geometries': 'geojson',
        'alternatives': 'false',
      },
    );
    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': osmClientUserAgent,
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RoutingFailure('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RoutingFailure('invalid body');
    }
    if (decoded['code'] != 'Ok') {
      throw RoutingFailure('${decoded['code']}');
    }
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw const RoutingFailure('no route');
    }
    final route = routes.first as Map<String, dynamic>;
    final distance = (route['distance'] as num?)?.toDouble() ?? 0;
    final durationSec = (route['duration'] as num?)?.toDouble() ?? 0;
    final geometry = route['geometry'];
    final points = <LatLng>[];
    if (geometry is Map && geometry['coordinates'] is List) {
      for (final pair in geometry['coordinates'] as List) {
        if (pair is List && pair.length >= 2) {
          final lon = (pair[0] as num).toDouble();
          final lat = (pair[1] as num).toDouble();
          points.add(LatLng(lat, lon));
        }
      }
    }
    if (points.length < 2) {
      throw const RoutingFailure('empty geometry');
    }
    return RoutedPath(
      points: points,
      distanceMeters: distance,
      duration: Duration(seconds: durationSec.round()),
    );
  }
}

class NominatimGeocoder implements PlaceGeocoder {
  NominatimGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<RouteEndpoint?> findPlace(String query, {LatLng? near}) async {
    final parsed = parseCoordinateQuery(query);
    if (parsed != null) return parsed;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    final params = <String, String>{
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '1',
    };
    if (near != null) {
      params['lat'] = near.latitude.toString();
      params['lon'] = near.longitude.toString();
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': osmClientUserAgent,
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RoutingFailure('geocode HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return null;
    final first = decoded.first;
    if (first is! Map) return null;
    final lat = double.tryParse('${first['lat']}');
    final lon = double.tryParse('${first['lon']}');
    if (lat == null || lon == null) return null;
    final name = '${first['display_name'] ?? trimmed}';
    return RouteEndpoint(lat: lat, lng: lon, label: name);
  }
}

class GeolocatorDeviceLocation implements DeviceLocation {
  const GeolocatorDeviceLocation();

  @override
  Future<RouteEndpoint> current() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationFailure('disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationFailure('denied');
    }
    final position = await Geolocator.getCurrentPosition();
    return RouteEndpoint(
      lat: position.latitude,
      lng: position.longitude,
      label: 'GPS',
    );
  }
}

/// Public OpenTopoData EU-DEM — no API key, suitable for Czech terrain.
class OpenTopoElevationLookup implements ElevationLookup {
  OpenTopoElevationLookup({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<double?>> lookup(List<LatLng> points) async {
    if (points.isEmpty) return const [];
    final limited = points.length > 100 ? points.sublist(0, 100) : points;
    final locations = limited
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
        )
        .join('|');
    final uri = Uri.https('api.opentopodata.org', '/v1/eudem25m', {
      'locations': locations,
    });
    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': osmClientUserAgent,
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RoutingFailure('elevation HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['status'] != 'OK') {
      throw const RoutingFailure('elevation failed');
    }
    final results = decoded['results'];
    if (results is! List) {
      throw const RoutingFailure('elevation failed');
    }
    return [
      for (final row in results)
        row is Map && row['elevation'] is num
            ? (row['elevation'] as num).toDouble()
            : null,
    ];
  }
}

class DualRoutePlanner {
  DualRoutePlanner({
    required this.routing,
    required this.elevation,
    this.planner = const RoutePlanner(),
  });

  final RoutingClient routing;
  final ElevationLookup elevation;
  final RoutePlanner planner;

  Future<DualRoutePlan> plan({
    required RouteEndpoint start,
    required RouteEndpoint end,
  }) async {
    if (_nearlySame(start.latLng, end.latLng)) {
      return const DualRoutePlan();
    }
    final paths = await Future.wait([
      _tryRoute(TravelMode.hike, start.latLng, end.latLng),
      _tryRoute(TravelMode.bike, start.latLng, end.latLng),
    ]);
    final hikePath = paths[0];
    final bikePath = paths[1];
    if (hikePath == null && bikePath == null) {
      throw const RoutingFailure();
    }
    final hikeSamples = samplePoints(hikePath?.points ?? const []);
    final bikeSamples = samplePoints(bikePath?.points ?? const []);
    final combined = [...hikeSamples, ...bikeSamples];
    List<double?> heights = const [];
    try {
      if (combined.isNotEmpty) {
        heights = await elevation.lookup(combined);
      }
    } catch (_) {
      heights = const [];
    }
    final byKey = <String, double>{};
    for (var i = 0; i < combined.length && i < heights.length; i++) {
      final value = heights[i];
      if (value != null) {
        byKey[_pointKey(combined[i])] = value;
      }
    }
    final osmPoints = [start.toWaypoint(), end.toWaypoint(sortOrder: 1)];
    return DualRoutePlan(
      hike: hikePath == null
          ? null
          : _summary(
              mode: TravelMode.hike,
              path: hikePath,
              samples: hikeSamples,
              elevations: byKey,
              start: start,
              end: end,
              osmPoints: osmPoints,
            ),
      bike: bikePath == null
          ? null
          : _summary(
              mode: TravelMode.bike,
              path: bikePath,
              samples: bikeSamples,
              elevations: byKey,
              start: start,
              end: end,
              osmPoints: osmPoints,
            ),
      hikeLine: hikePath?.points ?? const [],
      bikeLine: bikePath?.points ?? const [],
    );
  }

  Future<RoutedPath?> _tryRoute(
    TravelMode mode,
    LatLng start,
    LatLng end,
  ) async {
    try {
      return await routing.route(mode: mode, start: start, end: end);
    } catch (_) {
      return null;
    }
  }

  RouteSummary _summary({
    required TravelMode mode,
    required RoutedPath path,
    required List<LatLng> samples,
    required Map<String, double> elevations,
    required RouteEndpoint start,
    required RouteEndpoint end,
    required List<Waypoint> osmPoints,
  }) {
    final sampled = [
      for (final point in samples)
        if (elevations.containsKey(_pointKey(point)))
          elevations[_pointKey(point)]!,
    ];
    var gain = planner.elevationGainAlong(sampled);
    if (sampled.length < 2) {
      final startM = start.elevationM;
      final endM = end.elevationM;
      if (startM != null && endM != null) {
        gain = math.max(0, endM - startM);
      }
    }
    return planner.summarize(
      mode: mode,
      distanceKm: path.distanceKm,
      elevationGainM: gain,
      osmPoints: osmPoints,
    );
  }
}

RouteEndpoint? parseCoordinateQuery(String raw) {
  final match = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$')
      .firstMatch(raw);
  if (match == null) return null;
  final lat = double.parse(match.group(1)!);
  final lng = double.parse(match.group(2)!);
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return RouteEndpoint(lat: lat, lng: lng, label: raw.trim());
}

List<LatLng> samplePoints(List<LatLng> line, {int maxPoints = 20}) {
  if (line.isEmpty) return const [];
  if (line.length <= maxPoints) return List<LatLng>.from(line);
  final result = <LatLng>[];
  final step = (line.length - 1) / (maxPoints - 1);
  for (var i = 0; i < maxPoints; i++) {
    result.add(line[(i * step).round()]);
  }
  return result;
}

bool _nearlySame(LatLng a, LatLng b) {
  return (a.latitude - b.latitude).abs() < 0.00001 &&
      (a.longitude - b.longitude).abs() < 0.00001;
}

String _pointKey(LatLng point) =>
    '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
