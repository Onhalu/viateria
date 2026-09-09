import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../map/map_style_config.dart';
import '../../map/place.dart';

typedef PlaceTapCallback = void Function(Place place);
typedef ViewportCallback = void Function(GeoBounds bounds);

/// Native MapLibre host for the places map: OSM style, clustered GeoJSON.
class PlacesMapHost extends StatefulWidget {
  const PlacesMapHost({
    super.key,
    required this.places,
    required this.initialCamera,
    this.onPlaceTap,
    this.onBackgroundTap,
    this.onViewportChanged,
    this.onReady,
    this.onMapFailed,
    this.myLocationEnabled = false,
  });

  final List<Place> places;
  final CameraPosition initialCamera;
  final PlaceTapCallback? onPlaceTap;
  final VoidCallback? onBackgroundTap;
  final ViewportCallback? onViewportChanged;
  final void Function(MapLibreMapController controller)? onReady;
  final VoidCallback? onMapFailed;
  final bool myLocationEnabled;

  @override
  State<PlacesMapHost> createState() => _PlacesMapHostState();
}

class _PlacesMapHostState extends State<PlacesMapHost> {
  MapLibreMapController? _controller;
  var _layersReady = false;
  Timer? _moveEnd;
  Timer? _styleTimeout;

  @override
  void didUpdateWidget(covariant PlacesMapHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.places != widget.places) {
      unawaited(_pushPlaces(widget.places));
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
      _layersReady = true;
      await _pushPlaces(widget.places);
      await _syncViewport(controller);
    } catch (_) {
      widget.onMapFailed?.call();
    }
  }

  Future<void> _registerIcons(MapLibreMapController controller) async {
    const names = ['castle', 'chateau', 'ruin', 'church', 'other', 'cluster'];
    for (final name in names) {
      final data = await rootBundle.load('assets/map/icons/$name@2x.png');
      await controller.addImage(name, data.buffer.asUint8List());
    }
  }

  Future<void> _installLayers(MapLibreMapController controller) async {
    await controller.addSource(
      MapStyleConfig.poiSourceId,
      GeojsonSourceProperties(
        data: featureCollectionOf(const []),
        cluster: true,
        clusterRadius: MapStyleConfig.clusterRadius.toDouble(),
        clusterMaxZoom: MapStyleConfig.clusterMaxZoom.toDouble(),
        promoteId: 'id',
      ),
    );

    await controller.addSymbolLayer(
      MapStyleConfig.poiSourceId,
      MapStyleConfig.clusterLayerId,
      const SymbolLayerProperties(
        iconImage: 'cluster',
        iconSize: 1.0,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: ['has', 'point_count'],
    );

    await controller.addSymbolLayer(
      MapStyleConfig.poiSourceId,
      MapStyleConfig.clusterCountLayerId,
      const SymbolLayerProperties(
        textField: [Expressions.get, 'point_count'],
        textSize: 12,
        textColor: '#3D2914',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: ['has', 'point_count'],
    );

    await controller.addSymbolLayer(
      MapStyleConfig.poiSourceId,
      MapStyleConfig.symbolLayerId,
      const SymbolLayerProperties(
        iconImage: [Expressions.get, 'icon'],
        iconSize: 1.0,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    );
  }

  Future<void> _pushPlaces(List<Place> places) async {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    final geojson = featureCollectionOf(places);
    try {
      await controller.setGeoJsonSource(MapStyleConfig.poiSourceId, geojson);
    } catch (_) {
      await controller.editGeoJsonSource(
        MapStyleConfig.poiSourceId,
        jsonEncode(geojson),
      );
    }
  }

  Future<void> _onTap(math.Point<double> point) async {
    final controller = _controller;
    if (controller == null) return;

    final clusterHits = await controller.queryRenderedFeatures(point, [
      MapStyleConfig.clusterLayerId,
    ], null);
    if (clusterHits.isNotEmpty) {
      await _expandCluster(controller, clusterHits.first);
      return;
    }

    final poiHits = await controller.queryRenderedFeatures(point, [
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
    if (match != null) widget.onPlaceTap?.call(match);
  }

  Future<void> _expandCluster(
    MapLibreMapController controller,
    Object raw,
  ) async {
    final feature = _asMap(raw);
    final props = _asMap(feature['properties']);
    final clusterId = (props['cluster_id'] as num?)?.toInt();
    if (clusterId == null) return;
    final zoom = await controller.getClusterExpansionZoom(
      MapStyleConfig.poiSourceId,
      clusterId,
    );
    final coords = _asMap(feature['geometry'])['coordinates'];
    if (coords is! List || coords.length < 2) return;
    final lng = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom.toDouble() + 0.4),
    );
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
      color: Color(0xFFD7D2C8),
    );
  }
}
