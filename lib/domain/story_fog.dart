import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import 'unlock_rules.dart';

/// Minimum distance from a locked-stop `?` to any real stop.
///
/// SPEC default is a fog cluster, not a ±200 m jitter around the true point.
const storyFogMinSeparationMeters = 2000.0;

/// `?` drawn for one locked story waypoint. [position] is never that stop's
/// true latitude/longitude.
class StoryFogPin {
  const StoryFogPin({required this.waypointId, required this.position});

  final String waypointId;
  final LatLng position;
}

/// Waypoints whose true coordinates must stay off the map and out of the planner.
Set<String> storyHiddenWaypointIds({
  required AccessMode mode,
  required bool hasAccess,
  required List<Waypoint> ordered,
  required Set<String> completedIds,
  UnlockRules rules = const UnlockRules(),
}) {
  if (mode != AccessMode.story) return const {};
  final completedIndexes = <int>{
    for (var i = 0; i < ordered.length; i++)
      if (completedIds.contains(ordered[i].id)) i,
  };
  return {
    for (var i = 0; i < ordered.length; i++)
      if (!rules.isWaypointUnlocked(
        mode: mode,
        hasAccess: hasAccess,
        waypointIndex: i,
        completedIndexes: completedIndexes,
      ))
        ordered[i].id,
  };
}

/// Deterministic fog cluster inside the challenge field.
///
/// Pins sit on a ring around the centroid of every stop, at least
/// [storyFogMinSeparationMeters] from each true coordinate. The angle is
/// keyed by sort order so unlocking one stop does not slide the others.
/// A north-of-bbox fallback covers a tight cluster where the ring would
/// still land on a real stop.
List<StoryFogPin> storyFogPins({
  required List<Waypoint> ordered,
  required Set<String> hiddenIds,
}) {
  if (hiddenIds.isEmpty || ordered.isEmpty) return const [];
  final truths = [for (final waypoint in ordered) waypoint.latLng];
  final centroid = _centroid(truths);
  final placed = <LatLng>[];
  final pins = <StoryFogPin>[];
  for (var i = 0; i < ordered.length; i++) {
    final waypoint = ordered[i];
    if (!hiddenIds.contains(waypoint.id)) continue;
    final position = _fogPosition(
      sortIndex: i,
      centroid: centroid,
      truths: truths,
      already: placed,
    );
    placed.add(position);
    pins.add(StoryFogPin(waypointId: waypoint.id, position: position));
  }
  return pins;
}

/// Camera / fit anchors: revealed true coordinates plus fog pins.
///
/// Locked true coordinates are omitted so the camera never frames them.
List<LatLng> storyMapAnchors({
  required List<Waypoint> ordered,
  required Set<String> hiddenIds,
  required List<StoryFogPin> fog,
}) {
  return [
    for (final waypoint in ordered)
      if (!hiddenIds.contains(waypoint.id)) waypoint.latLng,
    for (final pin in fog) pin.position,
  ];
}

/// True when both pin lists name the same stops at the same offsets.
bool sameStoryFog(List<StoryFogPin> a, List<StoryFogPin> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].waypointId != b[i].waypointId) return false;
    if (a[i].position.latitude != b[i].position.latitude) return false;
    if (a[i].position.longitude != b[i].position.longitude) return false;
  }
  return true;
}

/// Great-circle distance in meters.
double metersBetween(LatLng a, LatLng b) {
  const earth = 6371000.0;
  final phi1 = a.latitude * math.pi / 180;
  final phi2 = b.latitude * math.pi / 180;
  final dPhi = (b.latitude - a.latitude) * math.pi / 180;
  final dLambda = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return 2 * earth * math.asin(math.min(1, math.sqrt(h)));
}

LatLng _centroid(List<LatLng> points) {
  var lat = 0.0;
  var lng = 0.0;
  for (final point in points) {
    lat += point.latitude;
    lng += point.longitude;
  }
  final n = points.length;
  return LatLng(lat / n, lng / n);
}

LatLng _fogPosition({
  required int sortIndex,
  required LatLng centroid,
  required List<LatLng> truths,
  required List<LatLng> already,
}) {
  const golden = 2.399963229728653;
  var bearing = golden * (sortIndex + 1);
  var distance = 2500.0 + sortIndex * 900.0;
  for (var attempt = 0; attempt < 36; attempt++) {
    final candidate = _offset(centroid, bearing, distance);
    if (_clear(candidate, truths, storyFogMinSeparationMeters) &&
        _clear(candidate, already, 800)) {
      return candidate;
    }
    bearing += 0.55;
    distance += 700;
  }
  var north = truths.first;
  for (final point in truths) {
    if (point.latitude > north.latitude) north = point;
  }
  var fallback = _offset(north, 0, 3000 + sortIndex * 1200);
  var extra = 0;
  while (!_clear(fallback, truths, storyFogMinSeparationMeters) && extra < 8) {
    extra += 1;
    fallback = _offset(
      north,
      0.4 * extra,
      3000 + sortIndex * 1200 + extra * 1000,
    );
  }
  return fallback;
}

bool _clear(LatLng candidate, List<LatLng> others, double minMeters) {
  for (final other in others) {
    if (metersBetween(candidate, other) < minMeters) return false;
  }
  return true;
}

/// [bearingRad] 0 is north, clockwise.
LatLng _offset(LatLng origin, double bearingRad, double distanceMeters) {
  const earth = 6371000.0;
  final angular = distanceMeters / earth;
  final lat1 = origin.latitude * math.pi / 180;
  final lng1 = origin.longitude * math.pi / 180;
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(angular) +
        math.cos(lat1) * math.sin(angular) * math.cos(bearingRad),
  );
  final lng2 =
      lng1 +
      math.atan2(
        math.sin(bearingRad) * math.sin(angular) * math.cos(lat1),
        math.cos(angular) - math.sin(lat1) * math.sin(lat2),
      );
  return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
}
