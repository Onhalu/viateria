import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/leaderboard_score.dart';
import '../models/models.dart';
import 'repositories.dart';

/// Live RPCs from `0011_leaderboard.sql`. Nothing is written to disk.
class SupabaseLeaderboardRepository implements LeaderboardRepository {
  SupabaseLeaderboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> recordPlaceVisit(
    String placeId, {
    required PlaceVisitSource source,
  }) async {
    if (!isPlaceUuid(placeId)) return;
    await _client.rpc(
      'record_place_visit',
      params: {'p_place_id': placeId, 'p_source': source.wire},
    );
  }

  @override
  Future<void> recordPlaceVisitsBatch(
    List<String> placeIds, {
    PlaceVisitSource source = PlaceVisitSource.prefsSync,
  }) async {
    final ids = placeIds.where(isPlaceUuid).toSet().toList();
    if (ids.isEmpty) return;
    await _client.rpc(
      'record_place_visits_batch',
      params: {'p_place_ids': ids, 'p_source': source.wire},
    );
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard({int limit = 50}) async {
    final raw = await _client.rpc(
      'get_leaderboard',
      params: {'p_limit': clampLeaderboardLimit(limit)},
    );
    return _rows(raw);
  }

  @override
  Future<LeaderboardEntry> fetchMyScore() async {
    final raw = await _client.rpc('get_my_score');
    final rows = _rows(raw);
    if (rows.isEmpty) return LeaderboardEntry.unscored;
    return rows.first;
  }

  List<LeaderboardEntry> _rows(dynamic raw) {
    if (raw == null) return const [];
    if (raw is Map) {
      return [LeaderboardEntry.fromRpc(Map<String, dynamic>.from(raw))];
    }
    if (raw is List) {
      return [
        for (final row in raw)
          if (row is Map)
            LeaderboardEntry.fromRpc(Map<String, dynamic>.from(row)),
      ];
    }
    return const [];
  }
}
