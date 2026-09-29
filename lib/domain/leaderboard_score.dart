import '../models/enums.dart';

/// Where a place visit was recorded. Wire values match `place_visits.source`.
enum PlaceVisitSource {
  map('map'),
  verify('verify'),
  prefsSync('prefs_sync');

  const PlaceVisitSource(this.wire);

  final String wire;
}

/// Mirrors `challenges.difficulty` scoring in `0011_leaderboard.sql`.
///
/// easy or null → 3, normal → 4, hard → 5. Only completed challenges score.
int pointsForCompletedChallenge(CatalogDifficulty? difficulty) {
  return switch (difficulty) {
    CatalogDifficulty.hard => 5,
    CatalogDifficulty.normal => 4,
    CatalogDifficulty.easy || null => 3,
  };
}

/// Place points (one per distinct place) plus challenge points.
int leaderboardTotal({required int placePoints, required int challengePoints}) {
  return placePoints + challengePoints;
}

/// `get_leaderboard` clamps the requested page size to 0…50.
int clampLeaderboardLimit(int limit) {
  if (limit < 0) return 0;
  if (limit > 50) return 50;
  return limit;
}

final _placeUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// True when [value] can be sent as a `places.id` uuid.
bool isPlaceUuid(String value) => _placeUuid.hasMatch(value);

/// One scored user before the server assigns [rank].
class ScoreCandidate {
  const ScoreCandidate({
    required this.userId,
    required this.totalPoints,
    this.firstVisit,
  });

  final String userId;
  final int totalPoints;

  /// Earliest `place_visits.visited_at`. Null when the user has only
  /// challenge points.
  final DateTime? firstVisit;
}

class RankedScore {
  const RankedScore({required this.row, required this.rank});

  final ScoreCandidate row;
  final int rank;
}

/// Same order as `leaderboard_rows`: points desc, first visit asc
/// (nulls last), then `user_id`. Zero-point rows are dropped.
List<RankedScore> rankScores(Iterable<ScoreCandidate> rows) {
  final sorted = [
    for (final row in rows)
      if (row.totalPoints > 0) row,
  ]..sort(compareScoreCandidates);
  return [
    for (var i = 0; i < sorted.length; i++)
      RankedScore(row: sorted[i], rank: i + 1),
  ];
}

int compareScoreCandidates(ScoreCandidate a, ScoreCandidate b) {
  final byPoints = b.totalPoints.compareTo(a.totalPoints);
  if (byPoints != 0) return byPoints;
  final aVisit = a.firstVisit;
  final bVisit = b.firstVisit;
  if (aVisit == null && bVisit != null) return 1;
  if (aVisit != null && bVisit == null) return -1;
  if (aVisit != null && bVisit != null) {
    final byVisit = aVisit.compareTo(bVisit);
    if (byVisit != 0) return byVisit;
  }
  return a.userId.compareTo(b.userId);
}

/// Name shown on the board. Never falls back to an email address.
String leaderboardPersonName({
  required String? displayName,
  required bool isSelf,
  required String selfLabel,
}) {
  final trimmed = displayName?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return isSelf ? selfLabel : '—';
}
