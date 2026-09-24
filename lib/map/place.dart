import 'place_category.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(GeoPoint point) {
    return point.latitude >= south &&
        point.latitude <= north &&
        point.longitude >= west &&
        point.longitude <= east;
  }

  /// Approximate Czech Republic bounds — used before the first camera idle.
  static const czechRepublic = GeoBounds(
    south: 48.55,
    west: 12.09,
    north: 51.06,
    east: 18.86,
  );
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    this.description,
    this.elevationM,
  });

  final String id;
  final String name;
  final PlaceCategory category;
  final GeoPoint location;

  /// `public.places.description`. Null when the column is null or blank.
  final String? description;

  /// `public.places.elevation_m` in metres. Null when the column is null.
  final double? elevationM;

  /// Marker and list icon. Always [PlaceCategory.iconName] for [category].
  String get iconName => category.iconName;

  Map<String, dynamic> toFeature({
    bool selected = false,
    bool inChallenge = false,
    bool verified = false,
  }) {
    return {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': [location.longitude, location.latitude],
      },
      'properties': {
        'id': id,
        'name': name,
        'category': category.name,
        'icon': iconName,
        'selected': selected ? 1 : 0,
        'inChallenge': inChallenge ? 1 : 0,
        'verified': verified ? 1 : 0,
        'placeState': placeStateOf(
          inChallenge: inChallenge,
          verified: verified,
        ),
      },
    };
  }

  static Place? fromFeature(Map<String, dynamic> feature) {
    final props = feature['properties'];
    if (props is! Map) return null;
    final geometry = feature['geometry'];
    if (geometry is! Map) return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final id = props['id']?.toString();
    final name = props['name']?.toString();
    if (id == null || name == null || id.isEmpty || name.isEmpty) return null;
    return Place(
      id: id,
      name: name,
      category: PlaceCategory.fromWire(
        props['category']?.toString() ?? 'historical',
      ),
      location: GeoPoint(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
      description: optionalPlaceText(props['description']),
      elevationM: optionalPlaceElevation(props['elevation_m']),
    );
  }

  static List<Place> fromFeatureCollection(Map<String, dynamic> collection) {
    final features = collection['features'];
    if (features is! List) return const [];
    final places = <Place>[];
    for (final raw in features) {
      if (raw is! Map) continue;
      final place = fromFeature(Map<String, dynamic>.from(raw));
      if (place != null) places.add(place);
    }
    return places;
  }
}

/// Blank descriptions are treated as missing.
String? optionalPlaceText(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return text;
}

/// Finite metres, or null when the value is missing or not a number.
double? optionalPlaceElevation(Object? value) {
  final parsed = switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
  return parsed;
}

/// Tint state: verified > inChallenge > outside.
String placeStateOf({required bool inChallenge, required bool verified}) {
  if (verified) return 'verified';
  if (inChallenge) return 'inChallenge';
  return 'outside';
}
