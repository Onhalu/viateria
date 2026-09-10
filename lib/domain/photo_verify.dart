/// Stop verification: GPS within [VerifyProximity.radiusMeters] is primary.
/// Live camera photo is the fallback. Gallery / files stay rejected.
enum PhotoSource { liveCamera, gallery, unknown }

class PhotoCaptureRequest {
  const PhotoCaptureRequest({required this.source});

  final PhotoSource source;
}

class PhotoVerifyPolicy {
  const PhotoVerifyPolicy();

  /// Gallery and unknown sources are rejected. GPS is handled separately
  /// before this photo fallback runs.
  bool allows(PhotoCaptureRequest request) =>
      request.source == PhotoSource.liveCamera;

  bool acceptsUpload({
    required PhotoCaptureRequest request,
    required List<int> bytes,
  }) {
    return allows(request) && bytes.isNotEmpty;
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
