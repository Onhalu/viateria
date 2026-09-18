import '../map/place.dart';
import '../map/place_category.dart';
import '../models/models.dart';

/// Verified/total for one [PlaceCategory] on the profile stats block.
class CategoryVisitCount {
  const CategoryVisitCount({
    required this.category,
    required this.verified,
    required this.total,
  });

  final PlaceCategory category;
  final int verified;
  final int total;

  /// Wire format shown next to the category label, e.g. `3 / 12`.
  String get fraction => '$verified / $total';
}

/// Counts catalog places per category and how many of those ids are verified.
///
/// Verified ids come from [VerifiedPlacesStore] (map GPS/photo). Challenge
/// waypoint verifies write matching catalog place ids into that store at
/// completion time, so they are included without a second backend.
///
/// Ids that are not in [places] do not count. Every category is returned,
/// including `0 / N`.
List<CategoryVisitCount> visitedPlaceCountsByCategory({
  required Iterable<Place> places,
  required Set<String> verifiedIds,
}) {
  final totals = {for (final category in PlaceCategory.values) category: 0};
  final verified = {for (final category in PlaceCategory.values) category: 0};
  for (final place in places) {
    totals[place.category] = totals[place.category]! + 1;
    if (verifiedIds.contains(place.id)) {
      verified[place.category] = verified[place.category]! + 1;
    }
  }
  return [
    for (final category in PlaceCategory.values)
      CategoryVisitCount(
        category: category,
        verified: verified[category]!,
        total: totals[category]!,
      ),
  ];
}

/// Published challenges the user has completed, newest [completedAt] first.
///
/// Progress rows whose challenge is missing from [published] are skipped
/// (unpublished / unknown ids are not readable under catalog RLS).
List<Challenge> completedChallengesForProfile({
  required Iterable<Challenge> published,
  required Iterable<ChallengeProgress> completedProgress,
}) {
  final byId = {for (final challenge in published) challenge.id: challenge};
  final sorted = [...completedProgress]
    ..sort((a, b) {
      final at = a.completedAt;
      final bt = b.completedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
  final seen = <String>{};
  final result = <Challenge>[];
  for (final progress in sorted) {
    if (!progress.isCompleted) continue;
    final challenge = byId[progress.challengeId];
    if (challenge == null) continue;
    if (!seen.add(challenge.id)) continue;
    result.add(challenge);
  }
  return result;
}
