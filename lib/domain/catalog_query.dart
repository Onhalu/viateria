import '../models/models.dart';
import 'route_planner.dart';

/// ISO country codes shown as catalog region chips.
const catalogCountryCodes = ['CZ', 'SK', 'AT', 'DE', 'PL'];

/// Length bands for catalog chips and card labels.
///
/// Bounds use actual hike hours from [CatalogRouteStats.estimatedDuration]:
/// short < 3 h, medium 3–6 h, long ≥ 6 h. Never invent hours for the UI.
enum CatalogLengthBand { short, medium, long }

/// Haversine + hike-time summary derived from stored waypoints.
///
/// There is no CMS duration/distance column. Stats come from ordered
/// `waypoints.lat/lng/elevation_m` via [RoutePlanner] (hike / Naismith).
/// Null when a challenge has fewer than two waypoints or time rounds to
/// nothing — callers must hide the length label.
class CatalogRouteStats {
  const CatalogRouteStats({this.distanceKm, this.estimatedDuration});

  final double? distanceKm;
  final Duration? estimatedDuration;

  CatalogLengthBand? get lengthBand {
    final duration = estimatedDuration;
    if (duration == null) return null;
    return catalogLengthBandFor(duration);
  }
}

CatalogLengthBand catalogLengthBandFor(Duration duration) {
  final hours = duration.inMinutes / 60.0;
  if (hours < 3) return CatalogLengthBand.short;
  if (hours < 6) return CatalogLengthBand.medium;
  return CatalogLengthBand.long;
}

/// Route length and hike time from stored waypoint coordinates.
///
/// Source: catalog `waypoints` already loaded with each published challenge
/// (not a new duration column). Uses [RoutePlanner.plan] in hike mode.
CatalogRouteStats? catalogRouteStatsFromWaypoints(List<Waypoint> waypoints) {
  if (waypoints.length < 2) return null;
  final summary = const RoutePlanner().plan(
    mode: TravelMode.hike,
    waypoints: waypoints,
  );
  final distance = summary.distanceKm >= 0.05 ? summary.distanceKm : null;
  final duration = summary.estimatedTime.inMinutes > 0
      ? summary.estimatedTime
      : null;
  if (distance == null && duration == null) return null;
  return CatalogRouteStats(distanceKm: distance, estimatedDuration: duration);
}

Map<String, CatalogRouteStats> catalogRouteStatsByChallenge(
  Iterable<ChallengeDetail> details,
) {
  final out = <String, CatalogRouteStats>{};
  for (final detail in details) {
    final stats = catalogRouteStatsFromWaypoints(detail.orderedWaypoints);
    if (stats != null) out[detail.challenge.id] = stats;
  }
  return out;
}

/// Catalog search + chip selection. Empty groups mean "all".
class CatalogFilter {
  const CatalogFilter({
    this.query = '',
    this.pricingTypes = const {},
    this.accessModes = const {},
    this.countryCodes = const {},
    this.lengthBands = const {},
    this.difficulties = const {},
  });

  final String query;
  final Set<PricingType> pricingTypes;
  final Set<AccessMode> accessModes;
  final Set<String> countryCodes;
  final Set<CatalogLengthBand> lengthBands;
  final Set<CatalogDifficulty> difficulties;

  bool get hasActiveChips =>
      pricingTypes.isNotEmpty ||
      accessModes.isNotEmpty ||
      countryCodes.isNotEmpty ||
      lengthBands.isNotEmpty ||
      difficulties.isNotEmpty;

  bool get isActive => query.trim().isNotEmpty || hasActiveChips;

  /// Promos stay above the list unless the user is typing a search.
  bool get showPromos => query.trim().isEmpty;

  CatalogFilter copyWith({
    String? query,
    Set<PricingType>? pricingTypes,
    Set<AccessMode>? accessModes,
    Set<String>? countryCodes,
    Set<CatalogLengthBand>? lengthBands,
    Set<CatalogDifficulty>? difficulties,
  }) {
    return CatalogFilter(
      query: query ?? this.query,
      pricingTypes: pricingTypes ?? this.pricingTypes,
      accessModes: accessModes ?? this.accessModes,
      countryCodes: countryCodes ?? this.countryCodes,
      lengthBands: lengthBands ?? this.lengthBands,
      difficulties: difficulties ?? this.difficulties,
    );
  }

  CatalogFilter cleared() => const CatalogFilter();
}

/// Keep ISO codes the chips understand; anything else is treated as unknown.
String? parseCountryCode(String? raw) {
  if (raw == null) return null;
  final code = raw.trim().toUpperCase();
  if (code.isEmpty) return null;
  return catalogCountryCodes.contains(code) ? code : null;
}

/// Best-effort map from the free-text [region] display string.
/// Used as a client fallback when `country_code` is still null.
String? inferCountryCodeFromRegion(String? region) {
  if (region == null || region.trim().isEmpty) return null;
  final folded = foldCatalogText(region);
  if (_matchesAny(folded, const [
    'cesko',
    'morava',
    'palava',
    'beskydy',
    'vysocina',
    'orlicke',
    'stredohori',
    'bohemia',
    'czechia',
    'prague',
    'praha',
  ])) {
    return 'CZ';
  }
  if (_matchesAny(folded, const ['slovensko', 'slovakia', 'tatry', 'liptov'])) {
    return 'SK';
  }
  if (_matchesAny(folded, const ['rakousko', 'osterreich', 'austria'])) {
    return 'AT';
  }
  if (_matchesAny(folded, const [
    'nemecko',
    'deutschland',
    'germany',
    'bavorsko',
  ])) {
    return 'DE';
  }
  if (_matchesAny(folded, const ['polsko', 'poland', 'polen'])) {
    return 'PL';
  }
  return null;
}

String? resolveCountryCode({String? countryCode, String? region}) {
  return parseCountryCode(countryCode) ?? inferCountryCodeFromRegion(region);
}

/// Case- and diacritic-insensitive haystack for catalog search.
String foldCatalogText(String input) {
  final buf = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    buf.write(_foldChar(rune));
  }
  return buf.toString();
}

/// Price OR, mode OR, region OR, length OR, difficulty OR; groups AND
/// search AND chips.
///
/// Search matches any locale's title + description on the challenge.
/// Length chips use [routeStats] derived from waypoints; a challenge
/// without a length band never matches a selected length chip.
/// A null CMS difficulty does not exclude a challenge when a difficulty
/// chip is active — only challenges that have a value are filtered.
List<Challenge> filterCatalogChallenges(
  Iterable<Challenge> challenges,
  CatalogFilter filter, {
  Map<String, CatalogRouteStats> routeStats = const {},
}) {
  final foldedQuery = foldCatalogText(filter.query.trim());
  return [
    for (final challenge in challenges)
      if (_matchesChallenge(challenge, filter, foldedQuery, routeStats))
        challenge,
  ];
}

bool _matchesChallenge(
  Challenge challenge,
  CatalogFilter filter,
  String foldedQuery,
  Map<String, CatalogRouteStats> routeStats,
) {
  if (filter.pricingTypes.isNotEmpty &&
      !filter.pricingTypes.contains(challenge.pricingType)) {
    return false;
  }
  if (filter.accessModes.isNotEmpty &&
      !filter.accessModes.contains(challenge.accessMode)) {
    return false;
  }
  if (filter.countryCodes.isNotEmpty) {
    final code = challenge.countryCode;
    if (code == null || !filter.countryCodes.contains(code)) {
      return false;
    }
  }
  if (filter.lengthBands.isNotEmpty) {
    final band = routeStats[challenge.id]?.lengthBand;
    if (band == null || !filter.lengthBands.contains(band)) {
      return false;
    }
  }
  if (filter.difficulties.isNotEmpty) {
    final difficulty = challenge.difficulty;
    if (difficulty != null && !filter.difficulties.contains(difficulty)) {
      return false;
    }
  }
  if (foldedQuery.isEmpty) return true;
  return foldCatalogText(_searchHaystack(challenge)).contains(foldedQuery);
}

String _searchHaystack(Challenge challenge) {
  final buf = StringBuffer();
  for (final text in challenge.translations) {
    buf
      ..write(text.title)
      ..write(' ')
      ..write(text.description)
      ..write(' ');
  }
  return buf.toString();
}

bool _matchesAny(String folded, List<String> needles) {
  for (final needle in needles) {
    if (folded.contains(needle)) return true;
  }
  return false;
}

String _foldChar(int rune) {
  switch (rune) {
    case 0xE1: // á
    case 0xE0: // à
    case 0xE2: // â
    case 0xE4: // ä
    case 0xE3: // ã
    case 0xE5: // å
    case 0x101: // ā
      return 'a';
    case 0xE7: // ç
    case 0x10D: // č
      return 'c';
    case 0x10F: // ď
      return 'd';
    case 0xE9: // é
    case 0xE8: // è
    case 0xEA: // ê
    case 0xEB: // ë
    case 0x11B: // ě
      return 'e';
    case 0xED: // í
    case 0xEC: // ì
    case 0xEE: // î
    case 0xEF: // ï
      return 'i';
    case 0x13E: // ľ
    case 0x13A: // ĺ
      return 'l';
    case 0x148: // ň
    case 0xF1: // ñ
      return 'n';
    case 0xF3: // ó
    case 0xF2: // ò
    case 0xF4: // ô
    case 0xF6: // ö
    case 0xF5: // õ
      return 'o';
    case 0x155: // ŕ
    case 0x159: // ř
      return 'r';
    case 0x161: // š
    case 0x15B: // ś
      return 's';
    case 0x165: // ť
      return 't';
    case 0xFA: // ú
    case 0xF9: // ù
    case 0xFB: // û
    case 0xFC: // ü
    case 0x16F: // ů
      return 'u';
    case 0xFD: // ý
    case 0xFF: // ÿ
      return 'y';
    case 0x17E: // ž
    case 0x17A: // ź
      return 'z';
    case 0xDF: // ß
      return 'ss';
    case 0xE6: // æ
      return 'ae';
    case 0x153: // œ
      return 'oe';
    default:
      return String.fromCharCode(rune);
  }
}
