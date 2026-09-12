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

const _enShortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Narrow no-break space for CS grouping and the currency gap (`1 249 Kč`).
const priceThinSpace = '\u202F';

/// Catalog / pay-CTA amount from minor units + UI locale.
/// CS CZK → `1 249 Kč` (thin-space grouping). Null / ≤0 → no display string.
String? formatChallengePrice(
  int? cents,
  String currency, [
  String locale = 'en',
]) {
  if (cents == null || cents <= 0) return null;
  final code = currency.trim().toLowerCase();
  final csStyle = locale == 'cs' || locale == 'de';
  final grouped = _groupThousands(cents ~/ 100, csStyle ? priceThinSpace : ',');
  final frac = cents % 100;
  final needsFraction = code == 'eur' || frac != 0;
  final amount = needsFraction
      ? '$grouped${csStyle ? ',' : '.'}${frac.toString().padLeft(2, '0')}'
      : grouped;
  return switch (code) {
    'czk' || 'kc' || 'kč' => '$amount${priceThinSpace}Kč',
    'eur' => csStyle ? '$amount$priceThinSpace€' : '€$amount',
    _ => '$amount ${currency.trim().toUpperCase()}',
  };
}

String _groupThousands(int value, String separator) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final buf = StringBuffer();
  final lead = digits.length % 3;
  if (lead > 0) buf.write(digits.substring(0, lead));
  for (var i = lead; i < digits.length; i += 3) {
    if (buf.isNotEmpty) buf.write(separator);
    buf.write(digits.substring(i, i + 3));
  }
  return buf.toString();
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
    _ => '${_enShortMonths[month - 1]} $day, $year',
  };
}
