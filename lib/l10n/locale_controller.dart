import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// Signed-in sessions use [profileLocale]. Signed-out sessions use
/// [storedLocale]. Anything outside cs/en/de falls back to Czech.
String resolveSessionLocale({
  required bool signedIn,
  String? profileLocale,
  String? storedLocale,
}) {
  final raw = (signedIn ? profileLocale : storedLocale)?.trim().toLowerCase();
  if (raw != null && AppStrings.supported.contains(raw)) return raw;
  return 'cs';
}

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
    if (stored == null) return;
    adoptResolvedLocale(
      resolveSessionLocale(signedIn: false, storedLocale: stored),
    );
  }

  /// Applies an already-resolved locale without writing SharedPreferences.
  ///
  /// Signed-in sessions use `profiles.locale`. Prefs stay the signed-out
  /// Auth screen value written by [setLocale].
  void adoptResolvedLocale(String locale) {
    final next = AppStrings.supported.contains(locale) ? locale : 'cs';
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
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
