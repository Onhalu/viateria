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

    expect(placeIdsInChallenge(places, waypointIds: const ['karlstejn']), {
      'karlstejn',
    });

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

  test('dedupe keeps one place; challenge membership wins', () {
    const nearby = Place(
      id: 'karlstejn-dup',
      name: 'Near Karlštejn',
      category: PlaceCategory.historical,
      location: GeoPoint(49.9395, 14.1880),
    );
    final sameId = [
      ...places,
      const Place(
        id: 'karlstejn',
        name: 'Karlštejn copy',
        category: PlaceCategory.historical,
        location: GeoPoint(49.9394, 14.1880),
      ),
    ];
    expect(
      dedupePlaces(sameId).where((p) => p.id == 'karlstejn'),
      hasLength(1),
    );

    final overlapped = [...places, nearby];
    final kept = dedupePlaces(
      overlapped,
      challengePlaceIds: const {'karlstejn'},
    );
    expect(kept.map((p) => p.id), contains('karlstejn'));
    expect(kept.map((p) => p.id), isNot(contains('karlstejn-dup')));
    expect(kept, hasLength(3));

    final challengeWins = dedupePlaces(
      overlapped,
      challengePlaceIds: const {'karlstejn-dup'},
    );
    expect(challengeWins.map((p) => p.id), contains('karlstejn-dup'));
    expect(challengeWins.map((p) => p.id), isNot(contains('karlstejn')));
  });

  test('placesOfChallenge returns only matching catalog stops', () {
    expect(
      placesOfChallenge(
        places,
        waypointIds: const ['missing'],
        waypointLocations: const [GeoPoint(0, 0)],
      ),
      isEmpty,
    );
    expect(
      placesOfChallenge(
        places,
        waypointIds: const ['karlstejn'],
      ).map((p) => p.id),
      ['karlstejn'],
    );
  });

  test('challenge-only filter keeps membership after categories', () {
    expect(
      applyChallengeOnlyFilter(places, {
        'karlstejn',
      }, enabled: false).map((p) => p.id),
      ['karlstejn', 'staromestske', 'pravcicka'],
    );
    expect(
      applyChallengeOnlyFilter(places, {
        'karlstejn',
      }, enabled: true).map((p) => p.id),
      ['karlstejn'],
    );
    expect(applyChallengeOnlyFilter(places, {}, enabled: true), isEmpty);

    final cityOnly = applyPlaceFilters(
      places,
      categories: {PlaceCategory.city},
      challengeOnly: true,
      challengePlaceIds: {'karlstejn'},
    );
    expect(cityOnly, isEmpty);

    final historicalChallenge = applyPlaceFilters(
      places,
      categories: {PlaceCategory.historical},
      challengeOnly: true,
      challengePlaceIds: {'karlstejn'},
    );
    expect(historicalChallenge.map((p) => p.id), ['karlstejn']);
  });

  test('search hits honor challenge-only filter', () {
    final filtered = applyChallengeOnlyFilter(places, {
      'karlstejn',
    }, enabled: true);
    expect(searchPlaces(filtered, 'Karl').single.id, 'karlstejn');
    expect(searchPlaces(filtered, 'Starom'), isEmpty);
  });
}
