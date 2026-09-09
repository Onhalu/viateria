import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';

class ChallengeMap extends StatelessWidget {
  const ChallengeMap({super.key, required this.waypoints, this.height = 220});

  final List<Waypoint> waypoints;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!TickerMode.valuesOf(context).enabled) {
      return SizedBox(height: height);
    }
    final ordered = [...waypoints]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final center = ordered.isEmpty
        ? const LatLng(50.0755, 14.4378)
        : ordered.first.latLng;
    return SizedBox(
      height: height,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: ordered.length > 1 ? 12 : 13,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.viateria.viateria',
          ),
          if (ordered.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: ordered.map((w) => w.latLng).toList(),
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 4,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final waypoint in ordered)
                Marker(
                  point: waypoint.latLng,
                  width: 36,
                  height: 36,
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      '${waypoint.sortOrder + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
