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

/// Relation/function missing (migration not applied yet). Column typos are
/// not included — those should surface.
bool isMissingSchemaObject({String? code, String? message}) {
  const codes = {'42P01', '42883', 'PGRST202', 'PGRST205'};
  if (code != null && codes.contains(code)) return true;
  final text = (message ?? '').toLowerCase();
  return text.contains('does not exist') ||
      text.contains('could not find the function') ||
      text.contains('could not find the table') ||
      text.contains('schema cache');
}

/// Missing column (0026 render fields before that migration).
bool isMissingColumn({String? code, String? message}) {
  if (code == '42703' || code == 'PGRST204') return true;
  final text = (message ?? '').toLowerCase();
  return text.contains('column') &&
      (text.contains('does not exist') || text.contains('schema cache'));
}

/// Wide `title_*` / `desc_*` from `challenge_catalog_v`, else narrow
/// `challenge_i18n`. Blank titles are omitted so [pickLocale] can fall
/// through cs → en → de.
List<LocalizedText> translationsFromChallengeRow(Map<String, dynamic> row) {
  final wide = _wideTranslations(row);
  if (wide.isNotEmpty) return wide;
  final embedded = i18nFromRows(row['challenge_i18n']);
  if (embedded.isNotEmpty) return embedded;
  final title = _nonEmpty(row['title']);
  if (title == null) return const [];
  return [
    LocalizedText(
      locale: row['resolved_for_locale'] as String? ?? 'cs',
      title: title,
      description: row['description'] as String? ?? '',
      diplomaHeadline: row['diploma_headline'] as String?,
      diplomaBody: row['diploma_body'] as String?,
    ),
  ];
}

List<LocalizedText> _wideTranslations(Map<String, dynamic> row) {
  final hasWide =
      row.containsKey('title_cs') ||
      row.containsKey('title_en') ||
      row.containsKey('title_de');
  if (!hasWide) return const [];
  final headline = row['diploma_headline'] as String?;
  final body = row['diploma_body'] as String?;
  final out = <LocalizedText>[];
  for (final locale in const ['cs', 'en', 'de']) {
    final title = _nonEmpty(row['title_$locale']);
    if (title == null) continue;
    out.add(
      LocalizedText(
        locale: locale,
        title: title,
        description: _nonEmpty(row['desc_$locale']) ?? '',
        diplomaHeadline: headline,
        diplomaBody: body,
      ),
    );
  }
  return out;
}

String? _nonEmpty(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

/// Maps a `challenges` row or a `challenge_catalog_v` row.
///
/// SKU columns stay nullable. Pay CTAs hide a line when that SKU is
/// null/≤0; diploma may use `price_cents` as the catalog fallback when
/// `diploma_price_cents` is missing. The catalog view has no
/// `price_cents`, so the diploma SKU fills it. Blank FAPI form URLs
/// become null so that variant's CTA stays disabled.
///
/// `stripe_price_id_diploma` / `stripe_price_id_medal` are never read.
Challenge challengeFromRow(Map<String, dynamic> row) {
  final diplomaPriceCents = (row['diploma_price_cents'] as num?)?.toInt();
  final priceCents =
      (row['price_cents'] as num?)?.toInt() ?? diplomaPriceCents ?? 0;
  return Challenge(
    id: row['id'] as String,
    slug: row['slug'] as String,
    accessMode: accessModeFromWire(row['access_mode'] as String? ?? 'open'),
    pricingType: pricingTypeFromWire(row['pricing_type'] as String? ?? 'free'),
    priceCents: priceCents,
    diplomaPriceCents: diplomaPriceCents,
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
    length: challengeLengthFromWire(row['length'] as String?),
    isPromo: row['is_promo'] == true,
    translations: translationsFromChallengeRow(row),
  );
}

/// Locale rank used by `challenge_sale_form_url`: preferred, then cs, en, de.
int saleFormLocaleRank(String locale, String preferred) {
  if (locale == preferred) return 0;
  if (locale == 'cs') return 1;
  if (locale == 'en') return 2;
  return 3;
}

bool satelliteVersionActive({
  required String status,
  DateTime? validFrom,
  DateTime? validTo,
  required DateTime now,
}) {
  if (status != 'published') return false;
  if (validFrom != null && now.isBefore(validFrom)) return false;
  if (validTo != null && !now.isBefore(validTo)) return false;
  return true;
}

/// Active published form for [rewardVariant], preferred locale → cs → en → de.
String? pickSaleFormUrl(
  Iterable<Map<String, dynamic>> forms, {
  required String challengeId,
  required String rewardVariant,
  required String locale,
  DateTime? now,
}) {
  final moment = now ?? DateTime.now().toUtc();
  final matches = <Map<String, dynamic>>[];
  for (final form in forms) {
    if (form['challenge_id'] != challengeId) continue;
    if (form['reward_variant'] != rewardVariant) continue;
    if (!satelliteVersionActive(
      status: form['status'] as String? ?? 'published',
      validFrom: dateTimeFromWire(form['valid_from']),
      validTo: dateTimeFromWire(form['valid_to']),
      now: moment,
    )) {
      continue;
    }
    if (httpUrlOrNull(form['fapi_form_url'] as String?) == null) continue;
    matches.add(form);
  }
  if (matches.isEmpty) return null;
  matches.sort((a, b) {
    final rank = saleFormLocaleRank(
      a['locale'] as String? ?? '',
      locale,
    ).compareTo(saleFormLocaleRank(b['locale'] as String? ?? '', locale));
    if (rank != 0) return rank;
    final at =
        dateTimeFromWire(a['valid_from']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final bt =
        dateTimeFromWire(b['valid_from']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return bt.compareTo(at);
  });
  return httpUrlOrNull(matches.first['fapi_form_url'] as String?);
}

/// Newest active published price row for [challengeId], or null.
Map<String, dynamic>? pickActivePrice(
  Iterable<Map<String, dynamic>> prices, {
  required String challengeId,
  DateTime? now,
}) {
  final moment = now ?? DateTime.now().toUtc();
  final matches = <Map<String, dynamic>>[];
  for (final price in prices) {
    if (price['challenge_id'] != challengeId) continue;
    if (!satelliteVersionActive(
      status: price['status'] as String? ?? 'published',
      validFrom: dateTimeFromWire(price['valid_from']),
      validTo: dateTimeFromWire(price['valid_to']),
      now: moment,
    )) {
      continue;
    }
    matches.add(price);
  }
  if (matches.isEmpty) return null;
  matches.sort((a, b) {
    final at =
        dateTimeFromWire(a['valid_from']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final bt =
        dateTimeFromWire(b['valid_from']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return bt.compareTo(at);
  });
  return matches.first;
}

/// Overlays `challenge_sale_forms` and `challenge_prices` onto a legacy
/// `challenges` row. Empty satellite lists leave the legacy columns.
Map<String, dynamic> overlayChallengeSatellites(
  Map<String, dynamic> row, {
  required String locale,
  Iterable<Map<String, dynamic>> saleForms = const [],
  Iterable<Map<String, dynamic>> prices = const [],
  DateTime? now,
}) {
  final copy = Map<String, dynamic>.from(row);
  final id = row['id'] as String?;
  if (id == null) return copy;
  final diploma = pickSaleFormUrl(
    saleForms,
    challengeId: id,
    rewardVariant: 'diploma',
    locale: locale,
    now: now,
  );
  final medal = pickSaleFormUrl(
    saleForms,
    challengeId: id,
    rewardVariant: 'medal_and_diploma',
    locale: locale,
    now: now,
  );
  if (diploma != null) copy['fapi_form_url_diploma'] = diploma;
  if (medal != null) copy['fapi_form_url_medal'] = medal;
  final price = pickActivePrice(prices, challengeId: id, now: now);
  if (price != null) {
    copy['diploma_price_cents'] = price['diploma_price_cents'];
    copy['medal_price_cents'] = price['medal_price_cents'];
    final currency = price['currency'];
    if (currency is String && currency.trim().isNotEmpty) {
      copy['currency'] = currency;
    }
  }
  return copy;
}

/// Postgres `interval` as PostgREST text (`3 days 01:02:03` or `P3DT1H`).
Duration? durationFromWire(Object? value) {
  if (value == null) return null;
  if (value is num) return Duration(microseconds: (value * 1000000).round());
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  final iso = RegExp(
    r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
  ).firstMatch(text);
  if (iso != null && text.startsWith('P')) {
    return Duration(
      days: int.tryParse(iso.group(1) ?? '') ?? 0,
      hours: int.tryParse(iso.group(2) ?? '') ?? 0,
      minutes: int.tryParse(iso.group(3) ?? '') ?? 0,
      seconds: double.tryParse(iso.group(4) ?? '')?.round() ?? 0,
    );
  }
  var days = 0;
  var hours = 0;
  var minutes = 0;
  var seconds = 0;
  var matched = false;
  final dayMatch = RegExp(r'(\d+)\s+days?').firstMatch(text);
  if (dayMatch != null) {
    days = int.parse(dayMatch.group(1)!);
    matched = true;
  }
  final timeMatch = RegExp(r'(\d+):(\d+):(\d+(?:\.\d+)?)').firstMatch(text);
  if (timeMatch != null) {
    hours = int.parse(timeMatch.group(1)!);
    minutes = int.parse(timeMatch.group(2)!);
    seconds = double.parse(timeMatch.group(3)!).round();
    matched = true;
  }
  if (!matched) return null;
  return Duration(days: days, hours: hours, minutes: minutes, seconds: seconds);
}

ChallengeProgress progressFromRunRow(
  String challengeId,
  Map<String, dynamic>? run, {
  Set<String> completedWaypointIds = const {},
}) {
  return ChallengeProgress(
    challengeId: challengeId,
    status: runStatusFromWire(run?['status'] as String? ?? 'in_progress'),
    completedWaypointIds: completedWaypointIds,
    startedAt: dateTimeFromWire(run?['started_at']),
    completedAt: dateTimeFromWire(run?['completed_at']),
    duration: durationFromWire(run?['duration']),
  );
}

IssuedDiploma issuedDiplomaFromRow(
  String challengeId,
  Map<String, dynamic> row,
) {
  return IssuedDiploma(
    challengeId: challengeId,
    headline: _nonEmpty(row['headline']),
    body: row['body'] as String?,
    recipientName: _nonEmpty(row['recipient_name']),
    recipientNameDisplay: _nonEmpty(row['recipient_name_display']),
    challengeTitle: _nonEmpty(row['challenge_title']),
    completedAt: dateTimeFromWire(row['completed_at']),
    duration: durationFromWire(row['duration']),
    lang: row['lang'] as String?,
    periodDays: (row['period_days'] as num?)?.toInt(),
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
