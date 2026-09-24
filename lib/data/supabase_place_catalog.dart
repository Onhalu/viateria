import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../map/place.dart';
import '../map/place_catalog.dart';
import '../map/place_category.dart';

typedef PlacePageQuery = Future<List<dynamic>> Function(
  int offset,
  int pageSize,
);

const _placesPageSize = 1000;

/// Reads the map catalog from `public.places`.
///
/// Rows are paged so a PostgREST max-rows cap cannot silently truncate the
/// catalog. A failed request throws; an empty table returns an empty list.
class SupabasePlaceCatalog implements PlaceCatalog {
  SupabasePlaceCatalog(SupabaseClient client, {this.pageSize = _placesPageSize})
    : _loadPage = ((offset, limit) => _fetchPlacesPage(client, offset, limit));

  @visibleForTesting
  SupabasePlaceCatalog.paging({
    required PlacePageQuery loadPage,
    this.pageSize = _placesPageSize,
    // Public name stays loadPage so tests outside this library can pass it.
    // ignore: prefer_initializing_formals
  }) : _loadPage = loadPage;

  final int pageSize;
  final PlacePageQuery _loadPage;

  @override
  Future<List<Place>> fetchAll() async {
    final byId = <String, Place>{};
    var offset = 0;
    while (true) {
      final rows = await _loadPage(offset, pageSize);
      for (final place in placesFromRows(rows)) {
        byId[place.id] = place;
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return byId.values.toList(growable: false);
  }
}

Future<List<dynamic>> _fetchPlacesPage(
  SupabaseClient client,
  int offset,
  int pageSize,
) async {
  final rows = await client
      .from('places')
      .select('id, name, category, lat, lng, description, elevation_m')
      .order('id')
      .range(offset, offset + pageSize - 1);
  return rows;
}

/// Maps `public.places` rows onto [Place]. Invalid rows are skipped.
List<Place> placesFromRows(List<dynamic> rows) {
  final places = <Place>[];
  for (final row in rows) {
    final place = placeFromRow(row);
    if (place != null) places.add(place);
  }
  return places;
}

@visibleForTesting
Place? placeFromRow(Object? raw) {
  if (raw is! Map) return null;
  final row = Map<String, dynamic>.from(raw);
  final id = row['id']?.toString().trim() ?? '';
  final name = row['name']?.toString().trim() ?? '';
  if (id.isEmpty || name.isEmpty) return null;
  final latitude = optionalPlaceElevation(row['lat']);
  final longitude = optionalPlaceElevation(row['lng']);
  if (latitude == null || longitude == null) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return Place(
    id: id,
    name: name,
    category: PlaceCategory.fromWire(row['category']?.toString() ?? ''),
    location: GeoPoint(latitude, longitude),
    description: optionalPlaceText(row['description']),
    elevationM: optionalPlaceElevation(row['elevation_m']),
  );
}

/// Production catalog: Supabase `public.places`, unless the asset flag is set
/// or Supabase itself is not configured.
PlaceCatalog resolvePlaceCatalog({
  required AppConfig config,
  SupabaseClient? client,
}) {
  if (!config.isSupabaseConfigured) return const UnconfiguredPlaceCatalog();
  if (config.useAssetPlaceCatalog) return const AssetPlaceCatalog();
  final supabase = client;
  if (supabase == null) {
    throw StateError('Supabase client is required for the place catalog');
  }
  return SupabasePlaceCatalog(supabase);
}
