import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart' as provider;

import '../../../core/l10n/map_strings.dart';
import '../../../core/map/map_runtime.dart';
import '../../../core/map/map_style_config.dart';
import '../../../core/theme/map_colors.dart';
import '../../../l10n/locale_controller.dart';
import '../application/map_providers.dart';
import '../data/location_service.dart';
import '../domain/poi.dart';
import 'widgets/map_chrome.dart';
import 'widgets/map_filter_sheet.dart';
import 'widgets/maplibre_host.dart';
import 'widgets/poi_detail_sheet.dart';
import 'widgets/poi_list_panel.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  MapLibreMapController? _map;
  CameraPosition _initialCamera = MapStyleConfig.defaultCamera;
  bool _cameraReady = false;
  bool _mapFailed = false;
  static const _sheetPeek = 0.28;
  static const _sheetExpand = 0.70;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreCamera());
  }

  Future<void> _restoreCamera() async {
    final saved = await ref.read(cameraStoreProvider).load();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _initialCamera = CameraPosition(
          target: LatLng(saved.target.latitude, saved.target.longitude),
          zoom: saved.zoom,
          bearing: saved.bearing,
          tilt: saved.tilt,
        );
      }
      _cameraReady = true;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  MapStrings get _strings {
    final locale = provider.Provider.of<LocaleController>(
      context,
      listen: true,
    ).locale;
    return MapStrings(locale);
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final catalog = ref.watch(poiCatalogProvider);
    final count = ref.watch(visibleCountProvider);
    final selected = ref.watch(selectedPoiProvider);
    final viewMode = ref.watch(mapViewModeProvider);
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final banner = ref.watch(mapBannerProvider);
    final userLocation = ref.watch(userLocationProvider);
    final listPois = ref.watch(listPoisProvider);
    final media = MediaQuery.of(context);
    final navClearance = 72.0 + media.padding.bottom;
    final sheetOpen = selected != null && viewMode == MapViewMode.map;
    final bottomChrome = sheetOpen
        ? media.size.height * _sheetPeek
        : navClearance;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_cameraReady)
          MapRuntime.embedNativeMap && !_mapFailed
              ? MapLibreHost(
                  initialCamera: _initialCamera,
                  onReady: (controller) => _map = controller,
                  onMapFailed: () {
                    if (mounted) setState(() => _mapFailed = true);
                  },
                )
              : const MapFallbackCanvas(),
        if (_mapFailed)
          _ErrorPanel(
            message: strings.mapLoadError,
            retryLabel: strings.retry,
            onRetry: () {
              setState(() => _mapFailed = false);
            },
          ),
        Positioned(
          left: 16,
          right: 16,
          top: media.padding.top + 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _searchBar(strings)),
                  const SizedBox(width: 8),
                  MapIconButton(
                    key: const Key('map-filter-button'),
                    icon: Icons.tune,
                    tooltip: strings.filtersTitle,
                    onPressed: () => unawaited(_openFilters(strings)),
                  ),
                ],
              ),
              if (query.trim().isNotEmpty && results.isNotEmpty)
                _searchResults(results),
              const SizedBox(height: 10),
              Row(
                children: [
                  MapGlass(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        strings.poiCount(count),
                        key: const Key('map-poi-count'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  MapGlass(
                    color: MapColors.accent,
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      ref.read(mapViewModeProvider.notifier).toggle();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        key: const Key('map-view-toggle'),
                        children: [
                          Icon(
                            viewMode == MapViewMode.map
                                ? Icons.view_list
                                : Icons.map_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            viewMode == MapViewMode.map
                                ? strings.viewList
                                : strings.viewMap,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (catalog.hasError)
                _Banner(
                  message: strings.catalogLoadError,
                  action: strings.retry,
                  onAction: () =>
                      ref.read(poiCatalogProvider.notifier).retry(),
                ),
              if (banner != null)
                _Banner(
                  message: banner,
                  action: strings.closeCta,
                  onAction: () =>
                      ref.read(mapBannerProvider.notifier).clear(),
                ),
            ],
          ),
        ),
        if (viewMode == MapViewMode.list)
          Positioned(
            left: 0,
            right: 0,
            top: media.padding.top + 108,
            bottom: 0,
            child: PoiListPanel(
              pois: listPois,
              strings: strings,
              userLocation: userLocation,
              onSelect: _selectFromList,
            ),
          ),
        if (viewMode == MapViewMode.map) ...[
          Positioned(
            left: 16,
            bottom: bottomChrome + 8,
            child: Row(
              children: [
                MapScaleBar(
                  zoom: _map?.cameraPosition?.zoom ?? _initialCamera.zoom,
                  latitude:
                      _map?.cameraPosition?.target.latitude ??
                      _initialCamera.target.latitude,
                ),
                const SizedBox(width: 8),
                OsmAttributionChip(
                  label: strings.osmAttribution,
                  longLabel: strings.osmAttributionLong,
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: bottomChrome + 8,
            child: MapIconButton(
              key: const Key('map-locate-fab'),
              icon: Icons.my_location,
              tooltip: strings.locateTooltip,
              background: MapColors.surface,
              size: 52,
              onPressed: () => unawaited(_locate(strings)),
            ),
          ),
        ],
        if (sheetOpen)
          DraggableScrollableSheet(
            initialChildSize: _sheetPeek,
            minChildSize: _sheetPeek,
            maxChildSize: _sheetExpand,
            builder: (context, _) {
              return SizedBox.expand(
                child: PoiDetailSheet(
                  poi: selected,
                  strings: strings,
                  userLocation: userLocation,
                  onClose: () =>
                      ref.read(selectedPoiProvider.notifier).clear(),
                  onDetail: () => _showDetailPlaceholder(strings),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _searchBar(MapStrings strings) {
    return MapGlass(
      child: SizedBox(
        height: 48,
        child: TextField(
          key: const Key('map-search-field'),
          controller: _search,
          focusNode: _searchFocus,
          style: const TextStyle(color: Colors.white),
          cursorColor: MapColors.accent,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: strings.searchHint,
            hintStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.search, color: Colors.white),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () {
                      _search.clear();
                      ref.read(searchQueryProvider.notifier).setQuery('');
                      setState(() {});
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) {
            setState(() {});
            _debounce?.cancel();
            _debounce = Timer(MapStyleConfig.searchDebounce, () {
              if (!mounted) return;
              ref.read(searchQueryProvider.notifier).setQuery(value);
            });
          },
        ),
      ),
    );
  }

  Widget _searchResults(List<Poi> results) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MapGlass(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            key: const Key('map-search-results'),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final poi = results[index];
              return ListTile(
                dense: true,
                title: Text(
                  poi.name,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => unawaited(_selectFromSearch(poi)),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openFilters(MapStrings strings) async {
    final next = await showMapFilterSheet(
      context: context,
      strings: strings,
      selected: ref.read(mapFiltersProvider),
    );
    if (next == null || !mounted) return;
    ref.read(mapFiltersProvider.notifier).replace(next);
  }

  Future<void> _selectFromSearch(Poi poi) async {
    _search.clear();
    ref.read(searchQueryProvider.notifier).setQuery('');
    _searchFocus.unfocus();
    ref.read(selectedPoiProvider.notifier).select(poi);
    ref.read(mapViewModeProvider.notifier).setMode(MapViewMode.map);
    await _flyTo(poi);
    setState(() {});
  }

  void _selectFromList(Poi poi) {
    ref.read(selectedPoiProvider.notifier).select(poi);
    ref.read(mapViewModeProvider.notifier).setMode(MapViewMode.map);
    unawaited(_flyTo(poi));
  }

  Future<void> _flyTo(Poi poi) async {
    final controller = _map;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(poi.location.latitude, poi.location.longitude),
        14,
      ),
    );
  }

  Future<void> _locate(MapStrings strings) async {
    final result = await ref.read(locationServiceProvider).locate();
    switch (result.outcome) {
      case LocateOutcome.denied:
        ref.read(mapBannerProvider.notifier).set(strings.locateDenied);
      case LocateOutcome.disabled:
        ref.read(mapBannerProvider.notifier).set(strings.locateDisabled);
      case LocateOutcome.granted:
        final point = result.position!;
        ref.read(userLocationProvider.notifier).set(point);
        ref.read(myLocationEnabledProvider.notifier).state = true;
        ref.read(mapBannerProvider.notifier).clear();
        await _map?.easeCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(point.latitude, point.longitude),
            13,
          ),
        );
    }
  }

  void _showDetailPlaceholder(MapStrings strings) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.detailPlaceholder)),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.action,
    required this.onAction,
  });

  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MapGlass(
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(
                  action,
                  style: const TextStyle(color: MapColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xAA1A1A1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              key: const Key('map-load-fail'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: MapColors.accent),
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
