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
  });

  final String id;
  final String name;
  final PlaceCategory category;
  final GeoPoint location;

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

/// Tint state: verified > inChallenge > outside.
String placeStateOf({required bool inChallenge, required bool verified}) {
  if (verified) return 'verified';
  if (inChallenge) return 'inChallenge';
  return 'outside';
}
