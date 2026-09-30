import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/challenge_mapping.dart';
import 'package:viateria/data/supabase_repositories.dart';
import 'package:viateria/domain/catalog_query.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/map/place_query.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/verify_waypoint_screen.dart';
import 'package:viateria/ui/widgets/places_map_host.dart';

void main() {
  test('0013 adds nullable place_id and backfills within 50 m', () {
    final sql = File(
      'supabase/migrations/0013_waypoints_place_id_nullable_backfill.sql',
    ).readAsStringSync();
    final lower = sql.toLowerCase();
    expect(lower, contains('add column if not exists place_id uuid'));
    expect(lower, contains('waypoints_place_id_fkey'));
    expect(lower, contains('references public.places (id)'));
    expect(lower, contains('6371000.0'));
    expect(lower, contains('<= 50'));
    expect(lower, contains('where w2.place_id is null'));
    expect(lower, contains('and w.place_id is null'));
    expect(lower, contains('95f6584b-45be-4b57-9af8-12a10b2a2a2d'));
    expect(lower, isNot(contains('alter column place_id set not null')));
    expect(lower, isNot(contains('service_role')));
    expect(sql, contains('Poutní kostel sv. Jana Nepomuckého na Zelené Hoře'));
  });

  test('0014 requires place_id and records that id on verify', () {
    final sql = File(
      'supabase/migrations/0014_waypoints_place_id_required_verify.sql',
    ).readAsStringSync();
    final lower = sql.toLowerCase();
    expect(lower, contains('unmatched published = 0'));
    expect(lower, contains('95f6584b-45be-4b57-9af8-12a10b2a2a2d'));
    expect(lower, contains('alter column place_id set not null'));
    expect(lower, contains('waypoints_challenge_place_uidx'));
    expect(lower, contains('on public.waypoints (challenge_id, place_id)'));
    expect(lower, contains("values (uid, wp.place_id, 'verify')"));
    expect(lower, contains('on conflict (user_id, place_id) do nothing'));
    expect(lower, isNot(contains('6371000')));
    expect(lower, isNot(contains('lateral')));
    expect(lower, isNot(contains('service_role')));
    expect(sql, contains('Poutní kostel sv. Jana Nepomuckého na Zelené Hoře'));
  });

  test('joined place supplies place_id and list coordinates', () {
    final start = waypointFromRow({
      'id': 'w0',
      'challenge_id': 'c1',
      'sort_order': 0,
      'lat': 50.0,
      'lng': 14.0,
      'elevation_m': 10,
      'place_id': '11111111-1111-4111-8111-111111111111',
      'places': {
        'id': '11111111-1111-4111-8111-111111111111',
        'lat': 49.58,
        'lng': 15.94,
        'elevation_m': 555,
      },
    });
    final next = waypointFromRow({
      'id': 'w1',
      'challenge_id': 'c1',
      'sort_order': 1,
      'lat': 50.0,
      'lng': 14.0,
      'elevation_m': 10,
      'place_id': '22222222-2222-4222-8222-222222222222',
      'places': {
        'id': '22222222-2222-4222-8222-222222222222',
        'lat': 50.58,
        'lng': 15.94,
      },
    });

    expect(start.placeId, '11111111-1111-4111-8111-111111111111');
    expect(start.lat, 49.58);
    expect(start.lng, 15.94);
    expect(start.elevationM, 555);
    expect(next.lat, 50.58);
    expect(next.elevationM, 10);

    final stats = catalogRouteStatsFromWaypoints([start, next]);
    expect(stats?.distanceKm, greaterThan(100));
    expect(RouteEndpoint.fromWaypoint(start, 'cs').lat, 49.58);

    final stored = waypointFromRow({
      'id': 'w2',
      'challenge_id': 'c1',
      'sort_order': 2,
      'lat': 48.1,
      'lng': 17.2,
      'places': null,
    });
    expect(stored.placeId, isNull);
    expect(stored.lat, 48.1);
    expect(stored.lng, 17.2);
    expect(
      publishedChallengeDetailSelect,
      contains('places!waypoints_place_id_fkey(id, lat, lng, elevation_m)'),
    );
  });

  test('map tint and verify persist the linked place, not a neighbor', () {
    const linked = Place(
      id: 'church',
      name: 'Zelená Hora',
      category: PlaceCategory.historical,
      location: GeoPoint(49.58, 15.94),
    );
    const neighbor = Place(
      id: 'nearby',
      name: 'Nearby',
      category: PlaceCategory.historical,
      location: GeoPoint(49.5801, 15.9401),
    );
    final places = [linked, neighbor];

    expect(placeIdsInChallenge(places, placeIds: const ['church']), {'church'});
    expect(
      placesOfChallenge(places, placeIds: const ['church']).map((p) => p.id),
      ['church'],
    );

    const geometry = ChallengeMapGeometry(
      waypoints: [
        Waypoint(
          id: '95f6584b-45be-4b57-9af8-12a10b2a2a2d',
          challengeId: 'vyzva-zdarma',
          sortOrder: 0,
          lat: 49.5801,
          lng: 15.9401,
          elevationM: 0,
          placeId: 'church',
          translations: [],
        ),
      ],
    );
    expect(geometry.waypointMatching(linked)?.id, startsWith('95f6584b'));
    expect(geometry.waypointMatching(neighbor), isNull);

    expect(
      placeIdsPersistedForVerify(
        shownPlaceId: 'nearby',
        waypointPlaceId: 'church',
      ),
      {'nearby', 'church'},
    );
    expect(placeIdsPersistedForVerify(waypointPlaceId: '  church  '), {
      'church',
    });
    expect(placeIdsPersistedForVerify(), isEmpty);
  });

  test('release refuses the asset place catalog', () {
    expect(
      () => refuseAssetPlaceCatalogInRelease(
        releaseMode: true,
        useAssetPlaceCatalog: true,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('public.places'),
        ),
      ),
    );
    refuseAssetPlaceCatalogInRelease(
      releaseMode: false,
      useAssetPlaceCatalog: true,
    );
    refuseAssetPlaceCatalogInRelease(
      releaseMode: true,
      useAssetPlaceCatalog: false,
    );

    final resolver = File('lib/data/supabase_place_catalog.dart')
        .readAsStringSync();
    expect(resolver, contains('kReleaseMode'));
    expect(resolver, contains('refuseAssetPlaceCatalogInRelease'));
    expect(resolver, isNot(contains('service_role')));
    final config = File('lib/config/app_config.dart').readAsStringSync();
    expect(config, contains('kReleaseMode'));
    expect(config, contains('refuseAssetPlaceCatalogInRelease'));
  });
}
