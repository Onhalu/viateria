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

/// Open-Meteo elevation — free, no key, index-aligned heights.
class OpenMeteoElevationLookup implements ElevationLookup {
  OpenMeteoElevationLookup({http.Client? client})
    : _client = client ?? http.Client();

  static const _chunk = 99;

  final http.Client _client;

  @override
  Future<List<double?>> lookup(List<LatLng> points) async {
    if (points.isEmpty) return const [];
    final out = <double?>[];
    for (var i = 0; i < points.length; i += _chunk) {
      final end = math.min(i + _chunk, points.length);
      out.addAll(await _lookupChunk(points.sublist(i, end)));
    }
    return out;
  }

  Future<List<double?>> _lookupChunk(List<LatLng> points) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/elevation', {
      'latitude': points.map((p) => p.latitude.toStringAsFixed(6)).join(','),
      'longitude': points.map((p) => p.longitude.toStringAsFixed(6)).join(','),
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
    if (decoded is! Map) {
      throw const RoutingFailure('elevation failed');
    }
    if (decoded['error'] == true) {
      throw RoutingFailure('${decoded['reason'] ?? 'elevation failed'}');
    }
    final elevations = decoded['elevation'];
    if (elevations is! List || elevations.length != points.length) {
      throw const RoutingFailure('elevation failed');
    }
    return [
      for (final value in elevations) value is num ? value.toDouble() : null,
    ];
  }
}

/// Public OpenTopoData — POST, global ASTER, used if Open-Meteo fails.
class OpenTopoElevationLookup implements ElevationLookup {
  OpenTopoElevationLookup({http.Client? client})
    : _client = client ?? http.Client();

  static const _chunk = 100;

  final http.Client _client;

  @override
  Future<List<double?>> lookup(List<LatLng> points) async {
    if (points.isEmpty) return const [];
    final out = <double?>[];
    for (var i = 0; i < points.length; i += _chunk) {
      final end = math.min(i + _chunk, points.length);
      out.addAll(await _lookupChunk(points.sublist(i, end)));
    }
    return out;
  }

  Future<List<double?>> _lookupChunk(List<LatLng> points) async {
    final locations = points
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
        )
        .join('|');
    final uri = Uri.https('api.opentopodata.org', '/v1/aster30m');
    final response = await _client.post(
      uri,
      headers: const {
        'User-Agent': osmClientUserAgent,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'locations': locations}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RoutingFailure('elevation HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['status'] != 'OK') {
      throw const RoutingFailure('elevation failed');
    }
    final results = decoded['results'];
    if (results is! List || results.length != points.length) {
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

/// Tries Open-Meteo first, then OpenTopoData. Throws if both fail.
class PublicElevationLookup implements ElevationLookup {
  PublicElevationLookup({http.Client? client})
    : _primary = OpenMeteoElevationLookup(client: client),
      _fallback = OpenTopoElevationLookup(client: client);

  final ElevationLookup _primary;
  final ElevationLookup _fallback;

  @override
  Future<List<double?>> lookup(List<LatLng> points) async {
    try {
      return await _primary.lookup(points);
    } catch (_) {
      return _fallback.lookup(points);
    }
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
    final hikeSamples = hikePath == null
        ? const <LatLng>[]
        : sampleAlongRoute(hikePath.points);
    final bikeSamples = bikePath == null
        ? const <LatLng>[]
        : sampleAlongRoute(bikePath.points);
    final combined = [...hikeSamples, ...bikeSamples];
    List<double?>? heights;
    try {
      if (combined.isNotEmpty) {
        final lookedUp = await elevation.lookup(combined);
        if (lookedUp.length == combined.length) {
          heights = lookedUp;
        }
      }
    } catch (_) {
      heights = null;
    }
    final osmPoints = [start.toWaypoint(), end.toWaypoint(sortOrder: 1)];
    return DualRoutePlan(
      hike: hikePath == null
          ? null
          : _summary(
              mode: TravelMode.hike,
              path: hikePath,
              heights: heights == null
                  ? null
                  : heights.sublist(0, hikeSamples.length),
              osmPoints: osmPoints,
            ),
      bike: bikePath == null
          ? null
          : _summary(
              mode: TravelMode.bike,
              path: bikePath,
              heights: heights == null
                  ? null
                  : heights.sublist(hikeSamples.length),
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
    required List<double?>? heights,
    required List<Waypoint> osmPoints,
  }) {
    return planner.summarize(
      mode: mode,
      distanceKm: path.distanceKm,
      elevationGainM: elevationGainFromHeights(heights, planner),
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

/// Evenly sample the actual polyline by distance, interpolating vertices.
List<LatLng> sampleAlongRoute(List<LatLng> line, {int count = 40}) {
  if (line.length < 2) return List<LatLng>.from(line);
  const haversine = Distance();
  final cumulative = <double>[0];
  for (var i = 1; i < line.length; i++) {
    cumulative.add(
      cumulative.last + haversine.as(LengthUnit.Meter, line[i - 1], line[i]),
    );
  }
  final total = cumulative.last;
  if (total <= 0) return [line.first, line.last];
  final n = math.max(2, math.min(count, 100));
  final out = <LatLng>[];
  var edge = 0;
  for (var i = 0; i < n; i++) {
    final target = total * i / (n - 1);
    while (edge < cumulative.length - 2 && cumulative[edge + 1] < target) {
      edge++;
    }
    final span = cumulative[edge + 1] - cumulative[edge];
    final t = span <= 0
        ? 0.0
        : ((target - cumulative[edge]) / span).clamp(0.0, 1.0).toDouble();
    final a = line[edge];
    final b = line[edge + 1];
    out.add(
      LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
    );
  }
  return out;
}

/// Gain along sampled heights. Null if the series is unusable — never 0 from
/// missing data or two endpoints alone.
double? elevationGainFromHeights(List<double?>? raw, RoutePlanner planner) {
  // Two heights are endpoints only — gain must follow the walking/cycling line.
  if (raw == null || raw.length < 3) return null;
  final knownCount = raw.whereType<double>().length;
  if (knownCount < 2 || knownCount * 2 < raw.length) return null;
  final filled = fillHeightGaps(raw);
  if (filled == null || filled.length < 3) return null;
  return planner.elevationGainAlong(filled);
}

List<double>? fillHeightGaps(List<double?> raw) {
  final first = raw.indexWhere((h) => h != null);
  final last = raw.lastIndexWhere((h) => h != null);
  if (first < 0 || last < 0 || last == first) return null;
  final out = List<double?>.from(raw);
  for (var i = 0; i < first; i++) {
    out[i] = out[first];
  }
  for (var i = last + 1; i < out.length; i++) {
    out[i] = out[last];
  }
  var i = first;
  while (i <= last) {
    if (out[i] != null) {
      i++;
      continue;
    }
    final start = i - 1;
    var end = i;
    while (end <= last && out[end] == null) {
      end++;
    }
    final a = out[start]!;
    final b = out[end]!;
    final span = end - start;
    for (var k = 1; k < span; k++) {
      out[start + k] = a + (b - a) * (k / span);
    }
    i = end;
  }
  return [for (final h in out) h!];
}

bool _nearlySame(LatLng a, LatLng b) {
  return (a.latitude - b.latitude).abs() < 0.00001 &&
      (a.longitude - b.longitude).abs() < 0.00001;
}
