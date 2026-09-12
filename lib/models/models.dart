import 'package:latlong2/latlong.dart';

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
    this.stripePriceId,
    this.stripePriceIdDiploma,
    this.stripePriceIdMedal,
    this.rewardVariant,
    int? diplomaPriceCents,
    int? medalPriceCents,
  }) : diplomaPriceCents = diplomaPriceCents ?? priceCents,
       medalPriceCents = medalPriceCents ?? priceCents;

  final String id;
  final String slug;
  final AccessMode accessMode;
  final PricingType pricingType;

  /// Catalog-card fallback. Same as the diploma (entry) SKU when
  /// [diplomaPriceCents] is not stored separately.
  final int priceCents;

  /// Digitální diplom / [RewardVariant.diploma].
  final int diplomaPriceCents;

  /// Medaile + diplom / [RewardVariant.medalAndDiploma].
  final int medalPriceCents;
  final String currency;
  final PublishStatus status;
  final List<LocalizedText> translations;
  final String? coverImageUrl;
  final String? region;

  /// Legacy shared Stripe Price id. Used when a per-SKU id is unset.
  final String? stripePriceId;
  final String? stripePriceIdDiploma;
  final String? stripePriceIdMedal;
  final RewardVariant? rewardVariant;

  bool get isPaid => pricingType == PricingType.paid;

  int priceCentsFor(RewardVariant variant) => switch (variant) {
    RewardVariant.diploma => diplomaPriceCents,
    RewardVariant.medalAndDiploma => medalPriceCents,
  };

  String? stripePriceIdFor(RewardVariant variant) => switch (variant) {
    RewardVariant.diploma => stripePriceIdDiploma ?? stripePriceId,
    RewardVariant.medalAndDiploma => stripePriceIdMedal ?? stripePriceId,
  };

  LocalizedText copyFor(String locale) => pickLocale(translations, locale);
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
    this.verifyMethod = VerifyMethod.photo,
  });

  final String id;
  final String challengeId;
  final int sortOrder;
  final double lat;
  final double lng;
  final double elevationM;
  final List<LocalizedText> translations;
  final VerifyMethod verifyMethod;

  LatLng get latLng => LatLng(lat, lng);

  LocalizedText copyFor(String locale) => pickLocale(translations, locale);
}

class ChallengeDetail {
  const ChallengeDetail({
    required this.challenge,
    required this.waypoints,
  });

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
