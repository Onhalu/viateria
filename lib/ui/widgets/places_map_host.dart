import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../map/map_style_config.dart';
import '../../map/place_pin_icon.dart';
import '../../map/place.dart';
import '../../map/place_query.dart';
import '../../map/poi_source_sync.dart';
import '../../map/story_fog_icon.dart';
import '../../models/models.dart';
import '../../domain/story_fog.dart';

typedef PlaceTapCallback = void Function(Place place);
typedef ViewportCallback = void Function(GeoBounds bounds);

/// Challenge waypoints + PR7 route lines drawn on the shared MapLibre host.
class ChallengeMapGeometry {
  const ChallengeMapGeometry({
    required this.waypoints,
    this.selectedWaypointId,
    this.start,
    this.hikeLine = const [],
    this.bikeLine = const [],
    this.navigating,
    this.hiddenWaypointIds = const {},
    this.fogPins = const [],
  });

  final List<Waypoint> waypoints;
  final String? selectedWaypointId;
  final ll.LatLng? start;
  final List<ll.LatLng> hikeLine;
  final List<ll.LatLng> bikeLine;
  final TravelMode? navigating;

  /// Story stops whose true coordinates must not be drawn or fitted.
  final Set<String> hiddenWaypointIds;

  /// `?` markers. Empty in open mode.
  final List<StoryFogPin> fogPins;

  /// Stops that may show a category icon on their real place coordinate.
  List<Waypoint> get revealedWaypoints => [
    for (final waypoint in waypoints)
      if (!hiddenWaypointIds.contains(waypoint.id)) waypoint,
  ];

  /// Catalog place ids to drop from search and from the basemap pins.
  Set<String> get suppressedPlaceIds => {
    for (final waypoint in waypoints)
      if (hiddenWaypointIds.contains(waypoint.id))
        if (waypoint.placeId != null) waypoint.placeId!,
  };

  /// Fit targets: revealed true coordinates and fog pins. Locked GPS is absent.
  List<ll.LatLng> get overviewLatLngs => [
    for (final waypoint in revealedWaypoints) waypoint.latLng,
    for (final pin in fogPins)
      ll.LatLng(pin.position.latitude, pin.position.longitude),
  ];

  bool sameAs(ChallengeMapGeometry? other) {
    if (identical(this, other)) return true;
    if (other == null) return false;
    return waypoints == other.waypoints &&
        selectedWaypointId == other.selectedWaypointId &&
        start == other.start &&
        hikeLine == other.hikeLine &&
        bikeLine == other.bikeLine &&
        navigating == other.navigating &&
        setEquals(hiddenWaypointIds, other.hiddenWaypointIds) &&
        sameStoryFog(fogPins, other.fogPins);
  }

  /// Stop linked to [place] by `waypoints.place_id`. Proximity is not a match.
  ///
  /// Locked story stops are not a match, so a tap cannot pan to their GPS.
  Waypoint? waypointMatching(Place place) {
    for (final waypoint in revealedWaypoints) {
      final placeId = waypoint.placeId;
      if (placeId != null && placeId == place.id) return waypoint;
    }
    return null;
  }
}

/// Native MapLibre host: OSM style, památky by type, optional challenge overlay.
class PlacesMapHost extends StatefulWidget {
  const PlacesMapHost({
    super.key,
    required this.places,
    required this.initialCamera,
    this.onPlaceTap,
    this.onBackgroundTap,
    this.onViewportChanged,
    this.onReady,
    this.onLayersReady,
    this.onMapFailed,
    this.myLocationEnabled = false,
    this.geometry,
    this.onWaypointTap,
    this.onFogTap,
    this.selectedPlaceId,
    this.verifiedPlaceIds = const {},
    this.catalogRoute = const [],
    this.zoomGesturesEnabled = true,
  });

  final List<Place> places;
  final CameraPosition initialCamera;
  final PlaceTapCallback? onPlaceTap;
  final VoidCallback? onBackgroundTap;
  final ViewportCallback? onViewportChanged;
  final void Function(MapLibreMapController controller)? onReady;
  final void Function(MapLibreMapController controller)? onLayersReady;
  final VoidCallback? onMapFailed;
  final bool myLocationEnabled;
  final ChallengeMapGeometry? geometry;
  final ValueChanged<Waypoint>? onWaypointTap;

  /// Tap on a locked story `?`. The host does not move the camera.
  final ValueChanged<String>? onFogTap;
  final String? selectedPlaceId;
  final Set<String> verifiedPlaceIds;

  /// Ordered stops for a session route on the main map. Empty hides the line.
  final List<ll.LatLng> catalogRoute;

  /// Wheel / pinch zoom. Challenge detail on web turns this off.
  final bool zoomGesturesEnabled;

  @override
  State<PlacesMapHost> createState() => _PlacesMapHostState();
}

class _PlacesMapHostState extends State<PlacesMapHost> {
  MapLibreMapController? _controller;
  var _layersReady = false;
  var _challengeLayersReady = false;
  var _fogLayersReady = false;
  Timer? _moveEnd;
  Timer? _styleTimeout;
  final _poiGate = PoiSourceGate();

  @override
  void didUpdateWidget(covariant PlacesMapHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePlaceMarkers(oldWidget)) {
      unawaited(_pushPlaces(widget.places));
    }
    if (widget.geometry != null &&
        !widget.geometry!.sameAs(oldWidget.geometry)) {
      unawaited(_syncChallengeSources());
      unawaited(_syncFog());
    }
    if (!_challengeLayersReady &&
        widget.geometry != null &&
        _layersReady &&
        _controller != null) {
      unawaited(_ensureChallengeLayers(_controller!));
    }
    if (!listEquals(oldWidget.catalogRoute, widget.catalogRoute)) {
      unawaited(_syncCatalogRoute());
    }
  }

  @override
  void dispose() {
    _moveEnd?.cancel();
    _styleTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: MapStyleConfig.styleUrl,
      initialCameraPosition: widget.initialCamera,
      trackCameraPosition: true,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      zoomGesturesEnabled: widget.zoomGesturesEnabled,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      myLocationRenderMode: MyLocationRenderMode.normal,
      logoEnabled: false,
      scaleControlEnabled: true,
      scaleControlPosition: ScaleControlPosition.bottomLeft,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonMargins: const math.Point(8, 8),
      featureTapsTriggersMapClick: true,
      annotationOrder: const [],
      onMapCreated: (controller) {
        _controller = controller;
        widget.onReady?.call(controller);
        _styleTimeout?.cancel();
        _styleTimeout = Timer(const Duration(seconds: 12), () {
          if (!_layersReady && mounted) widget.onMapFailed?.call();
        });
      },
      onStyleLoadedCallback: () {
        unawaited(_onStyleLoaded());
      },
      onMapClick: (point, _) => unawaited(_onTap(point)),
      onCameraIdle: _onCameraIdle,
    );
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    _styleTimeout?.cancel();
    try {
      await _registerIcons(controller);
      await _installLayers(controller);
      if (widget.geometry != null) {
        await _ensureChallengeLayers(controller);
      }
      _layersReady = true;
      await _syncCatalogRoute();
      await _pushPlaces(widget.places);
      if (widget.geometry != null) {
        await _syncChallengeSources();
        await _syncFog();
      }
      await _syncViewport(controller);
      widget.onLayersReady?.call(controller);
    } catch (_) {
      widget.onMapFailed?.call();
    }
  }

  Future<void> _registerIcons(MapLibreMapController controller) async {
    const names = ['city', 'nature', 'technical', 'historical'];
    final glyphs = <String, Uint8List>{};
    for (final name in names) {
      final data = await rootBundle.load('assets/map/icons/$name@2x.png');
      glyphs[name] = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    }

    Future<void> addPin(String id, Uint8List png) {
      // Plastic bevels stay in the baked pin. sdf: false, no icon-color.
      return controller.addImage(id, png, false);
    }

    await addPin(
      MapStyleConfig.verifiedPinImageId,
      await placePinPng(spec: placePinSpec(MapStyleConfig.placeStateVerified)),
    );
    for (final name in names) {
      for (final state in const [
        MapStyleConfig.placeStateInChallenge,
        MapStyleConfig.placeStateOutside,
      ]) {
        final id = MapStyleConfig.pinImageId(name, state);
        final png = await placePinPng(
          spec: placePinSpec(state),
          glyphPng: glyphs[name],
        );
        await addPin(id, png);
      }
    }
  }

  Future<void> _installLayers(MapLibreMapController controller) async {
    await controller.addSource(
      MapStyleConfig.poiSourceId,
      GeojsonSourceProperties(
        data: featureCollectionOf(const []),
        promoteId: 'id',
      ),
    );

    // Each pin is one symbol: opaque disk, ring, and bevel. viewport-y draws
    // the pin lower on the screen after the pin above it. That mode ignores
    // symbol-sort-key, so the tapped pin is a second layer above this one.
    const pinSymbols = SymbolLayerProperties(
      iconImage: MapStyleConfig.pinImageExpression,
      iconSize: MapStyleConfig.markerSizeExpression,
      iconOpacity: 1,
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      symbolZOrder: 'viewport-y',
    );
    await controller.addSymbolLayer(
      MapStyleConfig.poiSourceId,
      MapStyleConfig.symbolLayerId,
      pinSymbols,
      filter: MapStyleConfig.backgroundPinFilter,
    );
    await controller.addSymbolLayer(
      MapStyleConfig.poiSourceId,
      MapStyleConfig.selectedSymbolLayerId,
      pinSymbols,
      filter: MapStyleConfig.foregroundPinFilter,
    );

    await controller.addSource(
      MapStyleConfig.catalogRouteSourceId,
      GeojsonSourceProperties(data: _emptyCollection()),
    );
    await controller.addLineLayer(
      MapStyleConfig.catalogRouteSourceId,
      MapStyleConfig.catalogRouteLayerId,
      const LineLayerProperties(
        lineColor: MapStyleConfig.forestHex,
        lineWidth: 4,
        lineOpacity: 0.8,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
  }

  Future<void> _syncCatalogRoute() async {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    final line = widget.catalogRoute;
    await _setSource(
      controller,
      MapStyleConfig.catalogRouteSourceId,
      line.length > 1 ? _lineCollection(line) : _emptyCollection(),
    );
  }

  Future<void> _ensureChallengeLayers(MapLibreMapController controller) async {
    if (_challengeLayersReady) return;
    await _installChallengeLayers(controller);
    _challengeLayersReady = true;
    await _syncChallengeSources();
  }

  Future<void> _installChallengeLayers(MapLibreMapController controller) async {
    await controller.addSource(
      MapStyleConfig.hikeSourceId,
      GeojsonSourceProperties(data: _emptyCollection()),
    );
    await controller.addSource(
      MapStyleConfig.bikeSourceId,
      GeojsonSourceProperties(data: _emptyCollection()),
    );
    await controller.addLineLayer(
      MapStyleConfig.bikeSourceId,
      MapStyleConfig.bikeLayerId,
      const LineLayerProperties(
        lineColor: MapStyleConfig.forestHex,
        lineWidth: 5,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await controller.addLineLayer(
      MapStyleConfig.hikeSourceId,
      MapStyleConfig.hikeLayerId,
      const LineLayerProperties(
        lineColor: MapStyleConfig.barkHex,
        lineWidth: 4,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
  }

  bool _samePlaceMarkers(PlacesMapHost oldWidget) {
    final previous = poiMarkerSignature(
      places: oldWidget.places,
      selectedId: oldWidget.selectedPlaceId,
      challengePlaceIds: _challengeIdsFor(oldWidget),
      verifiedPlaceIds: oldWidget.verifiedPlaceIds,
    );
    final next = poiMarkerSignature(
      places: widget.places,
      selectedId: widget.selectedPlaceId,
      challengePlaceIds: _challengeIdsFor(widget),
      verifiedPlaceIds: widget.verifiedPlaceIds,
    );
    return previous == next;
  }

  Set<String> _challengeIdsFor(PlacesMapHost host) {
    final geometry = host.geometry;
    if (geometry == null) return const {};
    return placeIdsInChallenge(
      host.places,
      placeIds: geometry.revealedWaypoints.map((waypoint) => waypoint.placeId),
    );
  }

  Future<void> _pushPlaces(List<Place> places) async {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    final challengePlaceIds = _challengePlaceIds(places);
    final signature = poiMarkerSignature(
      places: places,
      selectedId: widget.selectedPlaceId,
      challengePlaceIds: challengePlaceIds,
      verifiedPlaceIds: widget.verifiedPlaceIds,
    );
    if (!_poiGate.shouldReplace(signature)) return;
    await _setSource(
      controller,
      MapStyleConfig.poiSourceId,
      featureCollectionOf(
        places,
        selectedId: widget.selectedPlaceId,
        challengePlaceIds: challengePlaceIds,
        verifiedPlaceIds: widget.verifiedPlaceIds,
      ),
    );
  }

  Set<String> _challengePlaceIds(List<Place> places) {
    final geometry = widget.geometry;
    if (geometry == null) return const {};
    return placeIdsInChallenge(
      places,
      placeIds: geometry.revealedWaypoints.map((waypoint) => waypoint.placeId),
    );
  }

  Future<void> _syncChallengeSources() async {
    final controller = _controller;
    final geometry = widget.geometry;
    if (controller == null || !_challengeLayersReady || geometry == null) {
      return;
    }
    final navigating = geometry.navigating;
    final showBike =
        geometry.bikeLine.length > 1 &&
        (navigating == null || navigating == TravelMode.bike);
    final showHike =
        geometry.hikeLine.length > 1 &&
        (navigating == null || navigating == TravelMode.hike);
    await _setSource(
      controller,
      MapStyleConfig.bikeSourceId,
      showBike ? _lineCollection(geometry.bikeLine) : _emptyCollection(),
    );
    await _setSource(
      controller,
      MapStyleConfig.hikeSourceId,
      showHike ? _lineCollection(geometry.hikeLine) : _emptyCollection(),
    );
    if (navigating == TravelMode.bike) {
      await controller.setLayerProperties(
        MapStyleConfig.bikeLayerId,
        const LineLayerProperties(
          lineWidth: 7,
          lineColor: MapStyleConfig.forestHex,
        ),
      );
      await controller.setLayerProperties(
        MapStyleConfig.hikeLayerId,
        const LineLayerProperties(
          lineWidth: 4,
          lineColor: MapStyleConfig.barkHex,
        ),
      );
    } else if (navigating == TravelMode.hike) {
      await controller.setLayerProperties(
        MapStyleConfig.bikeLayerId,
        const LineLayerProperties(
          lineWidth: 5,
          lineColor: MapStyleConfig.forestHex,
        ),
      );
      await controller.setLayerProperties(
        MapStyleConfig.hikeLayerId,
        const LineLayerProperties(
          lineWidth: 6,
          lineColor: MapStyleConfig.barkHex,
        ),
      );
    }
  }

  Future<void> _setSource(
    MapLibreMapController controller,
    String id,
    Map<String, dynamic> geojson,
  ) async {
    try {
      await controller.setGeoJsonSource(id, geojson);
    } catch (_) {
      await controller.editGeoJsonSource(id, jsonEncode(geojson));
    }
  }

  Future<void> _syncFog() async {
    final controller = _controller;
    final geometry = widget.geometry;
    if (controller == null || !_layersReady || geometry == null) return;
    if (geometry.fogPins.isEmpty && !_fogLayersReady) return;
    if (!_fogLayersReady) {
      await _installFogLayers(controller);
      _fogLayersReady = true;
    }
    await _setSource(
      controller,
      MapStyleConfig.fogSourceId,
      _fogCollection(geometry.fogPins),
    );
  }

  Future<void> _installFogLayers(MapLibreMapController controller) async {
    final png = await storyQuestionMarkPng();
    await controller.addImage(MapStyleConfig.fogIconId, png);
    await controller.addSource(
      MapStyleConfig.fogSourceId,
      GeojsonSourceProperties(data: _emptyCollection()),
    );
    await controller.addSymbolLayer(
      MapStyleConfig.fogSourceId,
      MapStyleConfig.fogLayerId,
      const SymbolLayerProperties(
        iconImage: MapStyleConfig.fogIconId,
        iconSize: 0.36,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );
  }

  Map<String, dynamic> _fogCollection(List<StoryFogPin> pins) {
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final pin in pins)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [pin.position.longitude, pin.position.latitude],
            },
            'properties': {'waypointId': pin.waypointId},
          },
      ],
    };
  }

  Future<void> _onTap(math.Point<double> point) async {
    final controller = _controller;
    if (controller == null) return;

    if (_fogLayersReady) {
      final fogHits = await controller.queryRenderedFeatures(point, [
        MapStyleConfig.fogLayerId,
      ], null);
      if (fogHits.isNotEmpty) {
        final feature = _asMap(fogHits.first);
        final props = _asMap(feature['properties']);
        final waypointId = props['waypointId']?.toString();
        if (waypointId != null && waypointId.isNotEmpty) {
          widget.onFogTap?.call(waypointId);
        }
        return;
      }
    }

    final poiHits = await controller.queryRenderedFeatures(point, [
      MapStyleConfig.selectedSymbolLayerId,
      MapStyleConfig.symbolLayerId,
    ], null);
    if (poiHits.isEmpty) {
      widget.onBackgroundTap?.call();
      return;
    }
    final feature = _asMap(poiHits.first);
    final props = _asMap(feature['properties']);
    final id = props['id']?.toString();
    if (id == null) return;
    Place? match;
    for (final place in widget.places) {
      if (place.id == id) {
        match = place;
        break;
      }
    }
    if (match == null) return;
    widget.onPlaceTap?.call(match);
    final waypoint = widget.geometry?.waypointMatching(match);
    if (waypoint != null) widget.onWaypointTap?.call(waypoint);
  }

  void _onCameraIdle() {
    _moveEnd?.cancel();
    _moveEnd = Timer(MapStyleConfig.moveEndThrottle, () async {
      final controller = _controller;
      if (controller == null || !mounted) return;
      await _syncViewport(controller);
    });
  }

  Future<void> _syncViewport(MapLibreMapController controller) async {
    final bounds = await controller.getVisibleRegion();
    widget.onViewportChanged?.call(
      GeoBounds(
        south: bounds.southwest.latitude,
        west: bounds.southwest.longitude,
        north: bounds.northeast.latitude,
        east: bounds.northeast.longitude,
      ),
    );
  }

  Map<String, dynamic> _lineCollection(List<ll.LatLng> points) {
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in points) [p.longitude, p.latitude],
            ],
          },
          'properties': const {},
        },
      ],
    };
  }

  Map<String, dynamic> _emptyCollection() => {
    'type': 'FeatureCollection',
    'features': const [],
  };

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}

class MapFallbackCanvas extends StatelessWidget {
  const MapFallbackCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: Key('map-canvas-fallback'),
      color: Color(0xFFD8CDB8),
    );
  }
}
