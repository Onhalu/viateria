import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

/// True only when the browser accepts `navigator.canShare({ files })`.
/// Desktop browsers return false; mobile Safari and Chrome often return true.
Future<bool> platformCanShareDiplomaFiles() async {
  try {
    final bytes = Uint8List.fromList(const [137, 80, 78, 71, 13, 10, 26, 10]);
    final file = File(
      [bytes.buffer.toJS].toJS,
      'probe.png',
      FilePropertyBag()..type = 'image/png',
    );
    return window.navigator.canShare(ShareData(files: [file].toJS));
  } catch (_) {
    return false;
  }
}
