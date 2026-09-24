import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scoped_prefs.dart';

/// Local set of verified map place ids (GPS or photo).
///
/// Unscoped until [bindUser] runs. The first signed-in user adopts the
/// legacy device set; each later user keeps a separate set.
class VerifiedPlacesStore extends ChangeNotifier {
  VerifiedPlacesStore({Set<String>? initial}) : _ids = {...?initial};

  static const prefsKey = 'viateria.verifiedPlaceIds';

  final Set<String> _ids;
  String? _userId;
  var _generation = 0;

  Set<String> get ids => Set<String>.unmodifiable(_ids);

  bool contains(String id) => _ids.contains(id);

  /// Loads the key for the current binding (legacy key when unbound).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(ScopedPrefs.keyFor(prefsKey, _userId));
    if (stored != null) {
      _ids
        ..clear()
        ..addAll(stored);
    }
    notifyListeners();
  }

  /// Switches the in-memory set to [userId].
  ///
  /// Null clears memory and leaves every account's prefs on disk.
  Future<void> bindUser(String? userId) async {
    final generation = ++_generation;
    final next = (userId == null || userId.isEmpty) ? null : userId;
    _userId = next;
    if (next == null) {
      _ids.clear();
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (generation != _generation) return;
    final scopedKey = ScopedPrefs.keyFor(prefsKey, next);
    final existing = prefs.getStringList(scopedKey);
    if (existing != null) {
      _ids
        ..clear()
        ..addAll(existing);
      final owner = prefs.getString(ScopedPrefs.ownerKey);
      if (owner == null || owner.isEmpty) {
        await prefs.setString(ScopedPrefs.ownerKey, next);
      }
    } else if (await ScopedPrefs.mayAdoptLegacy(prefs, next)) {
      if (generation != _generation) return;
      final raced = prefs.getStringList(scopedKey);
      final legacy = prefs.getStringList(prefsKey) ?? const <String>[];
      _ids
        ..clear()
        ..addAll(raced ?? legacy);
      await prefs.setStringList(scopedKey, _ids.toList()..sort());
      if (raced == null) await prefs.remove(prefsKey);
    } else {
      _ids.clear();
    }
    if (generation != _generation) return;
    notifyListeners();
  }

  Future<void> add(String id) async {
    await addAll([id]);
  }

  Future<void> addAll(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      if (id.isNotEmpty && _ids.add(id)) changed = true;
    }
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final key = ScopedPrefs.keyFor(prefsKey, _userId);
    final stored = prefs.getStringList(key);
    if (stored != null) _ids.addAll(stored);
    await prefs.setStringList(key, _ids.toList()..sort());
  }
}
