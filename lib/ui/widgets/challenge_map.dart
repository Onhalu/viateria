import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../domain/story_fog.dart';
import '../../theme/brand_colors.dart';
import '../../map/place.dart';
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
    this.onVerifyWaypoint,
    this.onFogTap,
    this.hiddenWaypointIds = const {},
    this.fogPins = const [],
    this.actions = const [],
    this.navigating,
    this.navigationBanner,
    this.catalog,
    this.cooperativeGestures = false,
    this.zoomGesturesEnabled = true,
    this.onExpand,
    this.expandLabel,
  });

  final List<Waypoint> waypoints;
  final double height;
  final String? selectedWaypointId;
  final ll.LatLng? start;
  final List<ll.LatLng> hikeLine;
  final List<ll.LatLng> bikeLine;
  final ValueChanged<Waypoint>? onWaypointTap;
  final Future<void> Function(Waypoint waypoint, Place place)? onVerifyWaypoint;
  final ValueChanged<String>? onFogTap;
  final Set<String> hiddenWaypointIds;
  final List<StoryFogPin> fogPins;
  final List<Widget> actions;
  final TravelMode? navigating;
  final Widget? navigationBanner;
  final PlaceCatalog? catalog;
  final bool cooperativeGestures;
  final bool zoomGesturesEnabled;
  final VoidCallback? onExpand;
  final String? expandLabel;

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
    hiddenWaypointIds: widget.hiddenWaypointIds,
    fogPins: widget.fogPins,
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
        oldWidget.waypoints != widget.waypoints ||
        oldWidget.hiddenWaypointIds != widget.hiddenWaypointIds ||
        !sameStoryFog(oldWidget.fogPins, widget.fogPins);
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
    fitMapPoints(controller, [
      ..._geometry.overviewLatLngs,
      ?widget.start,
      ...widget.hikeLine,
      ...widget.bikeLine,
    ], padding: 48);
  }

  void _fitActive() {
    final controller = _controller;
    if (controller == null || !_layersReady) return;
    fitMapPoints(controller, [..._activeLine, ?widget.start], padding: 48);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PlacesMapSurface(
              catalog: widget.catalog,
              compact: true,
              safeArea: false,
              waypointsOnly: true,
              cooperativeGestures: widget.cooperativeGestures,
              zoomGesturesEnabled: widget.zoomGesturesEnabled,
              initialCamera: challengeCameraOf(
                widget.waypoints,
                anchors: _geometry.overviewLatLngs,
              ),
              geometry: _geometry,
              onWaypointTap: widget.onWaypointTap,
              onVerifyWaypoint: widget.onVerifyWaypoint,
              onFogTap: widget.onFogTap,
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
            if (widget.onExpand != null && widget.expandLabel != null)
              Positioned(
                top: 8,
                right: 8,
                child: _ExpandMapButton(
                  label: widget.expandLabel!,
                  onPressed: widget.onExpand!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpandMapButton extends StatelessWidget {
  const _ExpandMapButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandColors.cream.withValues(alpha: 0.95),
      elevation: 1,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const Key('challenge-expand-map'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.open_in_full,
                  size: 18,
                  color: BrandColors.forest,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: BrandColors.forest,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
