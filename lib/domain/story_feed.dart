import '../models/models.dart';
import 'unlock_rules.dart';

/// One row in the challenge stop list.
sealed class ChallengeFeedItem {
  const ChallengeFeedItem();
}

class StoryFeedChapter extends ChallengeFeedItem {
  const StoryFeedChapter(this.step);

  final StoryStep step;
}

class StoryFeedPlace extends ChallengeFeedItem {
  const StoryFeedPlace({
    required this.waypoint,
    required this.index,
    required this.unlocked,
    required this.completed,
  });

  final Waypoint waypoint;
  final int index;
  final bool unlocked;
  final bool completed;
}

/// List order for a challenge.
///
/// Open mode is the waypoint list alone — story steps are ignored.
/// Story mode is opening → (chapter for a stop, once that chapter is
/// unlocked) → the stop, repeating → closing after the last verify.
/// A step with no YouTube, image, or body is skipped. The place stays.
List<ChallengeFeedItem> buildChallengeFeed({
  required AccessMode mode,
  required bool hasAccess,
  required List<Waypoint> ordered,
  required List<StoryStep> steps,
  required Set<String> completedIds,
  UnlockRules rules = const UnlockRules(),
}) {
  final completedIndexes = <int>{
    for (var i = 0; i < ordered.length; i++)
      if (completedIds.contains(ordered[i].id)) i,
  };
  bool unlockedAt(int index) {
    return rules.isWaypointUnlocked(
      mode: mode,
      hasAccess: hasAccess,
      waypointIndex: index,
      completedIndexes: completedIndexes,
    );
  }

  if (mode != AccessMode.story) {
    return [
      for (var i = 0; i < ordered.length; i++)
        StoryFeedPlace(
          waypoint: ordered[i],
          index: i,
          unlocked: unlockedAt(i),
          completed: completedIds.contains(ordered[i].id),
        ),
    ];
  }

  final items = <ChallengeFeedItem>[];
  StoryStep? opening;
  StoryStep? closing;
  final before = <String, StoryStep>{};
  for (final step in steps) {
    if (!step.hasChapterMedia) continue;
    switch (step.kind) {
      case StoryStepKind.opening:
        opening ??= step;
      case StoryStepKind.closing:
        closing ??= step;
      case StoryStepKind.beforeWaypoint:
        final waypointId = step.waypointId;
        if (waypointId != null) before[waypointId] = step;
    }
  }

  if (opening != null &&
      _chapterVisible(
        step: opening,
        hasAccess: hasAccess,
        ordered: ordered,
        completedIds: completedIds,
      )) {
    items.add(StoryFeedChapter(opening));
  }

  for (var i = 0; i < ordered.length; i++) {
    final waypoint = ordered[i];
    final chapter = before[waypoint.id];
    if (chapter != null &&
        _chapterVisible(
          step: chapter,
          hasAccess: hasAccess,
          ordered: ordered,
          completedIds: completedIds,
        )) {
      items.add(StoryFeedChapter(chapter));
    }
    items.add(
      StoryFeedPlace(
        waypoint: waypoint,
        index: i,
        unlocked: unlockedAt(i),
        completed: completedIds.contains(waypoint.id),
      ),
    );
  }

  if (closing != null &&
      _chapterVisible(
        step: closing,
        hasAccess: hasAccess,
        ordered: ordered,
        completedIds: completedIds,
      )) {
    items.add(StoryFeedChapter(closing));
  }
  return items;
}

bool _chapterVisible({
  required StoryStep step,
  required bool hasAccess,
  required List<Waypoint> ordered,
  required Set<String> completedIds,
}) {
  if (!hasAccess || !step.hasChapterMedia) return false;
  switch (step.kind) {
    case StoryStepKind.opening:
      return true;
    case StoryStepKind.closing:
      if (ordered.isEmpty) return false;
      return ordered.every((waypoint) => completedIds.contains(waypoint.id));
    case StoryStepKind.beforeWaypoint:
      final index = ordered.indexWhere(
        (waypoint) => waypoint.id == step.waypointId,
      );
      if (index < 0) return false;
      if (index == 0) return true;
      return completedIds.contains(ordered[index - 1].id);
  }
}

/// Generic locked label in story mode. Open mode and unlocked stops keep
/// the authored place name.
String storyPlaceTitle({
  required AccessMode mode,
  required bool unlocked,
  required Waypoint waypoint,
  required String locale,
  required String lockedTitle,
}) {
  if (mode == AccessMode.story && !unlocked) return lockedTitle;
  return waypoint.copyFor(locale).title;
}

/// Ids the server returns from `verify_waypoint`, derived locally when the
/// RPC payload omits them (memory tests, older responses).
({
  String? nextStoryStepId,
  String? closingStoryStepId,
  String? unlockedWaypointId,
})
storyStepIdsAfterVerify({
  required ChallengeDetail detail,
  required String verifiedWaypointId,
  required Set<String> completedIds,
}) {
  if (detail.challenge.accessMode != AccessMode.story) {
    return (
      nextStoryStepId: null,
      closingStoryStepId: null,
      unlockedWaypointId: null,
    );
  }
  final ordered = detail.orderedWaypoints;
  final index = ordered.indexWhere(
    (waypoint) => waypoint.id == verifiedWaypointId,
  );
  final finished =
      ordered.isNotEmpty &&
      ordered.every((waypoint) => completedIds.contains(waypoint.id));
  if (finished) {
    String? closing;
    for (final step in detail.orderedStorySteps) {
      if (step.kind == StoryStepKind.closing) {
        closing = step.id;
        break;
      }
    }
    return (
      nextStoryStepId: null,
      closingStoryStepId: closing,
      unlockedWaypointId: null,
    );
  }
  if (index < 0 || index + 1 >= ordered.length) {
    return (
      nextStoryStepId: null,
      closingStoryStepId: null,
      unlockedWaypointId: null,
    );
  }
  final next = ordered[index + 1];
  String? chapter;
  for (final step in detail.orderedStorySteps) {
    if (step.kind == StoryStepKind.beforeWaypoint &&
        step.waypointId == next.id) {
      chapter = step.id;
      break;
    }
  }
  return (
    nextStoryStepId: chapter,
    closingStoryStepId: null,
    unlockedWaypointId: next.id,
  );
}
