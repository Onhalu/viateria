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
    stripePriceIdDiploma: row['stripe_price_id_diploma'] as String?,
    stripePriceIdMedal: row['stripe_price_id_medal'] as String?,
    fapiFormUrlDiploma: httpUrlOrNull(row['fapi_form_url_diploma'] as String?),
    fapiFormUrlMedal: httpUrlOrNull(row['fapi_form_url_medal'] as String?),
    rewardVariant: rewardVariantFromWire(row['reward_variant'] as String?),
    translations: i18nFromRows(row['challenge_i18n']),
  );
}

/// PostgREST embed of `places` via `waypoints_place_id_fkey` (migration 0013).
/// List length and the planner read lat/lng from this object in [waypointFromRow].
const waypointPlaceEmbed =
    'places!waypoints_place_id_fkey(id, lat, lng, elevation_m)';

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
