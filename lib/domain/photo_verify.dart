/// Stop verification: GPS within [VerifyProximity.radiusMeters] is primary.
/// Live camera photo is the fallback. Gallery / files stay rejected.
enum PhotoSource { liveCamera, gallery, unknown }

class PhotoCaptureRequest {
  const PhotoCaptureRequest({required this.source});

  final PhotoSource source;
}

/// Bucket `waypoint-photos` upload cap: 8 MiB (8 * 1024 * 1024 bytes).
///
/// Keep this equal to `storage.buckets.file_size_limit` in
/// `supabase/migrations/0019_waypoint_photos_upload_limits.sql`.
const int waypointPhotoMaxBytes = 8388608;

/// Content types the bucket accepts. Comparison is exact and case-sensitive.
///
/// Live camera sends [liveCameraPhotoMimeType] only. PNG and WebP are
/// allowed so a future capture path can use them without a bucket change,
/// but the object key extension must come from [waypointPhotoFileExtension].
const Set<String> allowedWaypointPhotoMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
};

/// What the live-camera capture attaches. `image_picker` is called with
/// `imageQuality: 85` and `maxWidth: 1920`, which re-encodes the shot as JPEG.
const String liveCameraPhotoMimeType = 'image/jpeg';

enum WaypointPhotoRejection { empty, mime, oversize }

class WaypointPhotoRejected implements Exception {
  const WaypointPhotoRejected(this.reason);

  final WaypointPhotoRejection reason;

  @override
  String toString() => 'WaypointPhotoRejected(${reason.name})';
}

/// Null when [bytes] and [mimeType] may be uploaded to `waypoint-photos`.
WaypointPhotoRejection? waypointPhotoRejection({
  required List<int> bytes,
  required String mimeType,
}) {
  if (bytes.isEmpty) return WaypointPhotoRejection.empty;
  if (!allowedWaypointPhotoMimeTypes.contains(mimeType)) {
    return WaypointPhotoRejection.mime;
  }
  if (bytes.length > waypointPhotoMaxBytes) {
    return WaypointPhotoRejection.oversize;
  }
  return null;
}

/// Throws [WaypointPhotoRejected] before any storage request.
void requireWaypointPhoto({
  required List<int> bytes,
  required String mimeType,
}) {
  final reason = waypointPhotoRejection(bytes: bytes, mimeType: mimeType);
  if (reason != null) throw WaypointPhotoRejected(reason);
}

/// Object-key suffix for an allowed content type. `.jpg` is JPEG only.
String waypointPhotoFileExtension(String mimeType) {
  switch (mimeType) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    default:
      throw const WaypointPhotoRejected(WaypointPhotoRejection.mime);
  }
}

class PhotoVerifyPolicy {
  const PhotoVerifyPolicy();

  /// Gallery and unknown sources are rejected. GPS is handled separately
  /// before this photo fallback runs.
  bool allows(PhotoCaptureRequest request) =>
      request.source == PhotoSource.liveCamera;

  /// Live camera, non-empty body, allowlisted MIME, and size at or under
  /// [waypointPhotoMaxBytes].
  bool acceptsUpload({
    required PhotoCaptureRequest request,
    required List<int> bytes,
    required String mimeType,
  }) {
    return allows(request) &&
        waypointPhotoRejection(bytes: bytes, mimeType: mimeType) == null;
  }
}

/// Abstraction over the device camera so tests do not open hardware.
abstract class PhotoCapture {
  Future<LivePhoto?> captureLivePhoto();
}

class LivePhoto {
  const LivePhoto({required this.bytes, required this.mimeType});

  final List<int> bytes;
  final String mimeType;
}
