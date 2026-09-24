import 'package:shared_preferences/shared_preferences.dart';

/// Binds device-local prefs to one Supabase user.
///
/// There is no anonymous auth user. Visited places and the last-opened
/// challenge used to live in a single unscoped key. The first signed-in
/// account adopts that snapshot so it is not orphaned; later accounts on
/// the same device get their own key.
abstract final class ScopedPrefs {
  static const ownerKey = 'viateria.deviceProgressOwner';

  static String keyFor(String legacyKey, String? userId) {
    if (userId == null || userId.isEmpty) return legacyKey;
    return '$legacyKey.$userId';
  }

  /// True when [userId] may copy the legacy unscoped value.
  ///
  /// The first caller records itself as the owner. The same user may adopt
  /// again (a second store, or a retry). A different user may not.
  static Future<bool> mayAdoptLegacy(
    SharedPreferences prefs,
    String userId,
  ) async {
    final owner = prefs.getString(ownerKey);
    if (owner == null || owner.isEmpty) {
      await prefs.setString(ownerKey, userId);
      return true;
    }
    return owner == userId;
  }
}
