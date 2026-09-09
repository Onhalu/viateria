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
