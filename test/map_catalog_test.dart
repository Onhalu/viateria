import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock catalog uses Batch B categories and counts', () async {
    final raw = await rootBundle.loadString('assets/map/pois.geojson');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded['type'], 'FeatureCollection');
    expect(jsonEncode(decoded).contains('inChallenge'), isFalse);
    expect(jsonEncode(decoded).contains('placeState'), isFalse);
    expect(jsonEncode(decoded).contains('"verified"'), isFalse);

    final places = Place.fromFeatureCollection(decoded);
    expect(places, hasLength(167));
    expect(places.map((place) => place.id).toSet(), hasLength(167));

    final counts = <PlaceCategory, int>{
      for (final category in PlaceCategory.values) category: 0,
    };
    for (final place in places) {
      counts[place.category] = counts[place.category]! + 1;
      expect(place.iconName, place.category.name);
    }
    expect(counts[PlaceCategory.city], 12);
    expect(counts[PlaceCategory.nature], 57);
    expect(counts[PlaceCategory.technical], 12);
    expect(counts[PlaceCategory.historical], 86);
    expect(counts.values.reduce((a, b) => a + b), 167);
  });
}
