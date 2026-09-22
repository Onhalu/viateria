import 'package:latlong2/latlong.dart';

import '../map/place_category.dart';
import 'enums.dart';

export 'enums.dart';

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

LocalizedText pickLocale(
  List<LocalizedText> texts,
  String locale, {
  String fallback = 'en',
}) {
  for (final candidate in [locale, fallback, 'cs', 'en', 'de']) {
    for (final text in texts) {
      if (text.locale == candidate) return text;
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
    this.stripePriceIdDiploma,
    this.stripePriceIdMedal,
    this.fapiFormUrlDiploma,
    this.fapiFormUrlMedal,
    this.rewardVariant,
    this.diplomaPriceCents,
    this.medalPriceCents,
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

  /// Free-text place / range label for cards (Pálava, Beskydy, …).
  final String? region;

  /// ISO 3166-1 alpha-2 used by catalog region chips: CZ SK AT DE PL.
  final String? countryCode;

  /// CMS `easy` / `normal` / `hard`. Null hides the catalog label.
  final CatalogDifficulty? difficulty;

  /// Legacy shared Stripe Price id. Used when a per-SKU id is unset.
  final String? stripePriceId;
  final String? stripePriceIdDiploma;
  final String? stripePriceIdMedal;

  /// Public FAPI sales-form page for Digitální diplom. Null / blank disables
  /// that CTA. Prefill query params are added by `start-fapi-checkout`.
  final String? fapiFormUrlDiploma;

  /// Public FAPI sales-form page for Medaile + diplom. Null / blank disables
  /// that CTA.
  final String? fapiFormUrlMedal;
  final RewardVariant? rewardVariant;

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

  String? stripePriceIdFor(RewardVariant variant) => switch (variant) {
    RewardVariant.diploma => stripePriceIdDiploma ?? stripePriceId,
    RewardVariant.medalAndDiploma => stripePriceIdMedal ?? stripePriceId,
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

  /// Map category used for the waypoint-list icon. Wire values come from
  /// `waypoints.category` via [PlaceCategory.fromWire].
  final PlaceCategory category;
  final VerifyMethod verifyMethod;

  LatLng get latLng => LatLng(lat, lng);

  LocalizedText copyFor(String locale) => pickLocale(translations, locale);
}

class ChallengeDetail {
  const ChallengeDetail({required this.challenge, required this.waypoints});

  final Challenge challenge;
  final List<Waypoint> waypoints;

  List<Waypoint> get orderedWaypoints {
    final copy = [...waypoints];
    copy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return copy;
  }
}

class PromoStripe {
  const PromoStripe({
    required this.id,
    required this.status,
    required this.sortOrder,
    required this.translations,
    this.imageUrl,
    this.linkUrl,
    this.challengeId,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final PublishStatus status;
  final int sortOrder;
  final List<LocalizedText> translations;
  final String? imageUrl;
  final String? linkUrl;
  final String? challengeId;
  final DateTime? startsAt;
  final DateTime? endsAt;

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
    this.completedAt,
  });

  final String challengeId;
  final ChallengeRunStatus status;
  final Set<String> completedWaypointIds;
  final DateTime? completedAt;

  bool get isCompleted => status == ChallengeRunStatus.completed;
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
