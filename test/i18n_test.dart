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
    expect(AppStrings('cs').catalogLengthShort, 'Krátká');
    expect(AppStrings('en').catalogLengthShort, 'Short');
    expect(AppStrings('de').catalogLengthShort, 'Kurz');
    expect(AppStrings('cs').catalogLengthMedium, 'Střední');
    expect(AppStrings('en').catalogLengthMedium, 'Medium');
    expect(AppStrings('de').catalogLengthMedium, 'Mittel');
    expect(AppStrings('cs').catalogLengthLong, 'Dlouhá');
    expect(AppStrings('en').catalogLengthLong, 'Long');
    expect(AppStrings('de').catalogLengthLong, 'Lang');
    expect(AppStrings('cs').catalogDifficultyEasy, 'Lehká');
    expect(AppStrings('en').catalogDifficultyEasy, 'Easy');
    expect(AppStrings('de').catalogDifficultyEasy, 'Leicht');
    expect(AppStrings('cs').catalogDifficultyNormal, 'Běžná');
    expect(AppStrings('en').catalogDifficultyNormal, 'Normal');
    expect(AppStrings('de').catalogDifficultyNormal, 'Normal');
    expect(AppStrings('cs').catalogDifficultyHard, 'Náročná');
    expect(AppStrings('en').catalogDifficultyHard, 'Hard');
    expect(AppStrings('de').catalogDifficultyHard, 'Anspruchsvoll');
  });

  test('profile stats copy is localized', () {
    expect(AppStrings('cs').profileCatCity, 'Město');
    expect(AppStrings('en').profileCatCity, 'City');
    expect(AppStrings('de').profileCatCity, 'Stadt');
    expect(AppStrings('cs').profileCatNature, 'Příroda');
    expect(AppStrings('en').profileCatNature, 'Nature');
    expect(AppStrings('de').profileCatNature, 'Natur');
    expect(AppStrings('cs').profileCatTechnical, 'Technická');
    expect(AppStrings('en').profileCatTechnical, 'Technical');
    expect(AppStrings('de').profileCatTechnical, 'Technisch');
    expect(AppStrings('cs').profileCatHistorical, 'Historická');
    expect(AppStrings('en').profileCatHistorical, 'Historical');
    expect(AppStrings('de').profileCatHistorical, 'Historisch');
    expect(AppStrings('cs').completedChallenges, 'Dokončené výzvy');
    expect(AppStrings('en').completedChallenges, 'Completed challenges');
    expect(AppStrings('de').completedChallenges, 'Abgeschlossene Challenges');
    expect(
      AppStrings('cs').completedChallengesEmpty,
      'Zatím žádná dokončená výzva.',
    );
    expect(
      AppStrings('en').completedChallengesEmpty,
      'No completed challenges yet.',
    );
    expect(
      AppStrings('de').completedChallengesEmpty,
      'Noch keine abgeschlossene Challenge.',
    );
  });

  test('elevation metres keep a space and a locale decimal mark', () {
    expect(AppStrings('cs').formatElevationM(365), '365 m');
    expect(AppStrings('en').formatElevationM(365), '365 m');
    expect(AppStrings('de').formatElevationM(12), '12 m');
    expect(AppStrings('cs').formatElevationM(412.5), '412,5 m');
    expect(AppStrings('de').formatElevationM(412.5), '412,5 m');
    expect(AppStrings('en').formatElevationM(412.5), '412.5 m');
    expect(AppStrings('cs').showMore, 'Více');
    expect(AppStrings('cs').showLess, 'Méně');
    expect(AppStrings('en').showMore, 'More');
    expect(AppStrings('de').showMore, 'Mehr');
  });

  test('challenge photo gallery copy is localized', () {
    expect(AppStrings('cs').challengePhotosTitle, 'Fotky z výzvy');
    expect(AppStrings('en').challengePhotosTitle, 'Challenge photos');
    expect(AppStrings('de').challengePhotosTitle, 'Challenge-Fotos');
    expect(
      AppStrings('cs').challengePhotosEmpty,
      'Zatím žádná fotka. Ověř místo jako první.',
    );
    expect(
      AppStrings('en').challengePhotosEmpty,
      'No photos yet. Be the first to verify a place.',
    );
    expect(
      AppStrings('de').challengePhotosEmpty,
      'Noch keine Fotos. Sei der Erste.',
    );
  });
}
