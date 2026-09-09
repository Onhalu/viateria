import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/camera_store.dart';
import '../data/location_service.dart';
import '../data/poi_repository.dart';
import '../domain/poi.dart';
import '../domain/poi_category.dart';
import '../domain/poi_query.dart';

final poiRepositoryProvider = Provider<PoiRepository>(
  (ref) => const AssetPoiRepository(),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

final cameraStoreProvider = Provider<CameraStore>((ref) => CameraStore());

final poiCatalogProvider =
    AsyncNotifierProvider<PoiCatalogNotifier, List<Poi>>(
      PoiCatalogNotifier.new,
    );

class PoiCatalogNotifier extends AsyncNotifier<List<Poi>> {
  @override
  Future<List<Poi>> build() => ref.read(poiRepositoryProvider).fetchAll();

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(poiRepositoryProvider).fetchAll(),
    );
  }
}

final mapFiltersProvider =
    NotifierProvider<MapFiltersNotifier, Set<PoiCategory>>(
      MapFiltersNotifier.new,
    );

class MapFiltersNotifier extends Notifier<Set<PoiCategory>> {
  @override
  Set<PoiCategory> build() => Set<PoiCategory>.from(PoiCategory.values);

  void replace(Set<PoiCategory> next) => state = Set<PoiCategory>.from(next);

  void toggle(PoiCategory category) {
    final next = Set<PoiCategory>.from(state);
    if (!next.add(category)) next.remove(category);
    state = next;
  }

  void selectAll() => state = Set<PoiCategory>.from(PoiCategory.values);
}

enum MapViewMode { map, list }

final mapViewModeProvider = NotifierProvider<MapViewModeNotifier, MapViewMode>(
  MapViewModeNotifier.new,
);

class MapViewModeNotifier extends Notifier<MapViewMode> {
  @override
  MapViewMode build() => MapViewMode.map;

  void toggle() {
    state = state == MapViewMode.map ? MapViewMode.list : MapViewMode.map;
  }

  void setMode(MapViewMode mode) => state = mode;
}

final selectedPoiProvider = NotifierProvider<SelectedPoiNotifier, Poi?>(
  SelectedPoiNotifier.new,
);

class SelectedPoiNotifier extends Notifier<Poi?> {
  @override
  Poi? build() => null;

  void select(Poi? poi) => state = poi;
  void clear() => state = null;
}

final viewportProvider = NotifierProvider<ViewportNotifier, GeoBounds>(
  ViewportNotifier.new,
);

class ViewportNotifier extends Notifier<GeoBounds> {
  @override
  GeoBounds build() => GeoBounds.czechRepublic;

  void setBounds(GeoBounds bounds) => state = bounds;
}

final userLocationProvider = NotifierProvider<UserLocationNotifier, GeoPoint?>(
  UserLocationNotifier.new,
);

class UserLocationNotifier extends Notifier<GeoPoint?> {
  @override
  GeoPoint? build() => null;

  void set(GeoPoint? point) => state = point;
}

final mapBannerProvider = NotifierProvider<MapBannerNotifier, String?>(
  MapBannerNotifier.new,
);

class MapBannerNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? message) => state = message;
  void clear() => state = null;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final myLocationEnabledProvider = StateProvider<bool>((ref) => false);

final filteredPoisProvider = Provider<List<Poi>>((ref) {
  final catalog = ref.watch(poiCatalogProvider).valueOrNull ?? const <Poi>[];
  final filters = ref.watch(mapFiltersProvider);
  return applyCategoryFilter(catalog, filters);
});

final visibleCountProvider = Provider<int>((ref) {
  final filtered = ref.watch(filteredPoisProvider);
  final viewport = ref.watch(viewportProvider);
  return countInViewport(filtered, viewport);
});

final searchResultsProvider = Provider<List<Poi>>((ref) {
  final filtered = ref.watch(filteredPoisProvider);
  final query = ref.watch(searchQueryProvider);
  return searchPois(filtered, query);
});

final listPoisProvider = Provider<List<Poi>>((ref) {
  final filtered = ref.watch(filteredPoisProvider);
  final origin = ref.watch(userLocationProvider);
  return sortForList(filtered, origin);
});
