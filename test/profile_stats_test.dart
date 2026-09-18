import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/domain/profile_stats.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/models/models.dart';

import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

void main() {
  test('category counts are verified / total, including zeros', () {
    final places = [
      ...samplePlaces(),
      const Place(
        id: 'vitkovice',
        name: 'Ostrava-Vítkovice',
        category: PlaceCategory.technical,
        location: GeoPoint(49.81, 18.28),
      ),
      const Place(
        id: 'praha',
        name: 'Praha',
        category: PlaceCategory.city,
        location: GeoPoint(50.08, 14.42),
      ),
    ];
    final counts = visitedPlaceCountsByCategory(
      places: places,
      verifiedIds: {'staromestske', 'karlstejn', 'unknown-id'},
    );

    expect(counts, hasLength(PlaceCategory.values.length));
    expect(counts.map((row) => row.category), [
      PlaceCategory.city,
      PlaceCategory.nature,
      PlaceCategory.technical,
      PlaceCategory.historical,
    ]);

    expect(counts[0].verified, 1);
    expect(counts[0].total, 2);
    expect(counts[0].fraction, '1 / 2');

    expect(counts[1].verified, 0);
    expect(counts[1].total, 1);
    expect(counts[1].fraction, '0 / 1');

    expect(counts[2].verified, 0);
    expect(counts[2].total, 1);
    expect(counts[2].fraction, '0 / 1');

    expect(counts[3].verified, 1);
    expect(counts[3].total, 1);
    expect(counts[3].fraction, '1 / 1');
  });

  test('empty catalog still emits a 0 / 0 row per category', () {
    final counts = visitedPlaceCountsByCategory(
      places: const [],
      verifiedIds: {'karlstejn'},
    );
    for (final row in counts) {
      expect(row.verified, 0);
      expect(row.total, 0);
      expect(row.fraction, '0 / 0');
    }
  });

  test('completed list is empty when the user has no completed runs', () {
    final open = sampleOpenChallenge();
    expect(
      completedChallengesForProfile(
        published: [open.challenge],
        completedProgress: const [
          ChallengeProgress(
            challengeId: 'open-1',
            status: ChallengeRunStatus.inProgress,
            completedWaypointIds: {'ow-1'},
          ),
        ],
      ),
      isEmpty,
    );
  });

  test('completed list uses published titles, newest first', () {
    final open = sampleOpenChallenge();
    final story = sampleStoryChallenge();
    final completed = completedChallengesForProfile(
      published: [open.challenge, story.challenge],
      completedProgress: [
        ChallengeProgress(
          challengeId: 'open-1',
          status: ChallengeRunStatus.completed,
          completedWaypointIds: const {'ow-1', 'ow-2'},
          completedAt: DateTime.utc(2026, 1, 1),
        ),
        ChallengeProgress(
          challengeId: 'story-1',
          status: ChallengeRunStatus.completed,
          completedWaypointIds: const {'sw-1', 'sw-2'},
          completedAt: DateTime.utc(2026, 6, 1),
        ),
        const ChallengeProgress(
          challengeId: 'gone-1',
          status: ChallengeRunStatus.completed,
          completedWaypointIds: {},
        ),
      ],
    );
    expect(completed.map((c) => c.id), ['story-1', 'open-1']);
    expect(completed.first.copyFor('en').title, 'Story trail');
    expect(completed.last.copyFor('cs').title, 'Otevřená stezka');
  });
}
