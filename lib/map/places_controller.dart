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
  var _challengeOnly = false;
  Set<String> _challengePlaceIds = const {};
  Set<String> _verifiedPlaceIds = const {};
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
  bool get challengeOnly => _challengeOnly;
  Set<String> get challengePlaceIds => _challengePlaceIds;
  Set<String> get verifiedPlaceIds => _verifiedPlaceIds;
  String get query => _query;
  GeoBounds get viewport => _viewport;
  Place? get selected => _selected;
  MapViewMode get viewMode => _viewMode;
  GeoPoint? get userLocation => _userLocation;
  String? get banner => _banner;
  Object? get error => _error;
  bool get loading => _loading;
  bool get hasError => _error != null;

  List<Place> get filtered => applyPlaceFilters(
    _all,
    categories: _categories,
    challengeOnly: _challengeOnly,
    challengePlaceIds: _challengePlaceIds,
    verifiedPlaceIds: _verifiedPlaceIds,
  );

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
    _dropSelectedIfFilteredOut();
    notifyListeners();
  }

  void setChallengeOnly(bool value) {
    if (_challengeOnly == value) return;
    _challengeOnly = value;
    _dropSelectedIfFilteredOut();
    notifyListeners();
  }

  void setMapFilters({
    required Set<PlaceCategory> categories,
    required bool challengeOnly,
  }) {
    _categories = Set<PlaceCategory>.from(categories);
    _challengeOnly = challengeOnly;
    _dropSelectedIfFilteredOut();
    notifyListeners();
  }

  /// Challenge membership used when [challengeOnly] is on.
  /// Same ids as [placeIdsInChallenge] / forest+verified challenge stops.
  void setChallengePlaceIds(Set<String> ids) {
    if (setEquals(_challengePlaceIds, ids)) return;
    _challengePlaceIds = Set<String>.from(ids);
    _dropSelectedIfFilteredOut();
    notifyListeners();
  }

  void setVerifiedPlaceIds(Set<String> ids) {
    if (setEquals(_verifiedPlaceIds, ids)) return;
    _verifiedPlaceIds = Set<String>.from(ids);
    _dropSelectedIfFilteredOut();
    notifyListeners();
  }

  void _dropSelectedIfFilteredOut() {
    final selected = _selected;
    if (selected == null) return;
    for (final place in filtered) {
      if (place.id == selected.id) return;
    }
    _selected = null;
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
