import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';

List<Place> samplePlaces() => const [
  Place(
    id: 'karlstejn',
    name: 'Karlštejn',
    category: PlaceCategory.castle,
    location: GeoPoint(49.9394, 14.1880),
  ),
  Place(
    id: 'lednice',
    name: 'Lednice',
    category: PlaceCategory.chateau,
    location: GeoPoint(48.8020, 16.8056),
  ),
  Place(
    id: 'trosky',
    name: 'Trosky',
    category: PlaceCategory.ruin,
    location: GeoPoint(50.5233, 15.2317),
  ),
];
