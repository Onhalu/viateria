import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/data/challenge_mapping.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/models/models.dart';

void main() {
  test('waypointFromRow maps category onto the waypoint', () {
    final waypoint = waypointFromRow({
      'id': 'w1',
      'challenge_id': 'c1',
      'sort_order': 2,
      'lat': 49.67,
      'lng': 16.03,
      'elevation_m': 800,
      'category': 'nature',
      'waypoint_i18n': [
        {'locale': 'cs', 'title': 'Devět skal', 'description': ''},
      ],
    });

    expect(waypoint.category, PlaceCategory.nature);
    expect(
      'assets/map/icons/${waypoint.category.iconName}@2x.png',
      'assets/map/icons/nature@2x.png',
    );
  });

  test('missing or unknown category falls back to historical', () {
    Waypoint row(String? category) {
      return waypointFromRow({
        'id': 'w1',
        'challenge_id': 'c1',
        'sort_order': 0,
        'lat': 50,
        'lng': 14,
        'category': ?category,
      });
    }

    expect(row(null).category, PlaceCategory.historical);
    expect(row('castle').category, PlaceCategory.historical);
    expect(row('city').category, PlaceCategory.city);
    expect(row('technical').category, PlaceCategory.technical);
  });
}
