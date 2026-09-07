import 'dart:math' as math;

import '../models/models.dart';

class RouteSummary {
  const RouteSummary({
    required this.mode,
    required this.distanceKm,
    required this.elevationGainM,
    required this.estimatedTime,
    required this.difficulty,
    required this.osmUrl,
  });

  final TravelMode mode;
  final double distanceKm;
  final double elevationGainM;
  final Duration estimatedTime;
  final Difficulty difficulty;
  final String osmUrl;
}

/// Hiking/biking summary from ordered waypoints: distance, elevation, time,
/// difficulty, and an OpenStreetMap directions link.
class RoutePlanner {
  const RoutePlanner();

  static const _earthRadiusKm = 6371.0;

  RouteSummary plan({
    required TravelMode mode,
    required List<Waypoint> waypoints,
  }) {
    final ordered = [...waypoints]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    var distanceKm = 0.0;
    var elevationGainM = 0.0;
    for (var i = 1; i < ordered.length; i++) {
      distanceKm += _haversineKm(
        ordered[i - 1].lat,
        ordered[i - 1].lng,
        ordered[i].lat,
        ordered[i].lng,
      );
      final delta = ordered[i].elevationM - ordered[i - 1].elevationM;
      if (delta > 0) elevationGainM += delta;
    }

    final estimatedTime = _estimateTime(
      mode: mode,
      distanceKm: distanceKm,
      elevationGainM: elevationGainM,
    );
    final difficulty = classifyDifficulty(
      distanceKm: distanceKm,
      elevationGainM: elevationGainM,
    );
    return RouteSummary(
      mode: mode,
      distanceKm: distanceKm,
      elevationGainM: elevationGainM,
      estimatedTime: estimatedTime,
      difficulty: difficulty,
      osmUrl: osmDirectionsUrl(mode: mode, waypoints: ordered),
    );
  }

  Difficulty classifyDifficulty({
    required double distanceKm,
    required double elevationGainM,
  }) {
    final score = distanceKm + elevationGainM / 100;
    if (score < 6) return Difficulty.easy;
    if (score < 12) return Difficulty.moderate;
    if (score < 22) return Difficulty.hard;
    return Difficulty.expert;
  }

  String osmDirectionsUrl({
    required TravelMode mode,
    required List<Waypoint> waypoints,
  }) {
    if (waypoints.isEmpty) {
      return 'https://www.openstreetmap.org/';
    }
    final engine = mode == TravelMode.bike
        ? 'fossgis_osrm_bike'
        : 'fossgis_osrm_foot';
    final route = waypoints
        .map((w) => '${w.lat.toStringAsFixed(6)},${w.lng.toStringAsFixed(6)}')
        .join(';');
    return 'https://www.openstreetmap.org/directions?engine=$engine&route=$route';
  }

  Duration _estimateTime({
    required TravelMode mode,
    required double distanceKm,
    required double elevationGainM,
  }) {
    // Naismith-inspired: hike 4 km/h + 10 min / 100 m ascent.
    // Bike 15 km/h + 6 min / 100 m ascent.
    final horizontalHours = mode == TravelMode.bike
        ? distanceKm / 15.0
        : distanceKm / 4.0;
    final climbMinutesPer100m = mode == TravelMode.bike ? 6.0 : 10.0;
    final climbHours = (elevationGainM / 100.0) * (climbMinutesPer100m / 60.0);
    final totalMinutes = ((horizontalHours + climbHours) * 60).round();
    return Duration(minutes: math.max(totalMinutes, 0));
  }

  double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  double _rad(double deg) => deg * math.pi / 180.0;
}
