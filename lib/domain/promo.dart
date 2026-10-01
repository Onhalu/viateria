import '../l10n/app_strings.dart';
import '../models/models.dart';

/// Who a promo assignment points at. Mirrors `promo_assignments.target_type`.
enum PromoTargetType { all, user, segment, locale, country }

class PromoAssignment {
  const PromoAssignment({
    required this.targetType,
    this.userId,
    this.segmentId,
    this.locale,
    this.countryCode,
  });

  final PromoTargetType targetType;
  final String? userId;
  final String? segmentId;
  final String? locale;
  final String? countryCode;
}

/// Caller used by [promoMatchesViewer]. Segment ids are the viewer's
/// `promo_segment_members` rows.
class PromoViewer {
  const PromoViewer({
    required this.userId,
    this.locale,
    this.countryCode,
    this.segmentIds = const {},
  });

  final String userId;
  final String? locale;
  final String? countryCode;
  final Set<String> segmentIds;
}

/// Zero assignments means everyone. Otherwise any one row is enough.
bool promoMatchesViewer(List<PromoAssignment> assignments, PromoViewer viewer) {
  if (assignments.isEmpty) return true;
  for (final assignment in assignments) {
    switch (assignment.targetType) {
      case PromoTargetType.all:
        return true;
      case PromoTargetType.user:
        if (assignment.userId != null && assignment.userId == viewer.userId) {
          return true;
        }
      case PromoTargetType.segment:
        final segmentId = assignment.segmentId;
        if (segmentId != null && viewer.segmentIds.contains(segmentId)) {
          return true;
        }
      case PromoTargetType.locale:
        final locale = viewer.locale;
        if (locale != null &&
            locale.isNotEmpty &&
            assignment.locale == locale) {
          return true;
        }
      case PromoTargetType.country:
        final viewerCode = viewer.countryCode?.trim().toUpperCase();
        final targetCode = assignment.countryCode?.trim().toUpperCase();
        if (viewerCode != null &&
            viewerCode.isNotEmpty &&
            viewerCode == targetCode) {
          return true;
        }
    }
  }
  return false;
}

/// Published stripes inside the schedule, lowest [PromoStripe.sortOrder] first.
List<PromoStripe> visiblePromos(Iterable<PromoStripe> promos, DateTime now) {
  final active = [
    for (final promo in promos)
      if (promo.isActiveAt(now)) promo,
  ];
  active.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    return a.id.compareTo(b.id);
  });
  return active;
}

/// Snap-carousel item width. [contentWidth] is the promo slot after the
/// catalog list's 16 + 16 padding. The next card peeks 24px.
double promoCarouselItemWidth(double contentWidth) {
  if (contentWidth <= 24) return contentWidth;
  return contentWidth - 24;
}

/// Countdown copy for a stripe [endsAt].
///
/// Null [endsAt] returns null (no row). Within 48 hours: ceil hours, and
/// under one hour a dedicated phrase. Otherwise a calendar date, with the
/// year only when it is not [now]'s year.
String? promoValidityLabel({
  required DateTime now,
  required DateTime? endsAt,
  required AppStrings strings,
}) {
  if (endsAt == null) return null;
  final remaining = endsAt.difference(now);
  if (remaining.isNegative) return null;
  if (remaining <= const Duration(hours: 48)) {
    if (remaining < const Duration(hours: 1)) return strings.promoUnderHour;
    return strings.promoHoursLeft(_ceilHours(remaining));
  }
  return strings.promoValidUntil(promoUntilDate(endsAt, now));
}

/// `D. M.` in the viewer's local calendar, plus the year when it differs.
String promoUntilDate(DateTime endsAt, DateTime now) {
  final end = endsAt.toLocal();
  final today = now.toLocal();
  final date = '${end.day}. ${end.month}.';
  if (end.year == today.year) return date;
  return '$date ${end.year}';
}

int _ceilHours(Duration remaining) {
  const hourMicros = 3600 * 1000 * 1000;
  final micros = remaining.inMicroseconds;
  if (micros <= 0) return 0;
  return (micros + hourMicros - 1) ~/ hourMicros;
}
