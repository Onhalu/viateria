import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/l10n/app_strings.dart';

void main() {
  test('cs, en and de expose the same keys', () {
    for (final locale in AppStrings.supported) {
      final table = AppStrings(locale);
      for (final key in AppStrings.keys) {
        expect(table.t(key), isNotEmpty, reason: '$locale missing $key');
        expect(table.t(key), isNot(equals(key)), reason: '$locale fallback $key');
      }
    }
  });

  test('unknown locale falls back to English', () {
    expect(AppStrings('fr').signIn, AppStrings('en').signIn);
  });
}
