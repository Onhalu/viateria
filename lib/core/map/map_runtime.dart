/// Process-wide flags for the map module. Widget tests disable the native
/// MapLibre platform view (it cannot run under `flutter test`).
abstract final class MapRuntime {
  static bool embedNativeMap = true;
}
