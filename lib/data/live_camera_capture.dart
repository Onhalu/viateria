import 'package:image_picker/image_picker.dart';

import '../domain/photo_verify.dart';

class LiveCameraPhotoCapture implements PhotoCapture {
  LiveCameraPhotoCapture({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<LivePhoto?> captureLivePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return LivePhoto(bytes: bytes, mimeType: 'image/jpeg');
  }
}
