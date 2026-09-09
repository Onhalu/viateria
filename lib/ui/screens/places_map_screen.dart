import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../map/map_runtime.dart';
import '../../map/map_style_config.dart';
import '../../map/place.dart';
import '../../map/place_catalog.dart';
import '../../map/places_controller.dart';
import '../widgets/map_chrome.dart';
import '../widgets/places_map_host.dart';
import '../widgets/places_map_panels.dart';

/// Mapa tab: MapLibre places map with search, filters, list toggle, locate.
///
/// Lives in the existing 4-item shell. Does not replace catalog / last
/// challenge / profile.
class PlacesMapScreen extends StatefulWidget {
  const PlacesMapScreen({super.key, this.catalog});

  final PlaceCatalog? catalog;

  @override
  State<PlacesMapScreen> createState() => _PlacesMapScreenState();
}

class _PlacesMapScreenState extends State<PlacesMapScreen> {
  late final PlacesMapController _controller;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  MapLibreMapController? _map;
  var _mapFailed = false;

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _controller = PlacesMapController(
      catalog: widget.catalog ?? const AssetPlaceCatalog(),
      deviceLocation: services.deviceLocation,
    );
    _controller.addListener(_onController);
    unawaited(_controller.load());
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onController);
    _controller.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final media = MediaQuery.of(context);
    final selected = _controller.selected;
    final viewMode = _controller.viewMode;
    final sheetOpen = selected != null && viewMode == MapViewMode.map;
    final embed = MapRuntime.shouldEmbed(context) && !_mapFailed;

    return SafeArea(
      bottom: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          embed
              ? PlacesMapHost(
                  places: _controller.filtered,
                  initialCamera: MapStyleConfig.defaultCamera,
                  onReady: (controller) => _map = controller,
                  onMapFailed: () {
                    if (mounted) setState(() => _mapFailed = true);
                  },
                  onPlaceTap: _controller.select,
                  onBackgroundTap: () => _controller.select(null),
                  onViewportChanged: _controller.setViewport,
                )
              : const MapFallbackCanvas(),
          if (_mapFailed)
            _ErrorPanel(
              message: strings.mapLoadError,
              retryLabel: strings.retry,
              onRetry: () => setState(() => _mapFailed = false),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: 8,
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
                if (_controller.query.trim().isNotEmpty &&
                    _controller.searchHits.isNotEmpty)
                  _searchResults(_controller.searchHits),
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
                          strings.monumentCount(_controller.visibleCount),
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
                      color: MapOverlayColors.accent,
                      borderRadius: BorderRadius.circular(22),
                      onTap: _controller.toggleView,
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
                if (_controller.hasError)
                  _Banner(
                    message: strings.catalogLoadError,
                    action: strings.retry,
                    onAction: () => unawaited(_controller.load()),
                  ),
                if (_controller.banner != null)
                  _Banner(
                    message: _bannerText(strings, _controller.banner!),
                    action: strings.closeCta,
                    onAction: () => _controller.setBanner(null),
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
              child: PlaceListPanel(
                places: _controller.listPlaces,
                strings: strings,
                userLocation: _controller.userLocation,
                onSelect: _selectFromList,
              ),
            ),
          if (viewMode == MapViewMode.map) ...[
            Positioned(
              left: 16,
              bottom: (sheetOpen ? 200.0 : 16.0),
              child: OsmAttributionChip(
                label: strings.osmAttribution,
                longLabel: strings.osmAttributionLong,
              ),
            ),
            Positioned(
              right: 16,
              bottom: (sheetOpen ? 200.0 : 16.0),
              child: MapIconButton(
                key: const Key('map-locate-fab'),
                icon: Icons.my_location,
                tooltip: strings.locateTooltip,
                onPressed: () => unawaited(_locate(strings)),
              ),
            ),
          ],
          if (selected != null && viewMode == MapViewMode.map)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PlaceDetailSheet(
                place: selected,
                strings: strings,
                userLocation: _controller.userLocation,
                onClose: () => _controller.select(null),
                onDetail: () => _showDetailPlaceholder(strings),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchBar(AppStrings strings) {
    return MapGlass(
      child: SizedBox(
        height: 48,
        child: TextField(
          key: const Key('map-search-field'),
          controller: _search,
          focusNode: _searchFocus,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: strings.searchHint,
            hintStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.search, color: Colors.white),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) {
            _debounce?.cancel();
            _debounce = Timer(MapStyleConfig.searchDebounce, () {
              _controller.setQuery(value);
            });
          },
        ),
      ),
    );
  }

  Widget _searchResults(List<Place> results) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MapGlass(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final place in results)
                ListTile(
                  key: Key('map-search-${place.id}'),
                  dense: true,
                  title: Text(
                    place.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    _search.clear();
                    _controller.setQuery('');
                    _searchFocus.unfocus();
                    _selectFromList(place);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilters(AppStrings strings) async {
    final next = await showMapFilterSheet(
      context: context,
      strings: strings,
      selected: _controller.categories,
    );
    if (next != null) _controller.setCategories(next);
  }

  void _selectFromList(Place place) {
    _controller.showMap();
    _controller.select(place);
    unawaited(
      _map?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place.location.latitude, place.location.longitude),
          14,
        ),
      ),
    );
  }

  Future<void> _locate(AppStrings strings) async {
    final here = await _controller.locate();
    if (here == null) return;
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(here.latitude, here.longitude), 14),
    );
  }

  void _showDetailPlaceholder(AppStrings strings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(strings.detailPlaceholder),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.closeCta),
          ),
        ],
      ),
    );
  }

  String _bannerText(AppStrings strings, String code) {
    return switch (code) {
      'denied' => strings.locateDenied,
      'failed' => strings.locateDisabled,
      _ => code,
    };
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                  style: const TextStyle(color: Colors.white),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

/// Keeps the existing `/map` route type name used by [app.dart].
class ChallengesMapScreen extends PlacesMapScreen {
  const ChallengesMapScreen({super.key, super.catalog});
}
