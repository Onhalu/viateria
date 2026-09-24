import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/supabase_place_catalog.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/map/place_category.dart';

void main() {
  test('placesFromRows maps public.places columns and skips bad rows', () {
    final places = placesFromRows([
      {
        'id': '1fc4d6a6-b30f-4026-97ee-2c6eb52423d6',
        'name': '  Rodrigova skála  ',
        'category': 'nature',
        'lat': 49.6671092,
        'lng': 15.3209444,
        'description': '  Název skály připomíná Foglara.  ',
        'elevation_m': 365,
        'region': 'cz',
        'place_type': 'zajímavost',
      },
      {
        'id': 'f2184dcb-965d-4dc2-a2db-036a04d3beff',
        'name': 'Rozhledna',
        'category': 'unknown-wire',
        'lat': '49.96',
        'lng': 16,
        'description': '   ',
        'elevation_m': null,
        'place_type': 'rohledna',
      },
      {'id': '', 'name': 'Missing id', 'category': 'city', 'lat': 1, 'lng': 2},
      {
        'id': 'bad-coords',
        'name': 'Off the planet',
        'category': 'city',
        'lat': 120,
        'lng': 10,
      },
      'not-a-row',
    ]);

    expect(places, hasLength(2));
    expect(places.first.id, '1fc4d6a6-b30f-4026-97ee-2c6eb52423d6');
    expect(places.first.name, 'Rodrigova skála');
    expect(places.first.category, PlaceCategory.nature);
    expect(places.first.location.latitude, 49.6671092);
    expect(places.first.location.longitude, 15.3209444);
    expect(places.first.description, 'Název skály připomíná Foglara.');
    expect(places.first.elevationM, 365);
    expect(places.first.iconName, 'nature');
    expect(places.last.category, PlaceCategory.historical);
    expect(places.last.iconName, 'historical');
    expect(places.last.description, isNull);
    expect(places.last.elevationM, isNull);
    expect(places.last.location.latitude, 49.96);
  });

  test('icons follow category only, including the historical fallback', () {
    final mismatched = Place.fromFeature({
      'type': 'Feature',
      'properties': {
        'id': 'x',
        'name': 'X',
        'category': 'technical',
        'icon': 'city',
        'place_type': 'hrad',
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [14.0, 50.0],
      },
    });
    expect(mismatched, isNotNull);
    expect(mismatched!.iconName, 'technical');
    expect(mismatched.toFeature()['properties']['icon'], 'technical');

    for (final category in PlaceCategory.values) {
      expect(category.iconName, category.name);
    }
    expect(PlaceCategory.fromWire('').iconName, 'historical');
    expect(PlaceCategory.fromWire('castle').iconName, 'historical');
    expect(optionalPlaceElevation('558'), 558);
    expect(optionalPlaceElevation(double.nan), isNull);
  });

  test('paging stops on a short page and dedupes ids', () async {
    final calls = <int>[];
    final catalog = SupabasePlaceCatalog.paging(
      pageSize: 2,
      loadPage: (offset, pageSize) async {
        expect(pageSize, 2);
        calls.add(offset);
        if (offset == 0) {
          return [
            {
              'id': 'a',
              'name': 'Alpha',
              'category': 'city',
              'lat': 50,
              'lng': 14,
            },
            {
              'id': 'a',
              'name': 'Alpha again',
              'category': 'city',
              'lat': 50,
              'lng': 14,
            },
          ];
        }
        return [
          {
            'id': 'b',
            'name': 'Beta',
            'category': 'technical',
            'lat': 49,
            'lng': 15,
          },
        ];
      },
    );

    final places = await catalog.fetchAll();
    expect(calls, [0, 2]);
    expect(places.map((place) => place.id), ['a', 'b']);
    expect(places.first.name, 'Alpha again');
  });

  test('a failed page surfaces as an error', () async {
    final catalog = SupabasePlaceCatalog.paging(
      loadPage: (offset, pageSize) async {
        throw StateError('offline');
      },
    );
    expect(catalog.fetchAll(), throwsStateError);
  });

  test(
    'resolvePlaceCatalog defaults to Supabase and keeps assets behind a flag',
    () {
      const missing = AppConfig(
        supabaseUrl: '',
        supabaseAnonKey: '',
        stripePublishableKey: '',
      );
      expect(
        resolvePlaceCatalog(config: missing),
        isA<UnconfiguredPlaceCatalog>(),
      );

      const asset = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon',
        stripePublishableKey: '',
        useAssetPlaceCatalog: true,
      );
      expect(resolvePlaceCatalog(config: asset), isA<AssetPlaceCatalog>());

      const live = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon',
        stripePublishableKey: '',
      );
      expect(() => resolvePlaceCatalog(config: live), throwsStateError);
      expect(
        resolvePlaceCatalog(
          config: live,
          client: SupabaseClient('https://example.supabase.co', 'anon'),
        ),
        isA<SupabasePlaceCatalog>(),
      );
    },
  );

  test('migration mirrors public.places without deleting rows', () {
    final sql = File('supabase/migrations/0009_places.sql').readAsStringSync();
    expect(sql, contains('create table if not exists public.places'));
    expect(sql, contains('description text'));
    expect(sql, contains('region text'));
    expect(sql, contains('place_type text'));
    expect(sql, contains('elevation_m double precision'));
    expect(sql, contains('places_category_check'));
    expect(sql, contains("'city', 'nature', 'technical', 'historical'"));
    expect(sql, contains('places_select_public'));
    expect(sql, contains('for select'));
    expect(sql, contains('to anon, authenticated'));
    expect(sql, contains('using (true)'));
    expect(sql, contains('enable row level security'));
    expect(
      sql,
      contains('grant select on table public.places to anon, authenticated'),
    );
    expect(sql.toLowerCase(), isNot(contains('delete from')));
    expect(sql.toLowerCase(), isNot(contains('truncate')));
    expect(sql.toLowerCase(), isNot(contains('drop table')));
  });
}
