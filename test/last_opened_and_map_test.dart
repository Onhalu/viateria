import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/widgets/challenges_overview_map.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('remember persists the last opened challenge id', () async {
    final store = LastOpenedChallengeStore();
    expect(store.challengeId, isNull);
    await store.remember('open-1');
    expect(store.challengeId, 'open-1');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LastOpenedChallengeStore.prefsKey), 'open-1');

    final reloaded = LastOpenedChallengeStore();
    await reloaded.load();
    expect(reloaded.challengeId, 'open-1');
  });

  test('overview map skips challenges without waypoint coordinates', () {
    final open = sampleOpenChallenge();
    const empty = ChallengeDetail(
      challenge: Challenge(
        id: 'empty-1',
        slug: 'empty',
        accessMode: AccessMode.open,
        pricingType: PricingType.free,
        priceCents: 0,
        currency: 'eur',
        status: PublishStatus.published,
        translations: [
          LocalizedText(locale: 'en', title: 'No pins', description: ''),
        ],
      ),
      waypoints: [],
    );
    final mapped = mappedChallengesFrom([open, empty]);
    expect(mapped, hasLength(1));
    expect(mapped.single.id, 'open-1');
    expect(mapped.single.point.latitude, 50.08);
    expect(mapped.single.point.longitude, 14.42);
  });
}
