/// One row from `get_leaderboard` / `get_my_score`.
///
/// [displayName] is `profiles.display_name`. The RPC does not return email,
/// and this type has no email field.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.totalPoints,
    required this.placePoints,
    required this.challengePoints,
    this.displayName,
    this.avatarUrl,
    this.rank,
  });

  /// Signed-in user with nothing scored yet (rank stays null).
  static const unscored = LeaderboardEntry(
    userId: '',
    totalPoints: 0,
    placePoints: 0,
    challengePoints: 0,
  );

  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final int totalPoints;
  final int placePoints;
  final int challengePoints;
  final int? rank;

  bool get hasRank => rank != null && totalPoints > 0;

  factory LeaderboardEntry.fromRpc(Map<String, dynamic> row) {
    return LeaderboardEntry(
      userId: row['user_id'] as String? ?? '',
      displayName: _clean(row['display_name']),
      avatarUrl: _clean(row['avatar_url']),
      totalPoints: (row['total_points'] as num?)?.toInt() ?? 0,
      placePoints: (row['place_points'] as num?)?.toInt() ?? 0,
      challengePoints: (row['challenge_points'] as num?)?.toInt() ?? 0,
      rank: (row['rank'] as num?)?.toInt(),
    );
  }
}

String? _clean(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}
