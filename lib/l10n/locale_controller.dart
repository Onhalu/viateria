import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

class LocaleController extends ChangeNotifier {
  LocaleController({String initial = 'cs'}) : _locale = _normalize(initial);

  static const _prefsKey = 'viateria.locale';

  String _locale;
  String get locale => _locale;
  AppStrings get strings => AppStrings(_locale);

  static String _normalize(String value) {
    final lower = value.toLowerCase();
    if (AppStrings.supported.contains(lower)) return lower;
    return 'en';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null) {
      _locale = _normalize(stored);
      notifyListeners();
    }
  }

  Future<void> setLocale(String value) async {
    final next = _normalize(value);
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next);
  }
}
