import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  final LatLng? start;
  final List<LatLng> hikeLine;
  final List<LatLng> bikeLine;
  final ValueChanged<Waypoint>? onWaypointTap;
  final List<Widget> actions;
  final TravelMode? navigating;
  final Widget? navigationBanner;

  @override
  State<ChallengeMap> createState() => _ChallengeMapState();
}

class _ChallengeMapState extends State<ChallengeMap> {
  final _controller = MapController();
  var _ready = false;
  LatLng? _savedCenter;
  double? _savedZoom;

  @override
  void didUpdateWidget(covariant ChallengeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final navChanged = oldWidget.navigating != widget.navigating;
    final geometryChanged =
        oldWidget.hikeLine != widget.hikeLine ||
        oldWidget.bikeLine != widget.bikeLine ||
        oldWidget.start != widget.start ||
        oldWidget.selectedWaypointId != widget.selectedWaypointId;
    if (navChanged) {
      if (oldWidget.navigating == null && widget.navigating != null) {
        _saveCamera();
        _fitActive();
      } else if (widget.navigating == null) {
        _restoreCamera();
      } else {
        _fitActive();
      }
    } else if (geometryChanged) {
      if (widget.navigating != null) {
        _fitActive();
      } else {
        _fitOverview();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<LatLng> get _activeLine {
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
    if (!_ready) return;
    try {
      final camera = _controller.camera;
      _savedCenter = camera.center;
      _savedZoom = camera.zoom;
    } catch (_) {
      // Map may not have a size yet.
    }
  }

  void _restoreCamera() {
    final center = _savedCenter;
    final zoom = _savedZoom;
    _savedCenter = null;
    _savedZoom = null;
    if (!_ready) return;
    if (center != null && zoom != null) {
      try {
        _controller.move(center, zoom);
        return;
      } catch (_) {
        // Fall through to overview fit.
      }
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

  void _fitPoints(List<LatLng> points) {
    if (!_ready || points.length < 2) return;
    try {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(32),
        ),
      );
    } catch (_) {
      // Map may not have a size yet; onMapReady retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapBody = !TickerMode.valuesOf(context).enabled
        ? const SizedBox.expand()
        : _map(context);
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

  Widget _map(BuildContext context) {
    final ordered = [...widget.waypoints]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final center = ordered.isEmpty
        ? const LatLng(50.0755, 14.4378)
        : ordered.first.latLng;
    final scheme = Theme.of(context).colorScheme;
    final navigating = widget.navigating;
    final showBike =
        widget.bikeLine.length > 1 &&
        (navigating == null || navigating == TravelMode.bike);
    final showHike =
        widget.hikeLine.length > 1 &&
        (navigating == null || navigating == TravelMode.hike);
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: ordered.length > 1 ? 12 : 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _ready = true;
          if (widget.navigating != null) {
            _fitActive();
          } else {
            _fitOverview();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.viateria.viateria',
        ),
        if (showBike)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.bikeLine,
                color: AppTheme.gold.withValues(
                  alpha: navigating == TravelMode.bike ? 1 : 0.9,
                ),
                strokeWidth: navigating == TravelMode.bike ? 7 : 5,
              ),
            ],
          ),
        if (showHike)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.hikeLine,
                color: scheme.primary,
                strokeWidth: navigating == TravelMode.hike ? 6 : 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.start != null)
              Marker(
                point: widget.start!,
                width: 40,
                height: 40,
                child: const Icon(Icons.flag, color: AppTheme.forest, size: 32),
              ),
            for (final waypoint in ordered)
              Marker(
                point: waypoint.latLng,
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: widget.onWaypointTap == null
                      ? null
                      : () => widget.onWaypointTap!(waypoint),
                  child: CircleAvatar(
                    backgroundColor: waypoint.id == widget.selectedWaypointId
                        ? AppTheme.gold
                        : scheme.primary,
                    child: Text(
                      '${waypoint.sortOrder + 1}',
                      style: TextStyle(
                        color: waypoint.id == widget.selectedWaypointId
                            ? AppTheme.bark
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
