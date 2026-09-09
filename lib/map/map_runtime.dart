import 'package:flutter/widgets.dart';

/// Process-wide flags for map surfaces.
///
/// Widget tests disable the native MapLibre platform view — it cannot run
/// under `flutter test`.
abstract final class MapRuntime {
  /// Native MapLibre is skipped under `flutter test` (`FLUTTER_TEST`).
  static bool embedNativeMap = !const bool.fromEnvironment('FLUTTER_TEST');

  static bool shouldEmbed(BuildContext context) {
    return embedNativeMap && TickerMode.valuesOf(context).enabled;
  }
}
