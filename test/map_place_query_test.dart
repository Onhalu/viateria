import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/map/place_query.dart';

import 'helpers/map_harness.dart';

void main() {
  final places = samplePlaces();

  test('category filter changes viewport count', () {
    const bounds = GeoBounds.czechRepublic;
    expect(countInViewport(places, bounds), 3);

    final withoutHistorical = applyCategoryFilter(places, {
      PlaceCategory.city,
      PlaceCategory.nature,
      PlaceCategory.technical,
    });
    expect(withoutHistorical.map((p) => p.id), ['staromestske', 'pravcicka']);
    expect(countInViewport(withoutHistorical, bounds), 2);

    final empty = applyCategoryFilter(places, {PlaceCategory.technical});
    expect(countInViewport(empty, bounds), 0);
  });

  test('empty or full filter set keeps every place', () {
    expect(applyCategoryFilter(places, {}), places);
    expect(
      applyCategoryFilter(
        places,
        Set<PlaceCategory>.from(PlaceCategory.values),
      ),
      places,
    );
  });

  test('search is catalog-only, diacritics-insensitive, capped at 20', () {
    expect(searchPlaces(places, 'hrad').map((p) => p.id), ['karlstejn']);
    expect(searchPlaces(places, 'KARL').single.name, 'Karlštejn');
    expect(searchPlaces(places, 'xyz'), isEmpty);

    final many = [
      for (var i = 0; i < 30; i++)
        Place(
          id: 'p$i',
          name: 'Hrad $i',
          category: PlaceCategory.historical,
          location: const GeoPoint(50, 14),
        ),
    ];
    expect(searchPlaces(many, 'hrad', limit: 20), hasLength(20));
  });

  test('legacy wire categories map to historical', () {
    expect(PlaceCategory.fromWire('castle'), PlaceCategory.historical);
    expect(PlaceCategory.fromWire('chateau'), PlaceCategory.historical);
    expect(PlaceCategory.fromWire('ruin'), PlaceCategory.historical);
    expect(PlaceCategory.fromWire('church'), PlaceCategory.historical);
    expect(PlaceCategory.fromWire('other'), PlaceCategory.historical);
    expect(PlaceCategory.fromWire('city'), PlaceCategory.city);
  });

  test('Czech památka pluralization', () {
    expect(AppStrings('cs').monumentNoun(0), 'památek');
    expect(AppStrings('cs').monumentNoun(1), 'památka');
    expect(AppStrings('cs').monumentNoun(2), 'památky');
    expect(AppStrings('cs').monumentNoun(4), 'památky');
    expect(AppStrings('cs').monumentNoun(5), 'památek');
    expect(AppStrings('cs').monumentNoun(105), 'památek');
    expect(AppStrings('cs').monumentCount(105), '105 památek');
  });

  test('list sorts by distance when GPS is known, otherwise alpha', () {
    const prague = GeoPoint(50.08, 14.42);
    final byDistance = sortForList(places, prague);
    expect(byDistance.first.id, 'staromestske');

    final alpha = sortForList(places, null).map((p) => p.id).toList();
    expect(alpha, ['karlstejn', 'pravcicka', 'staromestske']);
  });

  test('challenge membership matches waypoint id or nearby coordinates', () {
    expect(placeIdsInChallenge(places), isEmpty);

    expect(
      placeIdsInChallenge(places, waypointIds: const ['karlstejn']),
      {'karlstejn'},
    );

    expect(
      placeIdsInChallenge(
        places,
        waypointLocations: const [GeoPoint(50.0875, 14.4211)],
      ),
      {'staromestske'},
    );

    expect(
      placeIdsInChallenge(
        places,
        waypointLocations: const [GeoPoint(50.0, 14.0)],
      ),
      isEmpty,
    );
  });
}
