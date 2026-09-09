import 'package:geolocator/geolocator.dart';

import '../domain/poi.dart';

enum LocateOutcome { granted, denied, disabled }

class LocateResult {
  const LocateResult._(this.outcome, this.position);

  const LocateResult.granted(GeoPoint position)
    : this._(LocateOutcome.granted, position);
  const LocateResult.denied() : this._(LocateOutcome.denied, null);
  const LocateResult.disabled() : this._(LocateOutcome.disabled, null);

  final LocateOutcome outcome;
  final GeoPoint? position;
}

/// Device location only. Never sent to a backend.
abstract class LocationService {
  Future<LocateResult> locate();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocateResult> locate() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return const LocateResult.disabled();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocateResult.denied();
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    // Location stays on-device: we only return it to the map camera.
    return LocateResult.granted(GeoPoint(pos.latitude, pos.longitude));
  }
}

class MemoryLocationService implements LocationService {
  MemoryLocationService({this.result = const LocateResult.denied()});

  LocateResult result;

  @override
  Future<LocateResult> locate() async => result;
}
