import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock catalog uses Batch B categories and counts', () async {
    final raw = await rootBundle.loadString('assets/map/pois.geojson');
    final places = Place.fromFeatureCollection(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    expect(places, hasLength(105));

    final counts = <PlaceCategory, int>{
      for (final category in PlaceCategory.values) category: 0,
    };
    for (final place in places) {
      counts[place.category] = counts[place.category]! + 1;
    }
    expect(counts[PlaceCategory.city], inInclusiveRange(8, 15));
    expect(counts[PlaceCategory.nature], inInclusiveRange(8, 15));
    expect(counts[PlaceCategory.technical], inInclusiveRange(8, 15));
    expect(
      counts[PlaceCategory.historical],
      105 -
          counts[PlaceCategory.city]! -
          counts[PlaceCategory.nature]! -
          counts[PlaceCategory.technical]!,
    );
    expect(
      places.every((place) => PlaceCategory.values.contains(place.category)),
      isTrue,
    );
  });
}
