import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/domain/unlock_rules.dart';
import 'package:viateria/models/models.dart';

import 'helpers/fakes.dart';

void main() {
  const rules = UnlockRules();

  test('free challenges are accessible without a purchase', () {
    expect(
      rules.hasAccess(pricing: PricingType.free, purchased: false),
      isTrue,
    );
  });

  test('paid challenges require a paid purchase', () {
    expect(
      rules.hasAccess(pricing: PricingType.paid, purchased: false),
      isFalse,
    );
    expect(
      rules.hasAccess(pricing: PricingType.paid, purchased: true),
      isTrue,
    );
  });

  test('open challenges unlock every waypoint after access', () {
    expect(
      rules.isWaypointUnlocked(
        mode: AccessMode.open,
        hasAccess: true,
        waypointIndex: 2,
        completedIndexes: {},
      ),
      isTrue,
    );
    expect(
      rules.isWaypointUnlocked(
        mode: AccessMode.open,
        hasAccess: false,
        waypointIndex: 0,
        completedIndexes: {},
      ),
      isFalse,
    );
  });

  test('story challenges unlock the next waypoint only after the prior one', () {
    expect(
      rules.isWaypointUnlocked(
        mode: AccessMode.story,
        hasAccess: true,
        waypointIndex: 0,
        completedIndexes: {},
      ),
      isTrue,
    );
    expect(
      rules.isWaypointUnlocked(
        mode: AccessMode.story,
        hasAccess: true,
        waypointIndex: 1,
        completedIndexes: {},
      ),
      isFalse,
    );
    expect(
      rules.isWaypointUnlocked(
        mode: AccessMode.story,
        hasAccess: true,
        waypointIndex: 1,
        completedIndexes: {0},
      ),
      isTrue,
    );
    expect(
      rules.isWaypointUnlocked(
        mode: AccessMode.story,
        hasAccess: true,
        waypointIndex: 2,
        completedIndexes: {0},
      ),
      isFalse,
    );
  });

  test('memory progress enforces story order', () async {
    final story = sampleStoryChallenge();
    final progress = MemoryProgress(details: [story]);
    await expectLater(
      progress.verifyWaypoint(
        challengeId: story.challenge.id,
        waypointId: 'sw-2',
        photoPath: 'user-1/story-1/sw-2/p.jpg',
      ),
      throwsStateError,
    );
    await progress.verifyWaypoint(
      challengeId: story.challenge.id,
      waypointId: 'sw-1',
      photoPath: 'user-1/story-1/sw-1/p.jpg',
    );
    final afterSecond = await progress.verifyWaypoint(
      challengeId: story.challenge.id,
      waypointId: 'sw-2',
      photoPath: 'user-1/story-1/sw-2/p.jpg',
    );
    expect(afterSecond.isCompleted, isTrue);
  });

  test('open progress allows later waypoints first', () async {
    final open = sampleOpenChallenge();
    final progress = MemoryProgress(details: [open]);
    final result = await progress.verifyWaypoint(
      challengeId: open.challenge.id,
      waypointId: 'ow-2',
      photoPath: 'user-1/open-1/ow-2/p.jpg',
    );
    expect(result.completedWaypointIds, contains('ow-2'));
    expect(result.isCompleted, isFalse);
  });
}
