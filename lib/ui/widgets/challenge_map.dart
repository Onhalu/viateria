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
  });

  final List<Waypoint> waypoints;
  final double height;
  final String? selectedWaypointId;
  final LatLng? start;
  final List<LatLng> hikeLine;
  final List<LatLng> bikeLine;
  final ValueChanged<Waypoint>? onWaypointTap;

  @override
  State<ChallengeMap> createState() => _ChallengeMapState();
}

class _ChallengeMapState extends State<ChallengeMap> {
  final _controller = MapController();
  var _ready = false;

  @override
  void didUpdateWidget(covariant ChallengeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hikeLine != widget.hikeLine ||
        oldWidget.bikeLine != widget.bikeLine ||
        oldWidget.start != widget.start ||
        oldWidget.selectedWaypointId != widget.selectedWaypointId) {
      _fit();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fit() {
    if (!_ready) return;
    final points = <LatLng>[
      for (final waypoint in widget.waypoints) waypoint.latLng,
      if (widget.start != null) widget.start!,
      ...widget.hikeLine,
      ...widget.bikeLine,
    ];
    if (points.length < 2) return;
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
    if (!TickerMode.valuesOf(context).enabled) {
      return SizedBox(height: widget.height);
    }
    final ordered = [...widget.waypoints]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final center = ordered.isEmpty
        ? const LatLng(50.0755, 14.4378)
        : ordered.first.latLng;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: ordered.length > 1 ? 12 : 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onMapReady: () {
            _ready = true;
            _fit();
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.viateria.viateria',
          ),
          if (widget.bikeLine.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.bikeLine,
                  color: AppTheme.gold.withValues(alpha: 0.9),
                  strokeWidth: 5,
                ),
              ],
            ),
          if (widget.hikeLine.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.hikeLine,
                  color: scheme.primary,
                  strokeWidth: 4,
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
                  child: const Icon(
                    Icons.flag,
                    color: AppTheme.forest,
                    size: 32,
                  ),
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
      ),
    );
  }
}
