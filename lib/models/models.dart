import 'package:latlong2/latlong.dart';

import '../map/place_category.dart';
import 'enums.dart';

export 'enums.dart';
export 'leaderboard_entry.dart';

class LocalizedText {
  const LocalizedText({
    required this.locale,
    required this.title,
    this.description = '',
    this.subtitle,
    this.ctaLabel,
    this.diplomaHeadline,
    this.diplomaBody,
    this.hint,
  });

  final String locale;
  final String title;
  final String description;
  final String? subtitle;
  final String? ctaLabel;
  final String? diplomaHeadline;
  final String? diplomaBody;
  final String? hint;
}

/// Preferred locale, then Czech, then English, then German.
///
/// A blank title counts as missing, matching `private.pick_locale`.
LocalizedText pickLocale(
  List<LocalizedText> texts,
  String locale, {
  String fallback = 'cs',
}) {
  final order = <String>[];
  for (final candidate in [locale, fallback, 'cs', 'en', 'de']) {
    if (!order.contains(candidate)) order.add(candidate);
  }
  for (final candidate in order) {
    for (final text in texts) {
      if (text.locale == candidate && text.title.trim().isNotEmpty) {
        return text;
      }
    }
  }
  if (texts.isEmpty) {
    return LocalizedText(locale: locale, title: '');
  }
  return texts.first;
}

class Challenge {
  const Challenge({
    required this.id,
    required this.slug,
    required this.accessMode,
    required this.pricingType,
    required this.priceCents,
    required this.currency,
    required this.status,
    required this.translations,
    this.coverImageUrl,
    this.region,
    this.countryCode,
    this.difficulty,
    this.stripePriceId,
    this.fapiFormUrlDiploma,
    this.fapiFormUrlMedal,
    this.rewardVariant,
    this.diplomaPriceCents,
    this.medalPriceCents,
    this.length,
    this.isPromo = false,
  });

  final String id;
  final String slug;
  final AccessMode accessMode;
  final PricingType pricingType;

  /// Catalog-card fallback. Same as the diploma (entry) SKU when
  /// [diplomaPriceCents] is not stored separately.
  final int priceCents;

  /// Digitální diplom / [RewardVariant.diploma]. Null when unset in the catalog.
  final int? diplomaPriceCents;

  /// Medaile + diplom / [RewardVariant.medalAndDiploma] total. Null when unset.
  final int? medalPriceCents;
  final String currency;
  final PublishStatus status;
  final List<LocalizedText> translations;
  final String? coverImageUrl;

  /// Free-text place label from `challenges.region` (Beskydy, Česko, …).
  /// Catalog country chips use [countryCode], not this string.
  final String? region;

  /// ISO codes from `challenges.country_code` (`CZ` or `CZ,AT`), or one
  /// code inferred from [region] when that column is empty. Catalog flags
  /// match when the selected code is in this list.
  final String? countryCode;

  /// CMS `easy` / `normal` / `hard`. Null hides the catalog label.
  final CatalogDifficulty? difficulty;

  /// Legacy shared Stripe Price id (`challenges.stripe_price_id`).
  /// `stripe_price_id_diploma` / `stripe_price_id_medal` are not on prod.
  final String? stripePriceId;

  /// Public FAPI sales-form page for Digitální diplom. Null / blank disables
  /// that CTA. Prefill query params are added by `start-fapi-checkout`.
  final String? fapiFormUrlDiploma;

  /// Public FAPI sales-form page for Medaile + diplom. Null / blank disables
  /// that CTA.
  final String? fapiFormUrlMedal;
  final RewardVariant? rewardVariant;

  /// CMS `challenges.length` (`short` | `medium` | `long`). Null hides the
  /// CMS band so cards fall back to hike-time length.
  final ChallengeLength? length;

  /// Exclusive promo challenge. Ordinary catalog queries omit these rows.
  /// Detail still opens when the caller has a matching active promo.
  final bool isPromo;

  bool get isPaid => pricingType == PricingType.paid;

  int? skuPriceCents(RewardVariant variant) => switch (variant) {
    RewardVariant.diploma => diplomaPriceCents,
    RewardVariant.medalAndDiploma => medalPriceCents,
  };

  /// Pay-CTA amount. Diploma may use [priceCents] when the SKU column is
  /// missing. Null / ≤0 means the price line should be hidden.
  int? displayPriceCents(RewardVariant variant) {
    final sku = skuPriceCents(variant);
    if (sku != null) return sku > 0 ? sku : null;
    if (variant == RewardVariant.diploma && priceCents > 0) return priceCents;
    return null;
  }

  /// Both reward variants share [stripePriceId]. Per-SKU Stripe columns
  /// are not read; they are not on prod.
  String? stripePriceIdFor(RewardVariant variant) => switch (variant) {
    RewardVariant.diploma || RewardVariant.medalAndDiploma => stripePriceId,
  };

  /// http(s) FAPI form URL for [variant], or null when unset / not openable.
  String? fapiFormUrlFor(RewardVariant variant) => switch (variant) {
    RewardVariant.diploma => httpUrlOrNull(fapiFormUrlDiploma),
    RewardVariant.medalAndDiploma => httpUrlOrNull(fapiFormUrlMedal),
  };

  LocalizedText copyFor(String locale) => pickLocale(translations, locale);
}

/// Trims [value] and keeps it only when it is an absolute http(s) URL.
String? httpUrlOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return trimmed;
}

class Waypoint {
  const Waypoint({
    required this.id,
    required this.challengeId,
    required this.sortOrder,
    required this.lat,
    required this.lng,
    required this.elevationM,
    required this.translations,
    this.placeId,
    this.category = PlaceCategory.historical,
    this.verifyMethod = VerifyMethod.photo,
  });

  final String id;
  final String challengeId;
  final int sortOrder;
  final double lat;
  final double lng;
  final double elevationM;
  final List<LocalizedText> translations;

  /// `waypoints.place_id`. Map tint and verify use this id, not proximity.
  final String? placeId;

  /// Map category used for the waypoint-list icon. Wire values come from
  /// `waypoints.category` via [PlaceCategory.fromWire].
  final PlaceCategory category;
  final VerifyMethod verifyMethod;

  LatLng get latLng => LatLng(lat, lng);

  LocalizedText copyFor(String locale) => pickLocale(translations, locale);
}

class ChallengeDetail {
  const ChallengeDetail({
    required this.challenge,
    required this.waypoints,
    this.storySteps = const [],
  });

  final Challenge challenge;
  final List<Waypoint> waypoints;

  /// Rows from `challenge_story_steps`. Ignored when [Challenge.accessMode]
  /// is [AccessMode.open].
  final List<StoryStep> storySteps;

  List<Waypoint> get orderedWaypoints {
    final copy = [...waypoints];
    copy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return copy;
  }

  List<StoryStep> get orderedStorySteps {
    final copy = [...storySteps];
    copy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return copy;
  }
}

/// One `challenge_story_steps` row plus its `challenge_story_step_i18n` copy.
class StoryStep {
  const StoryStep({
    required this.id,
    required this.challengeId,
    required this.sortOrder,
    required this.kind,
    required this.translations,
    this.waypointId,
    this.imageUrl,
    this.youtubeUrl,
  });

  final String id;
  final String challengeId;
  final int sortOrder;
  final StoryStepKind kind;

  /// Set only for [StoryStepKind.beforeWaypoint].
  final String? waypointId;
  final String? imageUrl;
  final String? youtubeUrl;
  final List<LocalizedText> translations;

  LocalizedText copyFor(String locale) => pickLocale(translations, locale);

  /// YouTube, a cover image, or a non-empty body in any locale.
  ///
  /// A title with no media is skipped in the list. The place tile stays.
  bool get hasChapterMedia {
    final video = youtubeUrl?.trim();
    if (video != null && video.isNotEmpty) return true;
    final image = imageUrl?.trim();
    if (image != null && image.isNotEmpty) return true;
    for (final text in translations) {
      if (text.description.trim().isNotEmpty) return true;
    }
    return false;
  }
}

class PromoStripe {
  const PromoStripe({
    required this.id,
    required this.status,
    required this.sortOrder,
    required this.translations,
    this.kind = PromoKind.discount,
    this.imageUrl,
    this.linkUrl,
    this.challengeId,
    this.startsAt,
    this.endsAt,
    this.promoDiplomaPriceCents,
    this.promoMedalPriceCents,
  });

  final String id;
  final PublishStatus status;
  final PromoKind kind;
  final int sortOrder;
  final List<LocalizedText> translations;
  final String? imageUrl;
  final String? linkUrl;
  final String? challengeId;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Discount-stripe diploma price. Null keeps the challenge price.
  final int? promoDiplomaPriceCents;

  /// Discount-stripe medal + diploma price. Null keeps the challenge price.
  final int? promoMedalPriceCents;

  bool get hasCover {
    final url = imageUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  bool get hasTarget {
    final id = challengeId?.trim();
    if (id != null && id.isNotEmpty) return true;
    final url = linkUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  bool isActiveAt(DateTime now) {
    if (!isPubliclyVisible(status)) return false;
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  LocalizedText copyFor(String locale) => pickLocale(translations, locale);
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.challengeId,
    required this.status,
    required this.completedWaypointIds,
    this.startedAt,
    this.completedAt,
    this.duration,
    this.nextStoryStepId,
    this.closingStoryStepId,
    this.unlockedWaypointId,
  });

  final String challengeId;
  final ChallengeRunStatus status;
  final Set<String> completedWaypointIds;

  /// First successful verify (`challenge_participations.started_at`).
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// `completed_at - started_at` when the participation row stores it.
  final Duration? duration;

  /// `verify_waypoint` → `next_story_step_id`. Null on a plain progress read.
  final String? nextStoryStepId;

  /// `verify_waypoint` → `closing_story_step_id` after the last stop.
  final String? closingStoryStepId;

  /// `verify_waypoint` → `unlocked_waypoint_id` (the next stop, if any).
  final String? unlockedWaypointId;

  bool get isCompleted => status == ChallengeRunStatus.completed;

  /// Chapter to scroll to after this verify. Closing wins when the run is done.
  String? get revealStoryStepId => closingStoryStepId ?? nextStoryStepId;

  /// Inclusive UTC day count from [startedAt] to [completedAt].
  ///
  /// Same calendar day is 1. Falls back to whole days of [duration].
  int? get inclusiveDayCount {
    final start = startedAt;
    final end = completedAt;
    if (start != null && end != null) {
      final a = DateTime.utc(
        start.toUtc().year,
        start.toUtc().month,
        start.toUtc().day,
      );
      final b = DateTime.utc(
        end.toUtc().year,
        end.toUtc().month,
        end.toUtc().day,
      );
      final days = b.difference(a).inDays + 1;
      if (days >= 1) return days;
    }
    final span = duration;
    if (span != null && span.inDays >= 1) return span.inDays;
    return null;
  }
}

/// Issued `challenge_diplomas` row (`user_id` set). Templates stay on the
/// catalog view (`diploma_headline` / `diploma_body`).
class IssuedDiploma {
  const IssuedDiploma({
    required this.challengeId,
    this.headline,
    this.body,
    this.recipientName,
    this.recipientNameDisplay,
    this.challengeTitle,
    this.completedAt,
    this.duration,
    this.lang,
    this.periodDays,
  });

  final String challengeId;
  final String? headline;
  final String? body;
  final String? recipientName;
  final String? recipientNameDisplay;
  final String? challengeTitle;
  final DateTime? completedAt;
  final Duration? duration;
  final String? lang;

  /// Inclusive calendar days from migration 0026 (`period_days`). Audit only.
  /// The diploma line is [formatDiplomaCompletedOn], not a day count.
  final int? periodDays;

  int? get displayDayCount {
    final days = periodDays;
    if (days != null && days >= 1) return days;
    final span = duration;
    if (span != null && span.inDays >= 1) return span.inDays;
    return null;
  }
}

/// Diploma line (cs v1): `dokončeno dne dd.mm.yyyy` from [completedAt] in Europe/Prague.
String formatDiplomaCompletedOn(DateTime completedAt) {
  final wall = pragueWallClock(completedAt);
  final dd = wall.day.toString().padLeft(2, '0');
  final mm = wall.month.toString().padLeft(2, '0');
  return 'dokončeno dne $dd.$mm.${wall.year}';
}

/// Europe/Prague wall clock (CET/CEST). DST follows the EU rule.
DateTime pragueWallClock(DateTime instant) {
  final utc = instant.toUtc();
  return utc.add(_pragueOffset(utc));
}

Duration _pragueOffset(DateTime utc) {
  final start = _euDstStart(utc.year);
  final end = _euDstEnd(utc.year);
  final inDst = !utc.isBefore(start) && utc.isBefore(end);
  return Duration(hours: inDst ? 2 : 1);
}

DateTime _euDstStart(int year) =>
    _lastSundayUtc(year, 3).add(const Duration(hours: 1));

DateTime _euDstEnd(int year) =>
    _lastSundayUtc(year, 10).add(const Duration(hours: 1));

DateTime _lastSundayUtc(int year, int month) {
  final nextMonth = month == 12
      ? DateTime.utc(year + 1, 1, 1)
      : DateTime.utc(year, month + 1, 1);
  var day = nextMonth.subtract(const Duration(days: 1));
  while (day.weekday != DateTime.sunday) {
    day = day.subtract(const Duration(days: 1));
  }
  return DateTime.utc(day.year, day.month, day.day);
}

/// `1 den` / `3 dny` / `5 dní`, with en/de plurals.
String formatParticipationDays(String locale, int days) {
  if (days < 1) return '';
  switch (locale) {
    case 'cs':
      if (days % 10 == 1 && days % 100 != 11) return '$days den';
      final teen = days % 100;
      if (days % 10 >= 2 && days % 10 <= 4 && (teen < 12 || teen > 14)) {
        return '$days dny';
      }
      return '$days dní';
    case 'de':
      return days == 1 ? '1 Tag' : '$days Tage';
    default:
      return days == 1 ? '1 day' : '$days days';
  }
}

/// One `waypoint_progress` photo row for a challenge waypoint.
///
/// [photoPath] is the object key in the `waypoint-photos` bucket. The gallery
/// query does not filter by user, so rows may belong to someone else.
class ChallengeWaypointPhoto {
  const ChallengeWaypointPhoto({
    required this.challengeId,
    required this.waypointId,
    required this.photoPath,
    required this.completedAt,
  });

  final String challengeId;
  final String waypointId;
  final String photoPath;
  final DateTime completedAt;
}

class Purchase {
  const Purchase({
    required this.challengeId,
    required this.status,
    this.checkoutUrl,
    this.paidAt,
    this.rewardVariant,
  });

  final String challengeId;
  final PurchaseStatus status;
  final String? checkoutUrl;

  /// Set when [status] becomes [PurchaseStatus.paid]. Null while unpaid.
  final DateTime? paidAt;
  final RewardVariant? rewardVariant;

  bool get isPaid => status == PurchaseStatus.paid;
}

class Profile {
  const Profile({
    required this.id,
    required this.locale,
    this.displayName,
    this.email,
  });

  final String id;
  final String locale;
  final String? displayName;
  final String? email;
}

class CheckoutSession {
  const CheckoutSession({required this.url});

  final String url;
}
