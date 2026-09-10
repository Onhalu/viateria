import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local set of verified map place ids (GPS or photo).
class VerifiedPlacesStore extends ChangeNotifier {
  VerifiedPlacesStore({Set<String>? initial}) : _ids = {...?initial};

  static const prefsKey = 'viateria.verifiedPlaceIds';

  final Set<String> _ids;

  Set<String> get ids => Set<String>.unmodifiable(_ids);

  bool contains(String id) => _ids.contains(id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(prefsKey);
    if (stored != null) {
      _ids
        ..clear()
        ..addAll(stored);
    }
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefsKey, _ids.toList()..sort());
  }
}
