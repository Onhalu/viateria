import '../domain/catalog_query.dart';
import '../map/place_category.dart';
import '../models/models.dart';

List<LocalizedText> i18nFromRows(
  dynamic raw, {
  String titleKey = 'title',
  String descriptionKey = 'description',
}) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(
        (row) => LocalizedText(
          locale: row['locale'] as String? ?? 'en',
          title: row[titleKey] as String? ?? '',
          description: row[descriptionKey] as String? ?? '',
          subtitle: row['subtitle'] as String?,
          ctaLabel: row['cta_label'] as String?,
          diplomaHeadline: row['diploma_headline'] as String?,
          diplomaBody: row['diploma_body'] as String?,
          hint: row['hint'] as String?,
        ),
      )
      .toList();
}

/// Maps a `challenges` row. SKU columns stay nullable. Pay CTAs hide a
/// line when that SKU is null/≤0; diploma may use `price_cents` as the
/// catalog fallback when `diploma_price_cents` is missing. Blank FAPI
/// form URLs become null so that variant's CTA stays disabled.
Challenge challengeFromRow(Map<String, dynamic> row) {
  final priceCents = (row['price_cents'] as num?)?.toInt() ?? 0;
  return Challenge(
    id: row['id'] as String,
    slug: row['slug'] as String,
    accessMode: accessModeFromWire(row['access_mode'] as String? ?? 'open'),
    pricingType: pricingTypeFromWire(row['pricing_type'] as String? ?? 'free'),
    priceCents: priceCents,
    diplomaPriceCents: (row['diploma_price_cents'] as num?)?.toInt(),
    medalPriceCents: (row['medal_price_cents'] as num?)?.toInt(),
    currency: row['currency'] as String? ?? 'eur',
    status: publishStatusFromWire(row['status'] as String? ?? 'draft'),
    coverImageUrl: row['cover_image_url'] as String?,
    region: row['region'] as String?,
    countryCode: resolveCountryCode(
      countryCode: row['country_code'] as String?,
      region: row['region'] as String?,
    ),
    difficulty: catalogDifficultyFromWire(row['difficulty'] as String?),
    stripePriceId: row['stripe_price_id'] as String?,
    fapiFormUrlDiploma: httpUrlOrNull(row['fapi_form_url_diploma'] as String?),
    fapiFormUrlMedal: httpUrlOrNull(row['fapi_form_url_medal'] as String?),
    rewardVariant: rewardVariantFromWire(row['reward_variant'] as String?),
    isPromo: row['is_promo'] == true,
    translations: i18nFromRows(row['challenge_i18n']),
  );
}

PromoStripe promoFromRow(Map<String, dynamic> row) {
  return PromoStripe(
    id: row['id'] as String,
    status: publishStatusFromWire(row['status'] as String? ?? 'draft'),
    kind: promoKindFromWire(row['kind'] as String?),
    sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    imageUrl: row['image_url'] as String?,
    linkUrl: row['link_url'] as String?,
    challengeId: row['challenge_id'] as String?,
    startsAt: dateTimeFromWire(row['starts_at']),
    endsAt: dateTimeFromWire(row['ends_at']),
    promoDiplomaPriceCents: (row['promo_diploma_price_cents'] as num?)?.toInt(),
    promoMedalPriceCents: (row['promo_medal_price_cents'] as num?)?.toInt(),
    translations: i18nFromRows(row['promo_stripe_i18n']),
  );
}

List<PromoStripe> promosFromRpc(dynamic raw) {
  if (raw == null) return const [];
  if (raw is Map) {
    return [promoFromRow(Map<String, dynamic>.from(raw))];
  }
  if (raw is List) {
    return [
      for (final row in raw)
        if (row is Map) promoFromRow(Map<String, dynamic>.from(row)),
    ];
  }
  return const [];
}

/// PostgREST embed of `places` via `waypoints_place_id_fkey` (migration 0013).
/// List length and the planner read lat/lng from this object in [waypointFromRow].
const waypointPlaceEmbed =
    'places!waypoints_place_id_fkey(id, lat, lng, elevation_m)';

/// Story chapters. Empty for open-mode challenges. Migration 0016.
const storyStepEmbed = 'challenge_story_steps(*, challenge_story_step_i18n(*))';

Waypoint waypointFromRow(Map<String, dynamic> row) {
  final place = _placeEmbed(row['places']);
  final placeElevation = place?['elevation_m'];
  return Waypoint(
    id: row['id'] as String,
    challengeId: row['challenge_id'] as String,
    sortOrder: (row['sort_order'] as num).toInt(),
    lat: _coord(place?['lat'], row['lat']),
    lng: _coord(place?['lng'], row['lng']),
    elevationM: placeElevation is num
        ? placeElevation.toDouble()
        : (row['elevation_m'] as num?)?.toDouble() ?? 0,
    placeId: _text(row['place_id']) ?? _text(place?['id']),
    category: PlaceCategory.fromWire(
      row['category'] as String? ?? 'historical',
    ),
    translations: i18nFromRows(row['waypoint_i18n']),
  );
}

Map<String, dynamic>? _placeEmbed(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return null;
}

double _coord(Object? embedded, Object? stored) {
  if (embedded is num) return embedded.toDouble();
  return (stored as num).toDouble();
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

List<StoryStep> storyStepsFromRows(dynamic raw) {
  if (raw is! List) return const [];
  final steps = <StoryStep>[];
  for (final row in raw.whereType<Map>()) {
    final step = storyStepFromRow(Map<String, dynamic>.from(row));
    if (step != null) steps.add(step);
  }
  steps.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return steps;
}

StoryStep? storyStepFromRow(Map<String, dynamic> row) {
  final kind = storyStepKindFromWire(row['kind'] as String?);
  final id = row['id'] as String?;
  final challengeId = row['challenge_id'] as String?;
  if (kind == null || id == null || challengeId == null) return null;
  return StoryStep(
    id: id,
    challengeId: challengeId,
    sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    kind: kind,
    waypointId: _text(row['waypoint_id']),
    imageUrl: httpUrlOrNull(row['image_url'] as String?),
    youtubeUrl: _text(row['youtube_url']),
    translations: i18nFromRows(row['challenge_story_step_i18n']),
  );
}
