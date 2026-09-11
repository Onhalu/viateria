enum AccessMode { open, story }

enum PricingType { free, paid }

enum PublishStatus { draft, published, archived }

enum TravelMode { hike, bike }

enum Difficulty { easy, moderate, hard, expert }

enum ChallengeRunStatus { inProgress, completed }

enum PurchaseStatus { pending, paid, failed, refunded }

enum VerifyMethod { photo }

/// Reward product attached to a paid purchase (or its Stripe/product row).
enum RewardVariant { diploma, medalAndDiploma }

AccessMode accessModeFromWire(String value) => switch (value) {
  'story' => AccessMode.story,
  _ => AccessMode.open,
};

PricingType pricingTypeFromWire(String value) => switch (value) {
  'paid' => PricingType.paid,
  _ => PricingType.free,
};

PublishStatus publishStatusFromWire(String value) => switch (value) {
  'published' => PublishStatus.published,
  'archived' => PublishStatus.archived,
  _ => PublishStatus.draft,
};

ChallengeRunStatus runStatusFromWire(String value) => switch (value) {
  'completed' => ChallengeRunStatus.completed,
  _ => ChallengeRunStatus.inProgress,
};

PurchaseStatus purchaseStatusFromWire(String value) => switch (value) {
  'paid' => PurchaseStatus.paid,
  'failed' => PurchaseStatus.failed,
  'refunded' => PurchaseStatus.refunded,
  _ => PurchaseStatus.pending,
};

RewardVariant? rewardVariantFromWire(String? value) => switch (value) {
  'diploma' => RewardVariant.diploma,
  'medal_and_diploma' || 'medalAndDiploma' => RewardVariant.medalAndDiploma,
  _ => null,
};

DateTime? dateTimeFromWire(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

extension PublishStatusWire on PublishStatus {
  String get wire => name;
}

/// Catalog and promo surfaces only render [PublishStatus.published] rows.
bool isPubliclyVisible(PublishStatus status) =>
    status == PublishStatus.published;
