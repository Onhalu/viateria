import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../map/place_catalog.dart';
import '../../models/models.dart';
import 'places_map_host.dart';
import 'places_map_surface.dart';

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
    this.catalog,
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
  final PlaceCatalog? catalog;

  @override
  State<ChallengeMap> createState() => _ChallengeMapState();
}

class _ChallengeMapState extends State<ChallengeMap> {
  MapLibreMapController? _controller;
  var _layersReady = false;
  LatLng? _savedCenter;
  double? _savedZoom;

  ChallengeMapGeometry get _geometry => ChallengeMapGeometry(
    waypoints: widget.waypoints,
    selectedWaypointId: widget.selectedWaypointId,
    start: widget.start,
    hikeLine: widget.hikeLine,
    bikeLine: widget.bikeLine,
    navigating: widget.navigating,
  );

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
      controller.animateCamera(CameraUpdate.newLatLngZoom(center, zoom));
      return;
    }
    _fitOverview();
  }

  void _fitOverview() {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    fitChallengeCamera(
      controller,
      waypoints: widget.waypoints,
      start: widget.start,
      hikeLine: widget.hikeLine,
      bikeLine: widget.bikeLine,
    );
  }

  void _fitActive() {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    fitMapPoints(controller, [..._activeLine, ?widget.start]);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: PlacesMapSurface(
          catalog: widget.catalog,
          compact: true,
          safeArea: false,
          initialCamera: challengeCameraOf(widget.waypoints),
          geometry: _geometry,
          onWaypointTap: widget.onWaypointTap,
          onReady: (controller) => _controller = controller,
          onLayersReady: (controller) {
            _controller = controller;
            _layersReady = true;
            if (widget.navigating != null) {
              _fitActive();
            } else {
              _fitOverview();
            }
          },
          overlayTop: widget.navigationBanner,
          overlayActions: widget.actions,
        ),
      ),
    );
  }
}
