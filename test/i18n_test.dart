import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/l10n/app_strings.dart';

void main() {
  test('cs, en and de expose the same keys', () {
    for (final locale in AppStrings.supported) {
      final table = AppStrings(locale);
      for (final key in AppStrings.keys) {
        expect(table.t(key), isNotEmpty, reason: '$locale missing $key');
        expect(
          table.t(key),
          isNot(equals(key)),
          reason: '$locale fallback $key',
        );
      }
    }
  });

  test('unknown locale falls back to English', () {
    expect(AppStrings('fr').signIn, AppStrings('en').signIn);
  });

  test('appName is VANDERY in every supported locale', () {
    for (final locale in AppStrings.supported) {
      expect(AppStrings(locale).appName, 'VANDERY');
    }
  });

  test('welcome header copy is localized', () {
    expect(AppStrings('cs').welcomeBack, 'Vítej zpět');
    expect(AppStrings('en').welcomeBack, 'Welcome back');
    expect(AppStrings('de').welcomeBack, 'Willkommen zurück');
    expect(AppStrings('cs').welcomeNameFallback, 'cestovateli');
    expect(AppStrings('en').welcomeNameFallback, 'traveler');
    expect(AppStrings('de').welcomeNameFallback, 'Wanderer');
  });

  test('catalog discover copy is localized', () {
    expect(AppStrings('cs').catalogFeatured, 'Vybrané');
    expect(AppStrings('en').catalogFeatured, 'Featured');
    expect(AppStrings('de').catalogFeatured, 'Ausgewählt');
    expect(AppStrings('cs').catalogDurationShort, 'Krátké');
    expect(AppStrings('en').catalogDurationShort, 'Short');
    expect(AppStrings('de').catalogDurationShort, 'Kurz');
    expect(AppStrings('cs').catalogDurationHalfDay, 'Půlden');
    expect(AppStrings('en').catalogDurationHalfDay, 'Half-day');
    expect(AppStrings('de').catalogDurationHalfDay, 'Halbtag');
    expect(AppStrings('cs').catalogDurationFullDay, 'Celodenní');
    expect(AppStrings('en').catalogDurationFullDay, 'Full day');
    expect(AppStrings('de').catalogDurationFullDay, 'Ganztag');
    expect(
      AppStrings('en').formatCatalogHours(const Duration(hours: 2)),
      '2 h',
    );
    expect(AppStrings('cs').formatDistanceKm(12.0), '12 km');
  });
}
