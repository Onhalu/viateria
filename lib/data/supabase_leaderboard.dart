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

  /// Own `place_visits.place_id` rows, paged so a PostgREST cap cannot truncate.
  ///
  /// RLS (`place_visits_select_own`) already limits this to `auth.uid()`.
  /// The `user_id` filter matches that and skips the request when signed out.
  @override
  Future<List<String>> fetchMyVisitedPlaceIds() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return Future.value(const []);
    return collectPlaceVisitIds(
      loadPage: (offset, pageSize) =>
          _fetchPlaceVisitPage(_client, userId, offset, pageSize),
    );
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

/// Page size for [collectPlaceVisitIds]. Matches the places catalog page.
const placeVisitPageSize = 1000;

/// Unions `place_id` from paged `place_visits` responses.
///
/// A short page ends the read. A full page that adds no new ids also ends
/// it, so a server that ignores `range` cannot loop.
Future<List<String>> collectPlaceVisitIds({
  required Future<List<dynamic>> Function(int offset, int pageSize) loadPage,
  int pageSize = placeVisitPageSize,
}) async {
  if (pageSize <= 0) return const [];
  final ids = <String>{};
  var offset = 0;
  while (true) {
    final page = await loadPage(offset, pageSize);
    final before = ids.length;
    ids.addAll(placeIdsFromVisitRows(page));
    if (page.length < pageSize || ids.length == before) break;
    offset += pageSize;
  }
  return ids.toList()..sort();
}

/// `place_id` values from `place_visits` rows. Blank ids are skipped.
List<String> placeIdsFromVisitRows(List<dynamic> rows) {
  final ids = <String>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final id = row['place_id']?.toString().trim() ?? '';
    if (id.isEmpty) continue;
    ids.add(id);
  }
  return ids.toList()..sort();
}

Future<List<dynamic>> _fetchPlaceVisitPage(
  SupabaseClient client,
  String userId,
  int offset,
  int pageSize,
) async {
  final rows = await client
      .from('place_visits')
      .select('place_id')
      .eq('user_id', userId)
      .order('place_id')
      .range(offset, offset + pageSize - 1);
  return rows;
}
