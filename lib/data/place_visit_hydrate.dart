import 'place_visit_sync.dart';
import 'repositories.dart';
import 'verified_places.dart';

/// Copies the signed-in user's `place_visits` into [VerifiedPlacesStore].
///
/// Profile category cards and the map read that store. This fills it after
/// a backfill, a new device, or cleared web storage. It does not look at
/// [PlaceVisitSync.syncedFlag].
class PlaceVisitHydrate {
  const PlaceVisitHydrate();

  /// Unions server place ids into [store] when it is still bound to [userId].
  ///
  /// A sign-out or account switch that lands while the select is in flight
  /// is ignored, so those ids are not written into the next account.
  Future<void> mergeFromServer({
    required String userId,
    required VerifiedPlacesStore store,
    required LeaderboardRepository leaderboard,
  }) async {
    if (userId.isEmpty) return;
    final ids = await leaderboard.fetchMyVisitedPlaceIds();
    if (store.boundUserId != userId) return;
    await store.addAll(ids);
  }
}

/// Login order: hydrate `place_visits`, then upload prefs still only local.
///
/// A failed read still attempts the upload. A failed upload leaves the
/// sync flag unset. Neither failure is thrown to the login caller.
Future<void> refreshVerifiedPlacesOnLogin({
  required String userId,
  required VerifiedPlacesStore store,
  required LeaderboardRepository leaderboard,
}) async {
  if (userId.isEmpty) return;
  try {
    await const PlaceVisitHydrate().mergeFromServer(
      userId: userId,
      store: store,
      leaderboard: leaderboard,
    );
  } catch (_) {}
  try {
    await const PlaceVisitSync().syncStored(
      userId: userId,
      store: store,
      leaderboard: leaderboard,
    );
  } catch (_) {}
}
