import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
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
import '../../models/models.dart';
import 'map_chrome.dart';
import 'places_map_host.dart';
import 'places_map_panels.dart';

/// Shared MapLibre places surface used by the Mapa tab and challenge maps.
class PlacesMapSurface extends StatefulWidget {
  const PlacesMapSurface({
    super.key,
    this.catalog,
    this.compact = false,
    this.safeArea = true,
    this.initialCamera,
    this.geometry,
    this.onWaypointTap,
    this.onReady,
    this.onLayersReady,
    this.overlayTop,
    this.overlayActions = const [],
  });

  final PlaceCatalog? catalog;
  final bool compact;
  final bool safeArea;
  final CameraPosition? initialCamera;
  final ChallengeMapGeometry? geometry;
  final ValueChanged<Waypoint>? onWaypointTap;
  final void Function(MapLibreMapController controller)? onReady;
  final void Function(MapLibreMapController controller)? onLayersReady;
  final Widget? overlayTop;
  final List<Widget> overlayActions;

  @override
  State<PlacesMapSurface> createState() => _PlacesMapSurfaceState();
}

class _PlacesMapSurfaceState extends State<PlacesMapSurface> {
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
    final selected = _controller.selected;
    final viewMode = _controller.viewMode;
    final sheetOpen = selected != null && viewMode == MapViewMode.map;
    final embed = MapRuntime.shouldEmbed(context) && !_mapFailed;
    final compact = widget.compact;
    final inset = MapChromeSizes.inset(compact);
    final locateSize = MapChromeSizes.circleButton(compact);
    final locateIcon = MapChromeSizes.circleIcon(compact);
    final bottomLift = sheetOpen ? (compact ? 148.0 : 200.0) : inset;

    final body = Stack(
      fit: StackFit.expand,
      children: [
        embed
            ? PlacesMapHost(
                places: _controller.filtered,
                initialCamera:
                    widget.initialCamera ?? MapStyleConfig.defaultCamera,
                geometry: widget.geometry,
                selectedPlaceId: selected?.id,
                onWaypointTap: widget.onWaypointTap,
                onReady: (controller) {
                  _map = controller;
                  widget.onReady?.call(controller);
                },
                onLayersReady: widget.onLayersReady,
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(inset, inset, inset, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.overlayTop != null) ...[
                    widget.overlayTop!,
                    SizedBox(height: compact ? 6 : 10),
                  ],
                  Row(
                    children: [
                      Expanded(child: _searchBar(strings)),
                      const SizedBox(width: 8),
                      MapIconButton(
                        key: const Key('map-filter-button'),
                        icon: Icons.tune,
                        tooltip: strings.filtersTitle,
                        size: locateSize,
                        iconSize: locateIcon,
                        onPressed: () => unawaited(_openFilters(strings)),
                      ),
                    ],
                  ),
                  if (_controller.query.trim().isNotEmpty &&
                      _controller.searchHits.isNotEmpty)
                    _searchResults(_controller.searchHits),
                  SizedBox(height: compact ? 6 : 10),
                  Row(
                    children: [
                      MapGlass(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 8 : 10,
                            vertical: compact ? 5 : 6,
                          ),
                          child: Text(
                            strings.monumentCount(_controller.visibleCount),
                            key: const Key('map-poi-count'),
                            style: TextStyle(
                              color: MapPalette.bark,
                              fontWeight: FontWeight.w600,
                              fontSize: MapChromeSizes.countFont(compact),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      MapGlass(
                        color: MapOverlayColors.accent,
                        borderRadius: BorderRadius.circular(
                          MapChromeSizes.toggleRadius,
                        ),
                        onTap: _controller.toggleView,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 12,
                            vertical: compact ? 6 : 8,
                          ),
                          child: Row(
                            key: const Key('map-view-toggle'),
                            children: [
                              Icon(
                                viewMode == MapViewMode.map
                                    ? Icons.view_list
                                    : Icons.map_outlined,
                                color: MapPalette.cream,
                                size: MapChromeSizes.toggleIcon(compact),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                viewMode == MapViewMode.map
                                    ? strings.viewList
                                    : strings.viewMap,
                                style: TextStyle(
                                  color: MapPalette.cream,
                                  fontWeight: FontWeight.w600,
                                  fontSize: MapChromeSizes.toggleFont(compact),
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
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: widget.compact ? 6 : 10),
                  child: PlaceListPanel(
                    places: _controller.listPlaces,
                    strings: strings,
                    userLocation: _controller.userLocation,
                    compact: widget.compact,
                    onSelect: _selectFromList,
                  ),
                ),
              )
            else
              const Expanded(child: IgnorePointer(child: SizedBox.expand())),
          ],
        ),
        if (viewMode == MapViewMode.map) ...[
          Positioned(
            left: inset,
            bottom: bottomLift,
            child: OsmAttributionChip(
              label: strings.osmAttribution,
              longLabel: strings.osmAttributionLong,
            ),
          ),
          Positioned(
            right: inset,
            bottom: bottomLift,
            child: MapIconButton(
              key: const Key('map-locate-fab'),
              icon: Icons.my_location,
              tooltip: strings.locateTooltip,
              size: locateSize,
              iconSize: locateIcon,
              onPressed: () => unawaited(_locate()),
            ),
          ),
          if (widget.overlayActions.isNotEmpty)
            Positioned(
              left: inset,
              right: inset + locateSize + 8,
              bottom: bottomLift,
              child: Wrap(
                key: const Key('route-map-nav-actions'),
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: widget.overlayActions,
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
              compact: widget.compact,
              onClose: () => _controller.select(null),
              onDetail: () => _showDetailPlaceholder(strings),
            ),
          ),
      ],
    );

    if (!widget.safeArea) return body;
    return SafeArea(bottom: false, child: body);
  }

  Widget _searchBar(AppStrings strings) {
    final compact = widget.compact;
    return MapGlass(
      borderRadius: BorderRadius.circular(MapChromeSizes.searchRadius),
      child: SizedBox(
        height: MapChromeSizes.searchHeight(compact),
        child: TextField(
          key: const Key('map-search-field'),
          controller: _search,
          focusNode: _searchFocus,
          style: TextStyle(
            color: MapPalette.forest,
            fontSize: MapChromeSizes.searchFont(compact),
          ),
          cursorColor: MapPalette.forest,
          decoration: InputDecoration(
            hintText: strings.searchHint,
            hintStyle: const TextStyle(color: MapPalette.bark),
            prefixIcon: Icon(
              Icons.search,
              color: MapPalette.forest,
              size: MapChromeSizes.searchIcon(compact),
            ),
            border: InputBorder.none,
            isDense: compact,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
          constraints: BoxConstraints(maxHeight: widget.compact ? 110 : 220),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final place in results)
                ListTile(
                  key: Key('map-search-${place.id}'),
                  dense: true,
                  title: Text(
                    place.name,
                    style: const TextStyle(color: MapPalette.forest),
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

  Future<void> _locate() async {
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
                  style: const TextStyle(color: MapPalette.forest),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(
                  action,
                  style: const TextStyle(color: MapPalette.forest),
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

CameraPosition challengeCameraOf(List<Waypoint> waypoints) {
  final ordered = [...waypoints]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final center = ordered.isEmpty
      ? MapStyleConfig.prague
      : LatLng(ordered.first.lat, ordered.first.lng);
  return CameraPosition(target: center, zoom: ordered.length > 1 ? 12 : 13);
}

void fitChallengeCamera(
  MapLibreMapController controller, {
  required List<Waypoint> waypoints,
  ll.LatLng? start,
  List<ll.LatLng> hikeLine = const [],
  List<ll.LatLng> bikeLine = const [],
}) {
  fitMapPoints(controller, [
    for (final waypoint in waypoints) waypoint.latLng,
    ?start,
    ...hikeLine,
    ...bikeLine,
  ]);
}

void fitMapPoints(MapLibreMapController controller, List<ll.LatLng> points) {
  if (points.isEmpty) return;
  if (points.length == 1) {
    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(points.first.latitude, points.first.longitude),
          13,
        ),
      ),
    );
    return;
  }
  unawaited(
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        boundsOf(points),
        left: 32,
        top: 32,
        right: 32,
        bottom: 32,
      ),
    ),
  );
}

LatLngBounds boundsOf(List<ll.LatLng> points) {
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final p in points) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  if ((maxLat - minLat).abs() < 0.0002) {
    minLat -= 0.002;
    maxLat += 0.002;
  }
  if ((maxLng - minLng).abs() < 0.0002) {
    minLng -= 0.002;
    maxLng += 0.002;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}
