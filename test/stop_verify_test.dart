import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/verified_places.dart';
import 'package:viateria/domain/stop_verify.dart';
import 'package:viateria/map/place.dart';

void main() {
  test('GPS verify radius is 120 m and matches nearby points', () {
    expect(VerifyProximity.radiusMeters, 120);
    const place = GeoPoint(50.08, 14.42);
    expect(
      VerifyProximity.isWithin(
        here: const GeoPoint(50.0805, 14.42),
        target: place,
      ),
      isTrue,
    );
    expect(
      VerifyProximity.isWithin(
        here: const GeoPoint(50.09, 14.43),
        target: place,
      ),
      isFalse,
    );
  });

  test('GPS photo path is user-scoped for the verify_waypoint RPC', () {
    expect(
      VerifyProximity.gpsPhotoPath(
        userId: 'user-1',
        challengeId: 'open-1',
        waypointId: 'ow-1',
      ),
      'user-1/gps/open-1/ow-1',
    );
  });

  test('verified place ids persist', () async {
    SharedPreferences.setMockInitialValues({});
    final store = VerifiedPlacesStore();
    await store.add('karlstejn');
    expect(store.contains('karlstejn'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(VerifiedPlacesStore.prefsKey), ['karlstejn']);

    final reloaded = VerifiedPlacesStore();
    await reloaded.load();
    expect(reloaded.contains('karlstejn'), isTrue);
  });
}
