import '../domain/leaderboard_score.dart';
import '../models/models.dart';
import 'repositories.dart';

/// In-memory board used by tests and the unconfigured app shell.
///
/// Records visits so callers can be asserted. It does not invent scores.
class MemoryLeaderboardRepository implements LeaderboardRepository {
  MemoryLeaderboardRepository({
    List<LeaderboardEntry>? entries,
    this.me,
    this.error,
    List<String>? visitedPlaceIds,
  }) : entries = entries ?? const [],
       visitedPlaceIds = List<String>.from(visitedPlaceIds ?? const []);

  List<LeaderboardEntry> entries;
  LeaderboardEntry? me;
  Object? error;

  /// Ids returned by [fetchMyVisitedPlaceIds]. Tests set the server snapshot.
  List<String> visitedPlaceIds;

  final visits = <({String placeId, PlaceVisitSource source})>[];
  final batches = <List<String>>[];

  @override
  Future<void> recordPlaceVisit(
    String placeId, {
    required PlaceVisitSource source,
  }) async {
    if (!isPlaceUuid(placeId)) return;
    final forced = error;
    if (forced != null) throw forced;
    visits.add((placeId: placeId, source: source));
  }

  @override
  Future<void> recordPlaceVisitsBatch(
    List<String> placeIds, {
    PlaceVisitSource source = PlaceVisitSource.prefsSync,
  }) async {
    final ids = placeIds.where(isPlaceUuid).toSet().toList()..sort();
    if (ids.isEmpty) return;
    final forced = error;
    if (forced != null) throw forced;
    batches.add(ids);
    for (final id in ids) {
      visits.add((placeId: id, source: source));
    }
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard({int limit = 50}) async {
    final forced = error;
    if (forced != null) throw forced;
    final capped = clampLeaderboardLimit(limit);
    if (entries.length <= capped) return List<LeaderboardEntry>.from(entries);
    return entries.sublist(0, capped);
  }

  @override
  Future<LeaderboardEntry> fetchMyScore() async {
    final forced = error;
    if (forced != null) throw forced;
    return me ?? LeaderboardEntry.unscored;
  }

  @override
  Future<List<String>> fetchMyVisitedPlaceIds() async {
    final forced = error;
    if (forced != null) throw forced;
    final ids = visitedPlaceIds.where((id) => id.isNotEmpty).toSet().toList()
      ..sort();
    return ids;
  }
}
