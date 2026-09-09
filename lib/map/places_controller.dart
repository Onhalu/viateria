import 'package:flutter/foundation.dart';

import '../data/route_services.dart';
import 'map_style_config.dart';
import 'place.dart';
import 'place_catalog.dart';
import 'place_category.dart';
import 'place_query.dart';

enum MapViewMode { map, list }

class PlacesMapController extends ChangeNotifier {
  PlacesMapController({required this.catalog, this.deviceLocation});

  final PlaceCatalog catalog;
  final DeviceLocation? deviceLocation;

  List<Place> _all = const [];
  Set<PlaceCategory> _categories = {...PlaceCategory.values};
  String _query = '';
  GeoBounds _viewport = GeoBounds.czechRepublic;
  Place? _selected;
  MapViewMode _viewMode = MapViewMode.map;
  GeoPoint? _userLocation;
  String? _banner;
  Object? _error;
  var _loading = false;

  List<Place> get all => _all;
  Set<PlaceCategory> get categories => _categories;
  String get query => _query;
  GeoBounds get viewport => _viewport;
  Place? get selected => _selected;
  MapViewMode get viewMode => _viewMode;
  GeoPoint? get userLocation => _userLocation;
  String? get banner => _banner;
  Object? get error => _error;
  bool get loading => _loading;
  bool get hasError => _error != null;

  List<Place> get filtered => applyCategoryFilter(_all, _categories);

  int get visibleCount => countInViewport(filtered, _viewport);

  List<Place> get searchHits =>
      searchPlaces(filtered, _query, limit: MapStyleConfig.searchLimit);

  List<Place> get listPlaces => sortForList(filtered, _userLocation);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _all = await catalog.fetchAll();
      _error = null;
    } catch (error) {
      _all = const [];
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setCategories(Set<PlaceCategory> next) {
    _categories = Set<PlaceCategory>.from(next);
    if (_selected != null && !_categories.contains(_selected!.category)) {
      _selected = null;
    }
    notifyListeners();
  }

  void setViewport(GeoBounds bounds) {
    _viewport = bounds;
    notifyListeners();
  }

  void select(Place? place) {
    _selected = place;
    notifyListeners();
  }

  void toggleView() {
    _viewMode = _viewMode == MapViewMode.map
        ? MapViewMode.list
        : MapViewMode.map;
    notifyListeners();
  }

  void showMap() {
    if (_viewMode == MapViewMode.map) return;
    _viewMode = MapViewMode.map;
    notifyListeners();
  }

  void setBanner(String? message) {
    _banner = message;
    notifyListeners();
  }

  Future<GeoPoint?> locate() async {
    final location = deviceLocation;
    if (location == null) return null;
    try {
      final here = await location.current();
      _userLocation = GeoPoint(here.lat, here.lng);
      _banner = null;
      notifyListeners();
      return _userLocation;
    } on LocationFailure catch (error) {
      _banner = error.message == 'denied' ? 'denied' : 'failed';
      notifyListeners();
      return null;
    } catch (_) {
      _banner = 'failed';
      notifyListeners();
      return null;
    }
  }
}
