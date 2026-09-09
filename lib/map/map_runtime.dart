import 'package:flutter/widgets.dart';

/// Process-wide flags for map surfaces.
///
/// Widget tests disable the native MapLibre platform view — it cannot run
/// under `flutter test`.
abstract final class MapRuntime {
  /// Native MapLibre is skipped under `flutter test`.
  static bool embedNativeMap = true;

  static bool shouldEmbed(BuildContext context) {
    if (!embedNativeMap) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    // Native MapLibre views cannot run under flutter_test.
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('TestWidgetsFlutterBinding')) return false;
    return true;
  }
}
