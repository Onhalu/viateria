import 'package:shared_preferences/shared_preferences.dart';

import '../domain/poi.dart';

class SavedCamera {
  const SavedCamera({
    required this.target,
    required this.zoom,
    this.bearing = 0,
    this.tilt = 0,
  });

  final GeoPoint target;
  final double zoom;
  final double bearing;
  final double tilt;
}

class CameraStore {
  CameraStore({this._prefs});

  SharedPreferences? _prefs;

  static const latKey = 'viateria.map.camera.lat';
  static const lngKey = 'viateria.map.camera.lng';
  static const zoomKey = 'viateria.map.camera.zoom';
  static const bearingKey = 'viateria.map.camera.bearing';
  static const tiltKey = 'viateria.map.camera.tilt';

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SavedCamera?> load() async {
    final prefs = await _instance();
    final lat = prefs.getDouble(latKey);
    final lng = prefs.getDouble(lngKey);
    final zoom = prefs.getDouble(zoomKey);
    if (lat == null || lng == null || zoom == null) return null;
    return SavedCamera(
      target: GeoPoint(lat, lng),
      zoom: zoom,
      bearing: prefs.getDouble(bearingKey) ?? 0,
      tilt: prefs.getDouble(tiltKey) ?? 0,
    );
  }

  Future<void> save(SavedCamera camera) async {
    final prefs = await _instance();
    await prefs.setDouble(latKey, camera.target.latitude);
    await prefs.setDouble(lngKey, camera.target.longitude);
    await prefs.setDouble(zoomKey, camera.zoom);
    await prefs.setDouble(bearingKey, camera.bearing);
    await prefs.setDouble(tiltKey, camera.tilt);
  }
}
