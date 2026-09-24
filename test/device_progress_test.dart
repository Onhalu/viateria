import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/data/scoped_prefs.dart';
import 'package:viateria/data/verified_places.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first signed-in user adopts legacy visited places', () async {
    SharedPreferences.setMockInitialValues({
      VerifiedPlacesStore.prefsKey: ['karlstejn'],
    });
    final store = VerifiedPlacesStore();
    await store.bindUser('user-a');
    expect(store.contains('karlstejn'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('${VerifiedPlacesStore.prefsKey}.user-a'), [
      'karlstejn',
    ]);
    expect(prefs.getStringList(VerifiedPlacesStore.prefsKey), isNull);
    expect(prefs.getString(ScopedPrefs.ownerKey), 'user-a');

    await store.bindUser('user-b');
    expect(store.ids, isEmpty);

    await store.add('prague');
    expect(prefs.getStringList('${VerifiedPlacesStore.prefsKey}.user-b'), [
      'prague',
    ]);
    expect(prefs.getStringList('${VerifiedPlacesStore.prefsKey}.user-a'), [
      'karlstejn',
    ]);

    await store.bindUser(null);
    expect(store.ids, isEmpty);

    await store.bindUser('user-a');
    expect(store.contains('karlstejn'), isTrue);
    expect(store.contains('prague'), isFalse);
  });

  test(
    'first signed-in user adopts the legacy last-opened challenge',
    () async {
      SharedPreferences.setMockInitialValues({
        LastOpenedChallengeStore.prefsKey: 'open-1',
      });
      final store = LastOpenedChallengeStore();
      await store.bindUser('user-a');
      expect(store.challengeId, 'open-1');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('${LastOpenedChallengeStore.prefsKey}.user-a'),
        'open-1',
      );
      expect(prefs.getString(LastOpenedChallengeStore.prefsKey), isNull);

      await store.bindUser('user-b');
      expect(store.challengeId, isNull);
      await store.remember('story-9');
      expect(store.challengeId, 'story-9');

      await store.bindUser('user-a');
      expect(store.challengeId, 'open-1');
    },
  );

  test('unbound stores still use the legacy keys', () async {
    final places = VerifiedPlacesStore();
    await places.add('karlstejn');
    final last = LastOpenedChallengeStore();
    await last.remember('open-1');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(VerifiedPlacesStore.prefsKey), ['karlstejn']);
    expect(prefs.getString(LastOpenedChallengeStore.prefsKey), 'open-1');
  });
}
