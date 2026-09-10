import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../map/map_icons.dart';
import '../../map/map_style_config.dart';
import '../../map/place.dart';
import '../../map/place_query.dart';
import '../../models/models.dart';

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
  });

  final List<Waypoint> waypoints;
  final String? selectedWaypointId;
  final ll.LatLng? start;
  final List<ll.LatLng> hikeLine;
  final List<ll.LatLng> bikeLine;
  final TravelMode? navigating;

  bool sameAs(ChallengeMapGeometry? other) {
    if (identical(this, other)) return true;
    if (other == null) return false;
    return waypoints == other.waypoints &&
        selectedWaypointId == other.selectedWaypointId &&
        start == other.start &&
        hikeLine == other.hikeLine &&
        bikeLine == other.bikeLine &&
        navigating == other.navigating;
  }

  Waypoint? waypointMatching(Place place, {double radiusKm = 0.2}) {
    for (final waypoint in waypoints) {
      if (waypoint.id == place.id) return waypoint;
      if (distanceKm(place.location, GeoPoint(waypoint.lat, waypoint.lng)) <=
          radiusKm) {
        return waypoint;
      }
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
    this.selectedPlaceId,
    this.verifiedPlaceIds = const {},
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
  final String? selectedPlaceId;
  final Set<String> verifiedPlaceIds;

  @override
  State<PlacesMapHost> createState() => _PlacesMapHostState();
}

class _PlacesMapHostState extends State<PlacesMapHost> {
  MapLibreMapController? _controller;
  var _layersReady = false;
  var _challengeLayersReady = false;
  Timer? _moveEnd;
  Timer? _styleTimeout;

  @override
  void didUpdateWidget(covariant PlacesMapHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.places != widget.places ||
        oldWidget.selectedPlaceId != widget.selectedPlaceId ||
        !_sameChallengeMembership(oldWidget.geometry, widget.geometry) ||
        !setEquals(oldWidget.verifiedPlaceIds, widget.verifiedPlaceIds)) {
      unawaited(_pushPlaces(widget.places));
    }
    if (widget.geometry != null &&
        !widget.geometry!.sameAs(oldWidget.geometry)) {
      unawaited(_syncChallengeSources());
    }
    if (!_challengeLayersReady &&
        widget.geometry != null &&
        _layersReady &&
        _controller != null) {
      unawaited(_ensureChallengeLayers(_controller!));
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
      await _pushPlaces(widget.places);
      if (widget.geometry != null) {
        await _syncChallengeSources();
      }
      await _syncViewport(controller);
      widget.onLayersReady?.call(controller);
    } catch (_) {
      widget.onMapFailed?.call();
    }
  }

  Future<void> _registerIcons(MapLibreMapController controller) async {
    const names = ['city', 'nature', 'technical', 'historical'];
    for (final name in names) {
      final data = await rootBundle.load('assets/map/icons/$name@2x.png');
      final sdf = await sdfSilhouettePng(data.buffer.asUint8List());
      await controller.addImage(name, sdf, true);
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

    await controller.addCircleLayer(
      MapStyleConfig.poiSourceId,
      MapStyleConfig.diskLayerId,
      const CircleLayerProperties(
        circleRadius: MapStyleConfig.diskRadiusExpression,
        circleColor: MapStyleConfig.diskFillExpression,
        circleOpacity: 1,
        circleStrokeWidth: MapStyleConfig.diskStrokeWidthExpression,
        circleStrokeColor: MapStyleConfig.diskStrokeColorExpression,
        circleStrokeOpacity: 1,
        circlePitchAlignment: 'viewport',
        circlePitchScale: 'viewport',
      ),
    );

    await controller.addSymbolLayer(
      MapStyleConfig.poiSourceId,
      MapStyleConfig.symbolLayerId,
      const SymbolLayerProperties(
        iconImage: [Expressions.get, 'icon'],
        iconSize: MapStyleConfig.markerSizeExpression,
        iconColor: MapStyleConfig.markerColorExpression,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
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

  Future<void> _pushPlaces(List<Place> places) async {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    await _setSource(
      controller,
      MapStyleConfig.poiSourceId,
      featureCollectionOf(
        places,
        selectedId: widget.selectedPlaceId,
        challengePlaceIds: _challengePlaceIds(places),
        verifiedPlaceIds: widget.verifiedPlaceIds,
      ),
    );
  }

  Set<String> _challengePlaceIds(List<Place> places) {
    final geometry = widget.geometry;
    if (geometry == null) return const {};
    return placeIdsInChallenge(
      places,
      waypointIds: geometry.waypoints.map((waypoint) => waypoint.id),
      waypointLocations: geometry.waypoints.map(
        (waypoint) => GeoPoint(waypoint.lat, waypoint.lng),
      ),
    );
  }

  bool _sameChallengeMembership(
    ChallengeMapGeometry? a,
    ChallengeMapGeometry? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.waypoints == b.waypoints;
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

  Future<void> _onTap(math.Point<double> point) async {
    final controller = _controller;
    if (controller == null) return;

    final poiHits = await controller.queryRenderedFeatures(point, [
      MapStyleConfig.symbolLayerId,
      MapStyleConfig.diskLayerId,
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
