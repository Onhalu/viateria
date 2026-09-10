import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';

List<Place> samplePlaces() => const [
  Place(
    id: 'karlstejn',
    name: 'Karlštejn',
    category: PlaceCategory.historical,
    location: GeoPoint(49.9394, 14.1880),
  ),
  Place(
    id: 'staromestske',
    name: 'Staroměstské náměstí',
    category: PlaceCategory.city,
    location: GeoPoint(50.0875, 14.4211),
  ),
  Place(
    id: 'pravcicka',
    name: 'Pravčická brána',
    category: PlaceCategory.nature,
    location: GeoPoint(50.8836, 14.2814),
  ),
];
