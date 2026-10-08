import 'package:flutter/foundation.dart';

/// iOS and Android can put a PNG on the system share sheet.
/// Desktop apps and tests cannot; they use the download fallback.
Future<bool> platformCanShareDiplomaFiles() async {
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    _ => false,
  };
}
