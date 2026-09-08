import '../models/models.dart';

/// Access + sequential unlock rules (SPEC v1).
///
/// * Free challenges are accessible immediately after sign-in.
/// * Paid challenges require a paid [Purchase].
/// * **Open** challenges unlock every waypoint once the user has access.
/// * **Story** challenges unlock the next waypoint only after the previous
///   one is complete. Waypoint 0 is unlocked as soon as access is granted.
class UnlockRules {
  const UnlockRules();

  bool hasAccess({
    required PricingType pricing,
    required bool purchased,
  }) {
    return pricing == PricingType.free || purchased;
  }

  bool isWaypointUnlocked({
    required AccessMode mode,
    required bool hasAccess,
    required int waypointIndex,
    required Set<int> completedIndexes,
  }) {
    if (!hasAccess) return false;
    if (waypointIndex < 0) return false;
    if (mode == AccessMode.open) return true;
    if (waypointIndex == 0) return true;
    return completedIndexes.contains(waypointIndex - 1);
  }

  bool isWaypointUnlockedById({
    required AccessMode mode,
    required bool hasAccess,
    required List<Waypoint> orderedWaypoints,
    required String waypointId,
    required Set<String> completedWaypointIds,
  }) {
    final index = orderedWaypoints.indexWhere((w) => w.id == waypointId);
    if (index < 0) return false;
    final completedIndexes = <int>{};
    for (var i = 0; i < orderedWaypoints.length; i++) {
      if (completedWaypointIds.contains(orderedWaypoints[i].id)) {
        completedIndexes.add(i);
      }
    }
    return isWaypointUnlocked(
      mode: mode,
      hasAccess: hasAccess,
      waypointIndex: index,
      completedIndexes: completedIndexes,
    );
  }

  bool canVerifyPhoto({
    required AccessMode mode,
    required bool hasAccess,
    required List<Waypoint> orderedWaypoints,
    required String waypointId,
    required Set<String> completedWaypointIds,
  }) {
    return isWaypointUnlockedById(
      mode: mode,
      hasAccess: hasAccess,
      orderedWaypoints: orderedWaypoints,
      waypointId: waypointId,
      completedWaypointIds: completedWaypointIds,
    );
  }

  bool isChallengeComplete({
    required List<Waypoint> waypoints,
    required Set<String> completedWaypointIds,
  }) {
    if (waypoints.isEmpty) return false;
    return waypoints.every((w) => completedWaypointIds.contains(w.id));
  }
}
