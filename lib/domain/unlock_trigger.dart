/// When the padlock may play. SPEC §15.1. Paid-challenge unlock is out of scope.
enum UnlockTrigger {
  serverMembershipActive,
  fapiCtaTap,
  paywallOpen,
  checkoutCancel,
  checkoutError,
  redemptionCode,
  storyNextPoint,
}

bool playsUnlockAnimation(UnlockTrigger trigger) {
  return trigger == UnlockTrigger.serverMembershipActive;
}

/// One play per session per entity. Not persisted.
class UnlockReplayMemory {
  final Set<String> _played = {};

  bool claim(String entityId) => _played.add(entityId);

  bool hasPlayed(String entityId) => _played.contains(entityId);

  void reset() => _played.clear();
}

const membershipUnlockEntity = 'vandery-plus-membership';

final unlockReplayMemory = UnlockReplayMemory();
