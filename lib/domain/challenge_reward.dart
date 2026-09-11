import 'package:intl/intl.dart';

import '../models/models.dart';

/// Completion window for every challenge until per-challenge windows exist.
abstract final class ChallengeCompletionWindow {
  static const months = 6;

  /// `paidAt + 6 months`. Null when the purchase is unpaid / [paidAt] unknown.
  static DateTime? completeBy(DateTime? paidAt) {
    if (paidAt == null) return null;
    return DateTime(
      paidAt.year,
      paidAt.month + months,
      paidAt.day,
      paidAt.hour,
      paidAt.minute,
      paidAt.second,
      paidAt.millisecond,
      paidAt.microsecond,
    );
  }
}

/// Locked/unlocked reward rules for challenge detail.
abstract final class ChallengeReward {
  /// Unlocked when the run is complete and the purchase is paid.
  /// Free challenges have no purchase — complete is enough.
  static bool isUnlocked({
    required bool challengeCompleted,
    required bool purchasePaid,
    bool requiresPurchase = true,
  }) {
    if (!challengeCompleted) return false;
    if (!requiresPurchase) return true;
    return purchasePaid;
  }

  /// Variant is known from a paid purchase, else from the product.
  /// Unpaid / unknown → `null` (generic diploma + medal placeholders).
  static RewardVariant? variant({
    Purchase? purchase,
    RewardVariant? productVariant,
  }) {
    if (purchase == null || !purchase.isPaid) return null;
    return purchase.rewardVariant ?? productVariant;
  }
}

/// Locale-typical calendar date (no time). Uses the device local calendar day.
String formatLocalDate(DateTime date, String locale) {
  final local = date.toLocal();
  final day = local.day;
  final month = local.month;
  final year = local.year;
  return switch (locale) {
    'cs' => '$day. $month. $year',
    'de' =>
      '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year',
    _ => DateFormat.yMMMd('en').format(local),
  };
}
