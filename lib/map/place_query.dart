import 'dart:math' as math;

import 'place.dart';
import 'place_category.dart';

final _diacritics = <String, String>{
  'á': 'a',
  'ä': 'a',
  'č': 'c',
  'ď': 'd',
  'é': 'e',
  'ě': 'e',
  'í': 'i',
  'ň': 'n',
  'ó': 'o',
  'ö': 'o',
  'ř': 'r',
  'š': 's',
  'ť': 't',
  'ú': 'u',
  'ů': 'u',
  'ü': 'u',
  'ý': 'y',
  'ž': 'z',
};

String foldCzech(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_diacritics[ch] ?? ch);
  }
  return buffer.toString();
}

List<Place> applyCategoryFilter(
  List<Place> places,
  Set<PlaceCategory> selected,
) {
  if (selected.isEmpty || selected.length == PlaceCategory.values.length) {
    return List<Place>.from(places);
  }
  return places.where((p) => selected.contains(p.category)).toList();
}

int countInViewport(Iterable<Place> places, GeoBounds bounds) {
  var n = 0;
  for (final place in places) {
    if (bounds.contains(place.location)) n++;
  }
  return n;
}

List<Place> searchPlaces(List<Place> places, String query, {int limit = 20}) {
  final q = foldCzech(query.trim());
  if (q.isEmpty) return const [];
  final hits = <Place>[];
  for (final place in places) {
    if (foldCzech(place.name).contains(q) ||
        _categoryMatches(place.category, q)) {
      hits.add(place);
      if (hits.length >= limit) break;
    }
  }
  return hits;
}

bool _categoryMatches(PlaceCategory category, String foldedQuery) {
  if (foldedQuery.length < 3) return false;
  const tokens = <PlaceCategory, List<String>>{
    PlaceCategory.city: ['city', 'mesto', 'stadt', 'namesti'],
    PlaceCategory.nature: ['nature', 'prirodni', 'natur', 'skaly', 'skala'],
    PlaceCategory.technical: [
      'technical',
      'technicka',
      'technisch',
      'industrie',
    ],
    PlaceCategory.historical: [
      'historical',
      'historicka',
      'historisch',
      'hrad',
      'zamek',
      'castle',
      'chateau',
    ],
  };
  for (final token in tokens[category] ?? const <String>[]) {
    final folded = foldCzech(token);
    if (folded.contains(foldedQuery) || foldedQuery.contains(folded)) {
      return true;
    }
  }
  return false;
}

/// Places that belong to the current challenge: matching waypoint id, or
/// within [radiusKm] of a waypoint. Empty inputs → no matches (sage tint).
Set<String> placeIdsInChallenge(
  Iterable<Place> places, {
  Iterable<String> waypointIds = const [],
  Iterable<GeoPoint> waypointLocations = const [],
  double radiusKm = 0.2,
}) {
  final ids = waypointIds.toSet();
  final points = waypointLocations.toList(growable: false);
  if (ids.isEmpty && points.isEmpty) return const {};
  final matched = <String>{};
  for (final place in places) {
    if (ids.contains(place.id)) {
      matched.add(place.id);
      continue;
    }
    for (final point in points) {
      if (distanceKm(place.location, point) <= radiusKm) {
        matched.add(place.id);
        break;
      }
    }
  }
  return matched;
}

/// One place = one marker. Same id or within [radiusKm] collapses to a
/// single row. Challenge membership (inChallenge / verified) wins.
List<Place> dedupePlaces(
  Iterable<Place> places, {
  Set<String> challengePlaceIds = const {},
  Set<String> verifiedPlaceIds = const {},
  double radiusKm = 0.2,
}) {
  int rank(Place place) {
    var value = 0;
    if (verifiedPlaceIds.contains(place.id)) value += 2;
    if (challengePlaceIds.contains(place.id)) value += 1;
    return value;
  }

  final byId = <String, Place>{};
  for (final place in places) {
    final existing = byId[place.id];
    if (existing == null || rank(place) > rank(existing)) {
      byId[place.id] = place;
    }
  }
  final unique = byId.values.toList();
  final kept = <Place>[];
  final used = <int>{};
  for (var i = 0; i < unique.length; i++) {
    if (used.contains(i)) continue;
    var best = unique[i];
    var bestRank = rank(best);
    for (var j = i + 1; j < unique.length; j++) {
      if (used.contains(j)) continue;
      if (distanceKm(unique[i].location, unique[j].location) > radiusKm) {
        continue;
      }
      used.add(j);
      final nextRank = rank(unique[j]);
      if (nextRank > bestRank) {
        best = unique[j];
        bestRank = nextRank;
      }
    }
    kept.add(best);
  }
  return kept;
}

/// Catalog places that belong to a challenge, already de-duplicated.
List<Place> placesOfChallenge(
  Iterable<Place> places, {
  Iterable<String> waypointIds = const [],
  Iterable<GeoPoint> waypointLocations = const [],
  Set<String> verifiedPlaceIds = const {},
  double radiusKm = 0.2,
}) {
  final challengeIds = placeIdsInChallenge(
    places,
    waypointIds: waypointIds,
    waypointLocations: waypointLocations,
    radiusKm: radiusKm,
  );
  if (challengeIds.isEmpty) return const [];
  return dedupePlaces(
    [
      for (final place in places)
        if (challengeIds.contains(place.id)) place,
    ],
    challengePlaceIds: challengeIds,
    verifiedPlaceIds: verifiedPlaceIds,
    radiusKm: radiusKm,
  );
}

double distanceKm(GeoPoint a, GeoPoint b) {
  const earth = 6371.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * earth * math.asin(math.sqrt(h));
}

double _rad(double deg) => deg * math.pi / 180;

List<Place> sortForList(List<Place> places, GeoPoint? userLocation) {
  final copy = List<Place>.from(places);
  if (userLocation == null) {
    copy.sort((a, b) => foldCzech(a.name).compareTo(foldCzech(b.name)));
    return copy;
  }
  copy.sort((a, b) {
    final da = distanceKm(userLocation, a.location);
    final db = distanceKm(userLocation, b.location);
    final cmp = da.compareTo(db);
    if (cmp != 0) return cmp;
    return foldCzech(a.name).compareTo(foldCzech(b.name));
  });
  return copy;
}

Map<String, dynamic> featureCollectionOf(
  Iterable<Place> places, {
  String? selectedId,
  Set<String> challengePlaceIds = const {},
  Set<String> verifiedPlaceIds = const {},
}) {
  final input = places.toList();
  Place? selected;
  if (selectedId != null) {
    for (final place in input) {
      if (place.id == selectedId) {
        selected = place;
        break;
      }
    }
  }
  final unique = dedupePlaces(
    input,
    challengePlaceIds: challengePlaceIds,
    verifiedPlaceIds: verifiedPlaceIds,
  );
  bool isSelected(Place place) {
    if (selected == null) return false;
    if (place.id == selected.id) return true;
    return distanceKm(place.location, selected.location) <= 0.2;
  }

  return {
    'type': 'FeatureCollection',
    'features': [
      for (final place in unique)
        place.toFeature(
          selected: isSelected(place),
          inChallenge: challengePlaceIds.contains(place.id),
          verified: verifiedPlaceIds.contains(place.id),
        ),
    ],
  };
}
