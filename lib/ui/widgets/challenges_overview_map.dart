import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';

class MappedChallenge {
  const MappedChallenge({required this.detail, required this.point});

  final ChallengeDetail detail;
  final LatLng point;

  String get id => detail.challenge.id;
}

List<MappedChallenge> mappedChallengesFrom(List<ChallengeDetail> details) {
  final mapped = <MappedChallenge>[];
  for (final detail in details) {
    final waypoints = detail.orderedWaypoints;
    if (waypoints.isEmpty) continue;
    mapped.add(MappedChallenge(detail: detail, point: waypoints.first.latLng));
  }
  return mapped;
}

/// Overview map of published challenges using existing waypoint coordinates
/// and the same Leaflet/OSM stack as [ChallengeMap].
class ChallengesOverviewMap extends StatelessWidget {
  const ChallengesOverviewMap({
    super.key,
    required this.challenges,
    required this.onChallengeTap,
  });

  final List<MappedChallenge> challenges;
  final ValueChanged<String> onChallengeTap;

  @override
  Widget build(BuildContext context) {
    if (!TickerMode.valuesOf(context).enabled) {
      return const SizedBox.expand();
    }
    final points = challenges.map((c) => c.point).toList();
    final scheme = Theme.of(context).colorScheme;
    return FlutterMap(
      options: MapOptions(
        initialCenter: points.first,
        initialZoom: points.length > 1 ? 8 : 12,
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(48),
              )
            : null,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.viateria.viateria',
        ),
        MarkerLayer(
          markers: [
            for (final item in challenges)
              Marker(
                point: item.point,
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => onChallengeTap(item.id),
                  child: CircleAvatar(
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.landscape, color: scheme.onPrimary),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
