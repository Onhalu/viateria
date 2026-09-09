import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/core/l10n/map_strings.dart';
import 'package:viateria/features/map/domain/poi.dart';
import 'package:viateria/features/map/domain/poi_category.dart';
import 'package:viateria/features/map/domain/poi_query.dart';

import 'helpers/map_harness.dart';

void main() {
  final pois = samplePois();

  test('category filter changes viewport count', () {
    const bounds = GeoBounds.czechRepublic;
    expect(countInViewport(pois, bounds), 3);

    final withoutCastles = applyCategoryFilter(pois, {
      PoiCategory.chateau,
      PoiCategory.ruin,
      PoiCategory.church,
      PoiCategory.other,
    });
    expect(withoutCastles.map((p) => p.id), ['lednice', 'trosky']);
    expect(countInViewport(withoutCastles, bounds), 2);

    final empty = applyCategoryFilter(pois, {PoiCategory.church});
    expect(countInViewport(empty, bounds), 0);
  });

  test('empty or full filter set keeps every POI', () {
    expect(applyCategoryFilter(pois, {}), pois);
    expect(
      applyCategoryFilter(pois, Set<PoiCategory>.from(PoiCategory.values)),
      pois,
    );
  });

  test('search is catalog-only, diacritics-insensitive, capped at 20', () {
    expect(searchPois(pois, 'hrad').map((p) => p.id), ['karlstejn']);
    expect(searchPois(pois, 'KARL').single.name, 'Karlštejn');
    expect(searchPois(pois, 'xyz'), isEmpty);

    final many = [
      for (var i = 0; i < 30; i++)
        Poi(
          id: 'p$i',
          name: 'Hrad $i',
          category: PoiCategory.castle,
          location: const GeoPoint(50, 14),
        ),
    ];
    expect(searchPois(many, 'hrad', limit: 20), hasLength(20));
  });

  test('Czech památka pluralization', () {
    expect(MapStrings.pamatkaPlural(0), 'památek');
    expect(MapStrings.pamatkaPlural(1), 'památka');
    expect(MapStrings.pamatkaPlural(2), 'památky');
    expect(MapStrings.pamatkaPlural(4), 'památky');
    expect(MapStrings.pamatkaPlural(5), 'památek');
    expect(MapStrings.pamatkaPlural(105), 'památek');
    expect(MapStrings('cs').poiCount(105), '105 památek');
  });

  test('list sorts by distance when GPS is known, otherwise alpha', () {
    const prague = GeoPoint(50.08, 14.42);
    final byDistance = sortForList(pois, prague);
    expect(byDistance.first.id, 'karlstejn');

    final alpha = sortForList(pois, null).map((p) => p.id).toList();
    expect(alpha, ['karlstejn', 'lednice', 'trosky']);
  });
}
