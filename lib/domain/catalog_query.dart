import 'package:intl/intl.dart';

import '../models/models.dart';
import 'route_planner.dart';

/// Length bands for catalog card labels.
///
/// Bounds use actual hike hours from [CatalogRouteStats.estimatedDuration]:
/// short < 3 h, medium 3–6 h, long ≥ 6 h. Never invent hours for the UI.
enum CatalogLengthBand { short, medium, long }

/// Haversine + hike-time summary derived from loaded waypoints.
///
/// There is no CMS duration/distance column. Stats come from ordered
/// waypoint coordinates via [RoutePlanner] (hike / Naismith). When the
/// row includes a joined place, those coordinates are the place's.
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
    this.accessModes = const {},
    this.regions = const {},
    this.difficulties = const {},
  });

  final String query;
  final Set<AccessMode> accessModes;

  /// Exact `challenges.region` values. Empty means every region, including null.
  final Set<String> regions;
  final Set<CatalogDifficulty> difficulties;

  bool get hasActiveChips =>
      accessModes.isNotEmpty || regions.isNotEmpty || difficulties.isNotEmpty;

  bool get isActive => query.trim().isNotEmpty || hasActiveChips;

  /// Promos stay above the list unless the user is typing a search.
  bool get showPromos => query.trim().isEmpty;

  CatalogFilter copyWith({
    String? query,
    Set<AccessMode>? accessModes,
    Set<String>? regions,
    Set<CatalogDifficulty>? difficulties,
  }) {
    return CatalogFilter(
      query: query ?? this.query,
      accessModes: accessModes ?? this.accessModes,
      regions: regions ?? this.regions,
      difficulties: difficulties ?? this.difficulties,
    );
  }

  CatalogFilter cleared() => const CatalogFilter();
}

/// Distinct non-blank [Challenge.region] values from challenges already loaded.
///
/// Published, non-promo rows only. Null and blank regions are omitted — those
/// challenges stay visible only when no region chip is selected. Order is a
/// diacritic-primary dictionary sort for the UI [locale] (cs, en, de).
List<String> catalogRegionOptions(
  Iterable<Challenge> challenges, {
  required String locale,
}) {
  final seen = <String>{};
  for (final challenge in challenges) {
    if (challenge.isPromo || !isPubliclyVisible(challenge.status)) continue;
    final region = challenge.region;
    if (region == null || region.trim().isEmpty) continue;
    seen.add(region);
  }
  final options = seen.toList();
  options.sort((a, b) => compareCatalogRegions(a, b, locale));
  return options;
}

/// Dictionary order for region chips in the active UI [locale].
///
/// cs / en / de (and other UI locales) use a diacritic-primary key
/// (č with c, ř with r) so "České středohoří" sorts with C rather than after Z.
int compareCatalogRegions(String a, String b, String locale) {
  final language = Intl.canonicalizedLocale(locale).split('_').first;
  if (language == 'cs' || language == 'en' || language == 'de') {
    final folded = foldCatalogText(a).compareTo(foldCatalogText(b));
    if (folded != 0) return folded;
  }
  return a.compareTo(b);
}

/// Case- and diacritic-insensitive haystack for catalog search.
String foldCatalogText(String input) {
  final buf = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    buf.write(_foldChar(rune));
  }
  return buf.toString();
}

/// Mode OR, region OR, difficulty OR; groups AND search AND chips.
///
/// Search matches any locale's title + description on the challenge.
/// Region chips match [Challenge.region] exactly. A null or blank region
/// stays in the list only when no region chip is selected.
/// A null CMS difficulty does not exclude a challenge when a difficulty
/// chip is active — only challenges that have a value are filtered.
List<Challenge> filterCatalogChallenges(
  Iterable<Challenge> challenges,
  CatalogFilter filter,
) {
  final foldedQuery = foldCatalogText(filter.query.trim());
  return [
    for (final challenge in challenges)
      if (_matchesChallenge(challenge, filter, foldedQuery)) challenge,
  ];
}

bool _matchesChallenge(
  Challenge challenge,
  CatalogFilter filter,
  String foldedQuery,
) {
  if (challenge.isPromo) return false;
  if (filter.accessModes.isNotEmpty &&
      !filter.accessModes.contains(challenge.accessMode)) {
    return false;
  }
  if (filter.regions.isNotEmpty) {
    final region = challenge.region;
    if (region == null ||
        region.trim().isEmpty ||
        !filter.regions.contains(region)) {
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
