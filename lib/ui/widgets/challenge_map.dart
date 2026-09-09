import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../map/map_runtime.dart';
import '../../map/map_style_config.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class ChallengeMap extends StatefulWidget {
  const ChallengeMap({
    super.key,
    required this.waypoints,
    this.height = 280,
    this.selectedWaypointId,
    this.start,
    this.hikeLine = const [],
    this.bikeLine = const [],
    this.onWaypointTap,
    this.actions = const [],
    this.navigating,
    this.navigationBanner,
  });

  final List<Waypoint> waypoints;
  final double height;
  final String? selectedWaypointId;
  final ll.LatLng? start;
  final List<ll.LatLng> hikeLine;
  final List<ll.LatLng> bikeLine;
  final ValueChanged<Waypoint>? onWaypointTap;
  final List<Widget> actions;
  final TravelMode? navigating;
  final Widget? navigationBanner;

  @override
  State<ChallengeMap> createState() => _ChallengeMapState();
}

class _ChallengeMapState extends State<ChallengeMap> {
  MapLibreMapController? _controller;
  var _layersReady = false;
  LatLng? _savedCenter;
  double? _savedZoom;

  static const _hikeSource = 'challenge-hike';
  static const _bikeSource = 'challenge-bike';
  static const _pointsSource = 'challenge-points';
  static const _hikeLayer = 'challenge-hike-line';
  static const _bikeLayer = 'challenge-bike-line';
  static const _circleLayer = 'challenge-circles';
  static const _labelLayer = 'challenge-labels';

  @override
  void didUpdateWidget(covariant ChallengeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final navChanged = oldWidget.navigating != widget.navigating;
    final geometryChanged =
        oldWidget.hikeLine != widget.hikeLine ||
        oldWidget.bikeLine != widget.bikeLine ||
        oldWidget.start != widget.start ||
        oldWidget.selectedWaypointId != widget.selectedWaypointId ||
        oldWidget.waypoints != widget.waypoints;
    if (!geometryChanged && !navChanged) return;
    unawaited(_syncSources());
    if (navChanged) {
      if (oldWidget.navigating == null && widget.navigating != null) {
        _saveCamera();
        _fitActive();
      } else if (widget.navigating == null) {
        _restoreCamera();
      } else {
        _fitActive();
      }
    } else if (widget.navigating != null) {
      _fitActive();
    } else {
      _fitOverview();
    }
  }

  List<ll.LatLng> get _activeLine {
    switch (widget.navigating) {
      case TravelMode.hike:
        return widget.hikeLine;
      case TravelMode.bike:
        return widget.bikeLine;
      case null:
        return const [];
    }
  }

  void _saveCamera() {
    final camera = _controller?.cameraPosition;
    if (camera == null) return;
    _savedCenter = camera.target;
    _savedZoom = camera.zoom;
  }

  void _restoreCamera() {
    final center = _savedCenter;
    final zoom = _savedZoom;
    _savedCenter = null;
    _savedZoom = null;
    final controller = _controller;
    if (controller != null && center != null && zoom != null) {
      unawaited(
        controller.animateCamera(CameraUpdate.newLatLngZoom(center, zoom)),
      );
      return;
    }
    _fitOverview();
  }

  void _fitOverview() {
    _fitPoints([
      for (final waypoint in widget.waypoints) waypoint.latLng,
      if (widget.start != null) widget.start!,
      ...widget.hikeLine,
      ...widget.bikeLine,
    ]);
  }

  void _fitActive() {
    _fitPoints([..._activeLine, if (widget.start != null) widget.start!]);
  }

  void _fitPoints(List<ll.LatLng> points) {
    final controller = _controller;
    if (controller == null || !_layersReady || points.isEmpty) return;
    if (points.length == 1) {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_toMl(points.first), 13),
        ),
      );
      return;
    }
    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          _boundsOf(points),
          left: 32,
          top: 32,
          right: 32,
          bottom: 32,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapBody = !MapRuntime.shouldEmbed(context)
        ? const SizedBox.expand()
        : _map();
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          mapBody,
          if (widget.navigationBanner != null)
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: widget.navigationBanner!,
            ),
          if (widget.actions.isNotEmpty)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Wrap(
                key: const Key('route-map-nav-actions'),
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: widget.actions,
              ),
            ),
        ],
      ),
    );
  }

  Widget _map() {
    final ordered = [...widget.waypoints]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final center = ordered.isEmpty
        ? MapStyleConfig.prague
        : _toMl(ordered.first.latLng);
    return MapLibreMap(
      styleString: MapStyleConfig.styleUrl,
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: ordered.length > 1 ? 12 : 13,
      ),
      trackCameraPosition: true,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      logoEnabled: false,
      scaleControlEnabled: true,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonMargins: const math.Point(4, 4),
      featureTapsTriggersMapClick: true,
      annotationOrder: const [],
      onMapCreated: (controller) => _controller = controller,
      onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
      onMapClick: (point, _) => unawaited(_onTap(point)),
    );
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.addSource(
        _hikeSource,
        GeojsonSourceProperties(data: _emptyCollection()),
      );
      await controller.addSource(
        _bikeSource,
        GeojsonSourceProperties(data: _emptyCollection()),
      );
      await controller.addSource(
        _pointsSource,
        GeojsonSourceProperties(data: _emptyCollection()),
      );
      await controller.addLineLayer(
        _bikeSource,
        _bikeLayer,
        LineLayerProperties(
          lineColor: _hex(AppTheme.gold),
          lineWidth: widget.navigating == TravelMode.bike ? 7 : 5,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      await controller.addLineLayer(
        _hikeSource,
        _hikeLayer,
        LineLayerProperties(
          lineColor: _hex(AppTheme.moss),
          lineWidth: widget.navigating == TravelMode.hike ? 6 : 4,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      await controller.addCircleLayer(
        _pointsSource,
        _circleLayer,
        const CircleLayerProperties(
          circleRadius: 16,
          circleColor: [
            Expressions.match,
            [Expressions.get, 'kind'],
            'selected',
            '#D4A017',
            'start',
            '#1B4332',
            '#2D6A4F',
          ],
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
      );
      await controller.addSymbolLayer(
        _pointsSource,
        _labelLayer,
        const SymbolLayerProperties(
          textField: [Expressions.get, 'label'],
          textSize: 12,
          textColor: [
            Expressions.match,
            [Expressions.get, 'kind'],
            'selected',
            '#3D2914',
            '#FFFFFF',
          ],
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
      );
      _layersReady = true;
      await _syncSources();
      if (widget.navigating != null) {
        _fitActive();
      } else {
        _fitOverview();
      }
    } catch (_) {
      // Native map failed to style; overlays still render.
    }
  }

  Future<void> _syncSources() async {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    final navigating = widget.navigating;
    final showBike =
        widget.bikeLine.length > 1 &&
        (navigating == null || navigating == TravelMode.bike);
    final showHike =
        widget.hikeLine.length > 1 &&
        (navigating == null || navigating == TravelMode.hike);
    await _setSource(
      controller,
      _bikeSource,
      showBike ? _lineCollection(widget.bikeLine) : _emptyCollection(),
    );
    await _setSource(
      controller,
      _hikeSource,
      showHike ? _lineCollection(widget.hikeLine) : _emptyCollection(),
    );
    await _setSource(controller, _pointsSource, _pointsCollection());
    if (navigating == TravelMode.bike) {
      await controller.setLayerProperties(
        _bikeLayer,
        LineLayerProperties(lineWidth: 7, lineColor: _hex(AppTheme.gold)),
      );
      await controller.setLayerProperties(
        _hikeLayer,
        LineLayerProperties(lineWidth: 4, lineColor: _hex(AppTheme.moss)),
      );
    } else if (navigating == TravelMode.hike) {
      await controller.setLayerProperties(
        _bikeLayer,
        LineLayerProperties(lineWidth: 5, lineColor: _hex(AppTheme.gold)),
      );
      await controller.setLayerProperties(
        _hikeLayer,
        LineLayerProperties(lineWidth: 6, lineColor: _hex(AppTheme.moss)),
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
    final onTap = widget.onWaypointTap;
    if (controller == null || onTap == null) return;
    final hits = await controller.queryRenderedFeatures(point, [
      _circleLayer,
      _labelLayer,
    ], null);
    if (hits.isEmpty) return;
    final feature = hits.first is Map
        ? Map<String, dynamic>.from(hits.first as Map)
        : const <String, dynamic>{};
    final props = feature['properties'] is Map
        ? Map<String, dynamic>.from(feature['properties'] as Map)
        : const <String, dynamic>{};
    final id = props['id']?.toString();
    if (id == null) return;
    for (final waypoint in widget.waypoints) {
      if (waypoint.id == id) {
        onTap(waypoint);
        return;
      }
    }
  }

  Map<String, dynamic> _pointsCollection() {
    final features = <Map<String, dynamic>>[];
    if (widget.start != null) {
      features.add(
        _pointFeature(
          id: 'start',
          point: widget.start!,
          label: 'S',
          kind: 'start',
        ),
      );
    }
    final ordered = [...widget.waypoints]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final waypoint in ordered) {
      features.add(
        _pointFeature(
          id: waypoint.id,
          point: waypoint.latLng,
          label: '${waypoint.sortOrder + 1}',
          kind: waypoint.id == widget.selectedWaypointId ? 'selected' : 'stop',
        ),
      );
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  Map<String, dynamic> _pointFeature({
    required String id,
    required ll.LatLng point,
    required String label,
    required String kind,
  }) {
    return {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': [point.longitude, point.latitude],
      },
      'properties': {'id': id, 'label': label, 'kind': kind},
    };
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

  LatLng _toMl(ll.LatLng point) => LatLng(point.latitude, point.longitude);

  LatLngBounds _boundsOf(List<ll.LatLng> points) {
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

  String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }
}
