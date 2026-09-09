import 'dart:math' as math;

import 'poi.dart';
import 'poi_category.dart';

final _diacritics = <String, String>{
  'á': 'a',
  'č': 'c',
  'ď': 'd',
  'é': 'e',
  'ě': 'e',
  'í': 'i',
  'ň': 'n',
  'ó': 'o',
  'ř': 'r',
  'š': 's',
  'ť': 't',
  'ú': 'u',
  'ů': 'u',
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

List<Poi> applyCategoryFilter(List<Poi> pois, Set<PoiCategory> selected) {
  if (selected.isEmpty || selected.length == PoiCategory.values.length) {
    return List<Poi>.from(pois);
  }
  return pois.where((p) => selected.contains(p.category)).toList();
}

int countInViewport(Iterable<Poi> pois, GeoBounds bounds) {
  var n = 0;
  for (final poi in pois) {
    if (bounds.contains(poi.location)) n++;
  }
  return n;
}

List<Poi> searchPois(List<Poi> pois, String query, {int limit = 20}) {
  final q = foldCzech(query.trim());
  if (q.isEmpty) return const [];
  final hits = <Poi>[];
  for (final poi in pois) {
    if (foldCzech(poi.name).contains(q) || _categoryMatches(poi.category, q)) {
      hits.add(poi);
      if (hits.length >= limit) break;
    }
  }
  return hits;
}

bool _categoryMatches(PoiCategory category, String foldedQuery) {
  if (foldedQuery.length < 3) return false;
  const tokens = <PoiCategory, List<String>>{
    PoiCategory.castle: ['castle', 'hrad', 'hrady'],
    PoiCategory.chateau: ['chateau', 'zamek', 'zamky'],
    PoiCategory.ruin: ['ruin', 'ruins', 'zricenina', 'zriceniny'],
    PoiCategory.church: ['church', 'kostel', 'kostely'],
    PoiCategory.other: ['other', 'ostatni'],
  };
  for (final token in tokens[category] ?? const <String>[]) {
    final folded = foldCzech(token);
    if (folded.contains(foldedQuery) || foldedQuery.contains(folded)) {
      return true;
    }
  }
  return false;
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

List<Poi> sortForList(List<Poi> pois, GeoPoint? userLocation) {
  final copy = List<Poi>.from(pois);
  if (userLocation == null) {
    copy.sort(
      (a, b) => foldCzech(a.name).compareTo(foldCzech(b.name)),
    );
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
