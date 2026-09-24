import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scoped_prefs.dart';

/// Remembers the challenge the user last opened (catalog, map, or detail).
///
/// Unscoped until [bindUser]. The first signed-in user adopts the legacy
/// device value; each later user has their own id.
class LastOpenedChallengeStore extends ChangeNotifier {
  LastOpenedChallengeStore({String? initialId}) : _challengeId = initialId;

  static const prefsKey = 'viateria.lastOpenedChallengeId';

  String? _challengeId;
  String? _userId;
  var _generation = 0;

  String? get challengeId => _challengeId;

  /// Loads the key for the current binding (legacy key when unbound).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(ScopedPrefs.keyFor(prefsKey, _userId));
    if (stored != null) _challengeId = stored.isEmpty ? null : stored;
    notifyListeners();
  }

  /// Switches the in-memory id to [userId].
  ///
  /// Null clears memory and leaves every account's prefs on disk.
  Future<void> bindUser(String? userId) async {
    final generation = ++_generation;
    final next = (userId == null || userId.isEmpty) ? null : userId;
    _userId = next;
    if (next == null) {
      _challengeId = null;
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (generation != _generation) return;
    final scopedKey = ScopedPrefs.keyFor(prefsKey, next);
    final existing = prefs.getString(scopedKey);
    if (existing != null) {
      _challengeId = existing.isEmpty ? null : existing;
      final owner = prefs.getString(ScopedPrefs.ownerKey);
      if (owner == null || owner.isEmpty) {
        await prefs.setString(ScopedPrefs.ownerKey, next);
      }
    } else if (await ScopedPrefs.mayAdoptLegacy(prefs, next)) {
      if (generation != _generation) return;
      final raced = prefs.getString(scopedKey);
      if (raced != null) {
        _challengeId = raced.isEmpty ? null : raced;
      } else {
        final legacy = prefs.getString(prefsKey);
        _challengeId = (legacy == null || legacy.isEmpty) ? null : legacy;
        await prefs.setString(scopedKey, _challengeId ?? '');
        await prefs.remove(prefsKey);
      }
    } else {
      _challengeId = null;
    }
    if (generation != _generation) return;
    notifyListeners();
  }

  Future<void> remember(String id) async {
    if (id.isEmpty || id == _challengeId) return;
    _challengeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ScopedPrefs.keyFor(prefsKey, _userId), id);
  }
}
