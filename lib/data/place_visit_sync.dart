import 'package:shared_preferences/shared_preferences.dart';

import '../domain/leaderboard_score.dart';
import 'repositories.dart';
import 'scoped_prefs.dart';
import 'verified_places.dart';

/// Uploads visited place ids that still live in SharedPreferences.
///
/// Runs once per user. Later map visits call `record_place_visit` themselves.
/// The flag stays unset when the RPC fails so the next launch can retry.
/// Local ids remain the map's visited markers; the score is the server row.
/// Login copies server rows back into the store (`PlaceVisitHydrate`) and
/// does not read this flag.
class PlaceVisitSync {
  const PlaceVisitSync();

  static const syncedFlag = 'viateria.placeVisitsSynced';

  Future<bool> syncStored({
    required String userId,
    required VerifiedPlacesStore store,
    required LeaderboardRepository leaderboard,
    SharedPreferences? preferences,
  }) async {
    if (userId.isEmpty) return false;
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final flag = ScopedPrefs.keyFor(syncedFlag, userId);
    if (prefs.getBool(flag) == true) return false;
    final ids = store.ids.where(isPlaceUuid).toList()..sort();
    if (ids.isNotEmpty) {
      await leaderboard.recordPlaceVisitsBatch(ids);
    }
    await prefs.setBool(flag, true);
    return true;
  }
}
