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
    PlaceCategory.castle: ['castle', 'hrad', 'hrady', 'burg', 'burgen'],
    PlaceCategory.chateau: [
      'chateau',
      'zamek',
      'zamky',
      'schloss',
      'schloesser',
    ],
    PlaceCategory.ruin: [
      'ruin',
      'ruins',
      'zricenina',
      'zriceniny',
      'ruine',
      'ruinen',
    ],
    PlaceCategory.church: ['church', 'kostel', 'kostely', 'kirche', 'kirchen'],
    PlaceCategory.other: ['other', 'ostatni', 'sonstiges'],
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
