import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/map/map_style_config.dart';
import '../../../../core/theme/map_colors.dart';
import '../../application/map_providers.dart';
import '../../data/camera_store.dart';
import '../../domain/poi.dart';

typedef MapReadyCallback = void Function(MapLibreMapController controller);

/// Native MapLibre host: OSM style, clustered GeoJSON symbols, camera persist.
class MapLibreHost extends ConsumerStatefulWidget {
  const MapLibreHost({
    super.key,
    required this.initialCamera,
    this.onReady,
    this.onMapFailed,
  });

  final CameraPosition initialCamera;
  final MapReadyCallback? onReady;
  final VoidCallback? onMapFailed;

  @override
  ConsumerState<MapLibreHost> createState() => _MapLibreHostState();
}

class _MapLibreHostState extends ConsumerState<MapLibreHost> {
  MapLibreMapController? _controller;
  bool _layersReady = false;
  Timer? _moveEnd;
  Timer? _styleTimeout;

  @override
  void dispose() {
    _moveEnd?.cancel();
    _styleTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationOn = ref.watch(myLocationEnabledProvider);
    ref.listen<List<Poi>>(filteredPoisProvider, (prev, next) {
      unawaited(_pushPois(next));
    });

    return MapLibreMap(
      styleString: MapStyleConfig.styleUrl,
      initialCameraPosition: widget.initialCamera,
      trackCameraPosition: true,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      myLocationEnabled: locationOn,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      myLocationRenderMode: MyLocationRenderMode.normal,
      logoEnabled: false,
      scaleControlEnabled: true,
      scaleControlPosition: ScaleControlPosition.bottomLeft,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      // Park native attribution above the nav / sheet peek.
      attributionButtonMargins: const math.Point(8, 96),
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
      onCameraIdle: () => _onCameraIdle(),
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
      await _pushPois(ref.read(filteredPoisProvider));
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
      MapStyleConfig.symbolLayerId,
      const SymbolLayerProperties(
        iconImage: [
          Expressions.get,
          'icon',
        ],
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

  Future<void> _pushPois(List<Poi> pois) async {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    final geojson = featureCollectionOf(pois);
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

    final clusterHits = await controller.queryRenderedFeatures(
      point,
      [MapStyleConfig.clusterLayerId],
      null,
    );
    if (clusterHits.isNotEmpty) {
      await _expandCluster(controller, clusterHits.first);
      return;
    }

    final poiHits = await controller.queryRenderedFeatures(
      point,
      [MapStyleConfig.symbolLayerId],
      null,
    );
    if (poiHits.isEmpty) {
      ref.read(selectedPoiProvider.notifier).clear();
      return;
    }
    final feature = _asMap(poiHits.first);
    final props = _asMap(feature['properties']);
    final id = props['id']?.toString();
    if (id == null) return;
    final catalog = ref.read(filteredPoisProvider);
    Poi? match;
    for (final poi in catalog) {
      if (poi.id == id) {
        match = poi;
        break;
      }
    }
    ref.read(selectedPoiProvider.notifier).select(match);
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
      await _persistCamera(controller);
    });
  }

  Future<void> _syncViewport(MapLibreMapController controller) async {
    final bounds = await controller.getVisibleRegion();
    ref.read(viewportProvider.notifier).setBounds(
      GeoBounds(
        south: bounds.southwest.latitude,
        west: bounds.southwest.longitude,
        north: bounds.northeast.latitude,
        east: bounds.northeast.longitude,
      ),
    );
  }

  Future<void> _persistCamera(MapLibreMapController controller) async {
    final camera = controller.cameraPosition;
    if (camera == null) return;
    await ref.read(cameraStoreProvider).save(
      SavedCamera(
        target: GeoPoint(camera.target.latitude, camera.target.longitude),
        zoom: camera.zoom,
        bearing: camera.bearing,
        tilt: camera.tilt,
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

class MapScaleBar extends StatelessWidget {
  const MapScaleBar({super.key, required this.zoom, required this.latitude});

  final double zoom;
  final double latitude;

  @override
  Widget build(BuildContext context) {
    final metersPerPx =
        156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
    const candidates = [
      20.0,
      50.0,
      100.0,
      200.0,
      500.0,
      1000.0,
      2000.0,
      5000.0,
      10000.0,
      20000.0,
    ];
    var meters = candidates.last;
    for (final c in candidates) {
      if (c / metersPerPx >= 48 && c / metersPerPx <= 120) {
        meters = c;
        break;
      }
    }
    final width = (meters / metersPerPx).clamp(48.0, 140.0);
    final label = meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(meters % 1000 == 0 ? 0 : 1)} km'
        : '${meters.round()} m';
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.white, blurRadius: 4)],
            ),
          ),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: MapColors.surface,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class OsmAttributionChip extends StatelessWidget {
  const OsmAttributionChip({super.key, required this.label, required this.longLabel});

  final String label;
  final String longLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MapColors.surfaceFill,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const Key('map-osm-attribution'),
        customBorder: const StadiumBorder(),
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(label),
              content: Text(longLabel),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.info_outline, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
