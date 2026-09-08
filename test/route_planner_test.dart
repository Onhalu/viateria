import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/models/models.dart';

void main() {
  const planner = RoutePlanner();

  final waypoints = [
    const Waypoint(
      id: 'a',
      challengeId: 'c',
      sortOrder: 0,
      lat: 50.0,
      lng: 14.0,
      elevationM: 100,
      translations: [],
    ),
    const Waypoint(
      id: 'b',
      challengeId: 'c',
      sortOrder: 1,
      lat: 50.05,
      lng: 14.05,
      elevationM: 250,
      translations: [],
    ),
  ];

  test('computes distance, elevation, time, difficulty and OSM link', () {
    final hike = planner.plan(mode: TravelMode.hike, waypoints: waypoints);
    expect(hike.distanceKm, greaterThan(5));
    expect(hike.distanceKm, lessThan(10));
    expect(hike.elevationGainM, 150);
    expect(hike.estimatedTime.inMinutes, greaterThan(0));
    expect(hike.osmUrl, contains('openstreetmap.org/directions'));
    expect(hike.osmUrl, contains('fossgis_osrm_foot'));
    expect(hike.osmUrl, contains('50.000000,14.000000;50.050000,14.050000'));

    final bike = planner.plan(mode: TravelMode.bike, waypoints: waypoints);
    expect(bike.estimatedTime < hike.estimatedTime, isTrue);
    expect(bike.osmUrl, contains('fossgis_osrm_bike'));
  });

  test('classifies difficulty from distance and climb', () {
    expect(
      planner.classifyDifficulty(distanceKm: 2, elevationGainM: 50),
      Difficulty.easy,
    );
    expect(
      planner.classifyDifficulty(distanceKm: 8, elevationGainM: 200),
      Difficulty.moderate,
    );
    expect(
      planner.classifyDifficulty(distanceKm: 14, elevationGainM: 400),
      Difficulty.hard,
    );
    expect(
      planner.classifyDifficulty(distanceKm: 30, elevationGainM: 1200),
      Difficulty.expert,
    );
  });
}
