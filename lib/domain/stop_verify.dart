import '../map/place.dart';
import '../map/place_query.dart';

/// GPS-first stop verification. Photo is the fallback when GPS is denied,
/// unavailable, or outside [radiusMeters].
abstract final class VerifyProximity {
  /// Reasonable on-site radius (~100–150 m). Keep this the single constant.
  static const radiusMeters = 120.0;

  static bool isWithin({required GeoPoint here, required GeoPoint target}) {
    return distanceKm(here, target) * 1000 <= radiusMeters;
  }

  /// Sentinel storage path for GPS completions. Matches
  /// `verify_waypoint` (`p_photo_path` must be `{userId}/…`).
  static String gpsPhotoPath({
    required String userId,
    required String challengeId,
    required String waypointId,
  }) {
    return '$userId/gps/$challengeId/$waypointId';
  }
}
