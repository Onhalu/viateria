import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/verified_places.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../map/map_runtime.dart';
import '../../map/map_style_config.dart';
import '../../map/place.dart';
import '../../map/place_catalog.dart';
import '../../map/place_query.dart';
import '../../map/places_controller.dart';
import '../../models/models.dart';
import '../layout/map_search_metrics.dart';
import 'cooperative_map_gestures.dart';
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
    this.onVerifyWaypoint,
    this.onFogTap,
    this.onReady,
    this.onLayersReady,
    this.overlayTop,
    this.overlayActions = const [],
    this.waypointsOnly = false,
    this.catalogRoute = const [],
    this.onAddToRoute,
    this.cooperativeGestures = false,
    this.zoomGesturesEnabled = true,
  });

  final PlaceCatalog? catalog;
  final bool compact;
  final bool safeArea;
  final CameraPosition? initialCamera;
  final ChallengeMapGeometry? geometry;
  final ValueChanged<Waypoint>? onWaypointTap;

  /// Challenge maps own verify so the detail can reload and open the next
  /// chapter. When null, this surface pushes the verify route itself.
  final Future<void> Function(Waypoint waypoint, Place place)? onVerifyWaypoint;

  final ValueChanged<String>? onFogTap;
  final void Function(MapLibreMapController controller)? onReady;
  final void Function(MapLibreMapController controller)? onLayersReady;
  final Widget? overlayTop;
  final List<Widget> overlayActions;

  /// Challenge detail draws only that challenge's waypoint places.
  final bool waypointsOnly;

  /// Session route polyline on the main map.
  final List<ll.LatLng> catalogRoute;

  /// Secondary popup action. Null hides "Add to route".
  final void Function(Place place)? onAddToRoute;

  /// One-finger drags scroll the page. Two fingers pan the map.
  final bool cooperativeGestures;

  final bool zoomGesturesEnabled;

  @override
  State<PlacesMapSurface> createState() => _PlacesMapSurfaceState();
}

class _PlacesMapSurfaceState extends State<PlacesMapSurface> {
  late final PlacesMapController _controller;
  late final VerifiedPlacesStore _verifiedPlaces;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  MapLibreMapController? _map;
  var _mapFailed = false;
  var _controlPressed = false;
  List<Place>? _waypointInput;
  List<Place>? _waypointCache;
  Set<String>? _waypointIds;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocus);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    final services = context.read<AppServices>();
    _controller = PlacesMapController(
      catalog: widget.catalog ?? services.places,
      deviceLocation: services.deviceLocation,
    );
    _controller.addListener(_onController);
    _verifiedPlaces = services.verifiedPlaces;
    _verifiedPlaces.addListener(_syncVerifiedIds);
    _syncVerifiedIds();
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant PlacesMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameChallengeGeometry(oldWidget.geometry, widget.geometry)) {
      _syncChallengeMembership();
    }
  }

  void _onController() {
    _syncChallengeMembership();
    if (mounted) setState(() {});
  }

  void _onSearchFocus() {
    if (mounted) setState(() {});
  }

  bool _onHardwareKey(KeyEvent event) {
    final down = HardwareKeyboard.instance.isControlPressed;
    if (down != _controlPressed && mounted) {
      setState(() => _controlPressed = down);
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _searchFocus.removeListener(_onSearchFocus);
    _debounce?.cancel();
    _verifiedPlaces.removeListener(_syncVerifiedIds);
    _controller.removeListener(_onController);
    _controller.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final embed = MapRuntime.shouldEmbed(context) && !_mapFailed;
    final compact = widget.compact;
    final inset = MapChromeSizes.inset(compact);
    final locateSize = MapChromeSizes.circleButton(compact);
    final locateIcon = MapChromeSizes.circleIcon(compact);

    final body = Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: const Key('places-map-repaint'),
          child: embed
              ? _maybeCooperative(
                  PlacesMapHost(
                    places: _waypointPlaces(_controller.filtered),
                    initialCamera:
                        widget.initialCamera ?? MapStyleConfig.defaultCamera,
                    geometry: widget.geometry,
                    selectedPlaceId: _controller.selected?.id,
                    verifiedPlaceIds: context
                        .read<AppServices>()
                        .verifiedPlaces
                        .ids,
                    catalogRoute: widget.catalogRoute,
                    zoomGesturesEnabled: mapWheelZoomEnabled(
                      isWeb: kIsWeb,
                      controlPressed: _controlPressed,
                      enabled: widget.zoomGesturesEnabled,
                    ),
                    onWaypointTap: widget.onWaypointTap,
                    onFogTap: widget.onFogTap,
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
                  ),
                )
              : const MapFallbackCanvas(),
        ),
        if (_mapFailed)
          _ErrorPanel(
            message: strings.mapLoadError,
            retryLabel: strings.retry,
            onRetry: () => setState(() => _mapFailed = false),
          ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final selected = _controller.selected;
            final viewMode = _controller.viewMode;
            final sheetOpen = selected != null && viewMode == MapViewMode.map;
            final bottomLift = sheetOpen ? (compact ? 148.0 : 200.0) : inset;
            return PopScope(
              canPop: !sheetOpen,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _controller.select(null);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
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
                            LayoutBuilder(
                              builder: (context, searchConstraints) {
                                final slot = searchConstraints.maxWidth;
                                final controls = locateSize + 8;
                                final fieldWidth = mapSearchFieldWidth(
                                  viewportWidth: MediaQuery.sizeOf(context)
                                      .width,
                                  slotWidth: math.max(0, slot - controls),
                                  margin: inset,
                                  controlsWidth: locateSize,
                                  focused: _searchFocus.hasFocus,
                                );
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _searchBar(strings),
                                    ),
                                    const SizedBox(width: 8),
                                    MapIconButton(
                                      key: const Key('map-filter-button'),
                                      icon: Icons.tune,
                                      tooltip: strings.filtersTitle,
                                      size: locateSize,
                                      iconSize: locateIcon,
                                      onPressed: () =>
                                          unawaited(_openFilters(strings)),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (_controller.query.trim().isNotEmpty &&
                                _waypointPlaces(_controller.searchHits)
                                    .isNotEmpty)
                              _searchResults(
                                _waypointPlaces(_controller.searchHits),
                              ),
                            if (_controller.challengeOnly &&
                                _controller.filtered.isEmpty &&
                                viewMode == MapViewMode.map)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: MapGlass(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    child: Text(
                                      strings.filterChallengeOnlyEmpty,
                                      key: const Key(
                                        'map-filter-challenge-only-empty',
                                      ),
                                      style: const TextStyle(
                                        color: MapPalette.forest,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
                                      strings.monumentCount(
                                        _controller.visibleCount,
                                      ),
                                      key: const Key('map-poi-count'),
                                      style: TextStyle(
                                        color: MapPalette.bark,
                                        fontWeight: FontWeight.w600,
                                        fontSize: MapChromeSizes.countFont(
                                          compact,
                                        ),
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
                                          size: MapChromeSizes.toggleIcon(
                                            compact,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          viewMode == MapViewMode.map
                                              ? strings.viewList
                                              : strings.viewMap,
                                          style: TextStyle(
                                            color: MapPalette.cream,
                                            fontWeight: FontWeight.w600,
                                            fontSize: MapChromeSizes.toggleFont(
                                              compact,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_controller.loading)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: MapGlass(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    child: Text(
                                      strings.placesLoading,
                                      key: const Key('map-catalog-loading'),
                                      style: const TextStyle(
                                        color: MapPalette.forest,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!_controller.loading &&
                                !_controller.hasError &&
                                _controller.all.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: MapGlass(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    child: Text(
                                      strings.placesEmpty,
                                      key: const Key('map-places-empty'),
                                      style: const TextStyle(
                                        color: MapPalette.forest,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_controller.hasError)
                              _Banner(
                                message: strings.catalogLoadError,
                                action: strings.retry,
                                onAction: () => unawaited(_controller.load()),
                              ),
                            if (_controller.banner != null)
                              _Banner(
                                message: _bannerText(
                                  strings,
                                  _controller.banner!,
                                ),
                                action: strings.closeCta,
                                onAction: () => _controller.setBanner(null),
                              ),
                          ],
                        ),
                      ),
                      if (viewMode == MapViewMode.list)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: widget.compact ? 6 : 10,
                            ),
                            child: PlaceListPanel(
                              places: _listPlaces,
                              strings: strings,
                              userLocation: _controller.userLocation,
                              compact: widget.compact,
                              emptyLabel: _listEmptyLabel(strings),
                              onSelect: _selectFromList,
                            ),
                          ),
                        )
                      else
                        const Expanded(
                          child: IgnorePointer(child: SizedBox.expand()),
                        ),
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
                      child: Column(
                        key: const Key('map-zoom-column'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MapIconButton(
                            key: const Key('map-zoom-in'),
                            icon: Icons.add,
                            tooltip: strings.zoomIn,
                            size: locateSize,
                            iconSize: locateIcon,
                            onPressed: () => unawaited(_zoom(1)),
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          MapIconButton(
                            key: const Key('map-zoom-out'),
                            icon: Icons.remove,
                            tooltip: strings.zoomOut,
                            size: locateSize,
                            iconSize: locateIcon,
                            onPressed: () => unawaited(_zoom(-1)),
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          MapIconButton(
                            key: const Key('map-locate-fab'),
                            icon: Icons.my_location,
                            tooltip: strings.locateTooltip,
                            size: locateSize,
                            iconSize: locateIcon,
                            onPressed: () => unawaited(_locate()),
                          ),
                        ],
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
                        onVerify: () {
                          unawaited(_onVerify(selected));
                        },
                        onAddToRoute: widget.onAddToRoute == null
                            ? null
                            : () {
                                widget.onAddToRoute!(selected);
                                _controller.select(null);
                              },
                      ),
                    ),
                ],
              ),
            );
          },
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
      challengeOnly: _controller.challengeOnly,
    );
    if (next != null) {
      _controller.setMapFilters(
        categories: next.categories,
        challengeOnly: next.challengeOnly,
      );
    }
  }

  List<Place> _waypointPlaces(List<Place> places) {
    if (!widget.waypointsOnly) return places;
    final ids = <String>{
      for (final waypoint in widget.geometry?.revealedWaypoints ?? const [])
        if (waypoint.placeId != null) waypoint.placeId!,
    };
    if (_waypointCache != null &&
        _waypointIds != null &&
        setEquals(ids, _waypointIds!) &&
        _samePlaceIds(places, _waypointInput)) {
      return _waypointCache!;
    }
    final filtered = [
      for (final place in places)
        if (ids.contains(place.id)) place,
    ];
    _waypointInput = places;
    _waypointIds = ids;
    _waypointCache = filtered;
    return filtered;
  }

  bool _samePlaceIds(List<Place>? a, List<Place>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Widget _maybeCooperative(Widget child) {
    if (!widget.cooperativeGestures) return child;
    return CooperativeMapGestures(child: child);
  }

  void _syncChallengeMembership() {
    final geometry = widget.geometry;
    if (geometry == null || geometry.waypoints.isEmpty) {
      _controller.setChallengePlaceIds(const {});
      _controller.setSuppressedPlaceIds(const {});
      return;
    }
    _controller.setChallengePlaceIds(
      placeIdsInChallenge(
        _controller.all,
        placeIds: geometry.revealedWaypoints.map(
          (waypoint) => waypoint.placeId,
        ),
      ),
    );
    _controller.setSuppressedPlaceIds(geometry.suppressedPlaceIds);
  }

  void _syncVerifiedIds() {
    _controller.setVerifiedPlaceIds(_verifiedPlaces.ids);
  }

  bool _sameChallengeGeometry(
    ChallengeMapGeometry? a,
    ChallengeMapGeometry? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.waypoints == b.waypoints &&
        setEquals(a.hiddenWaypointIds, b.hiddenWaypointIds);
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

  List<Place> get _listPlaces {
    final geometry = widget.geometry;
    if (geometry == null || geometry.waypoints.isEmpty) return const [];
    return sortForList(
      placesOfChallenge(
        _controller.filtered,
        placeIds: geometry.revealedWaypoints.map(
          (waypoint) => waypoint.placeId,
        ),
        verifiedPlaceIds: context.read<AppServices>().verifiedPlaces.ids,
      ),
      _controller.userLocation,
    );
  }

  String _listEmptyLabel(AppStrings strings) {
    final geometry = widget.geometry;
    if (geometry == null || geometry.waypoints.isEmpty) {
      return strings.listNoChallenge;
    }
    return strings.monumentCount(0);
  }

  Future<void> _zoom(double delta) async {
    final update = delta > 0 ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut();
    await _map?.animateCamera(update);
  }

  Future<void> _locate() async {
    final here = await _controller.locate();
    if (here == null) return;
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(here.latitude, here.longitude), 14),
    );
  }

  Future<void> _onVerify(Place place) async {
    final waypoint = _waypointFor(place);
    if (waypoint != null) {
      final handler = widget.onVerifyWaypoint;
      if (handler != null) {
        await handler(waypoint, place);
        return;
      }
      await context.push<String?>(
        '/verify/${waypoint.challengeId}/${waypoint.id}',
        extra: place,
      );
      return;
    }
    await context.push('/verify/place/${place.id}', extra: place);
  }

  Waypoint? _waypointFor(Place place) {
    final geometry = widget.geometry;
    if (geometry == null) return null;
    return geometry.waypointMatching(place);
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

CameraPosition challengeCameraOf(
  List<Waypoint> waypoints, {
  List<ll.LatLng> anchors = const [],
}) {
  if (anchors.isNotEmpty) {
    return CameraPosition(
      target: LatLng(anchors.first.latitude, anchors.first.longitude),
      zoom: anchors.length > 1 ? 12 : 13,
    );
  }
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

void fitMapPoints(
  MapLibreMapController controller,
  List<ll.LatLng> points, {
  double padding = 32,
}) {
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
        left: padding,
        top: padding,
        right: padding,
        bottom: padding,
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
