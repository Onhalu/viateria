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
    stripePriceId: row['stripe_price_id'] as String?,
    stripePriceIdDiploma: row['stripe_price_id_diploma'] as String?,
    stripePriceIdMedal: row['stripe_price_id_medal'] as String?,
    fapiFormUrlDiploma: httpUrlOrNull(row['fapi_form_url_diploma'] as String?),
    fapiFormUrlMedal: httpUrlOrNull(row['fapi_form_url_medal'] as String?),
    rewardVariant: rewardVariantFromWire(row['reward_variant'] as String?),
    translations: i18nFromRows(row['challenge_i18n']),
  );
}

Waypoint waypointFromRow(Map<String, dynamic> row) {
  return Waypoint(
    id: row['id'] as String,
    challengeId: row['challenge_id'] as String,
    sortOrder: (row['sort_order'] as num).toInt(),
    lat: (row['lat'] as num).toDouble(),
    lng: (row['lng'] as num).toDouble(),
    elevationM: (row['elevation_m'] as num?)?.toDouble() ?? 0,
    translations: i18nFromRows(row['waypoint_i18n']),
  );
}
