import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the challenge the user last opened (catalog, map, or detail).
class LastOpenedChallengeStore extends ChangeNotifier {
  LastOpenedChallengeStore({String? initialId}) : _challengeId = initialId;

  static const prefsKey = 'viateria.lastOpenedChallengeId';

  String? _challengeId;
  String? get challengeId => _challengeId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _challengeId = prefs.getString(prefsKey) ?? _challengeId;
    notifyListeners();
  }

  Future<void> remember(String id) async {
    if (id.isEmpty || id == _challengeId) return;
    _challengeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, id);
  }
}
