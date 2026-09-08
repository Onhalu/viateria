import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Material/Cupertino catalogs on some Flutter SDKs omit Czech (`cs`).
///
/// App copy stays in custom cs/en/de strings. These delegates only satisfy
/// `Localizations` for widget chrome (TextField, buttons, dialogs) by loading
/// the English Global* translations when the locale is `cs`.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'cs';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant FallbackMaterialLocalizationsDelegate old) =>
      false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'cs';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant FallbackCupertinoLocalizationsDelegate old) =>
      false;
}

/// Fallback delegates first so `cs` is claimed before Global* (en/de).
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  FallbackMaterialLocalizationsDelegate(),
  FallbackCupertinoLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
