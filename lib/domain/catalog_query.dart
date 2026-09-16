import '../models/models.dart';

/// ISO country codes shown as catalog region chips.
const catalogCountryCodes = ['CZ', 'SK', 'AT', 'DE', 'PL'];

/// Catalog search + chip selection. Empty groups mean "all".
class CatalogFilter {
  const CatalogFilter({
    this.query = '',
    this.pricingTypes = const {},
    this.accessModes = const {},
    this.countryCodes = const {},
  });

  final String query;
  final Set<PricingType> pricingTypes;
  final Set<AccessMode> accessModes;
  final Set<String> countryCodes;

  bool get hasActiveChips =>
      pricingTypes.isNotEmpty ||
      accessModes.isNotEmpty ||
      countryCodes.isNotEmpty;

  bool get isActive => query.trim().isNotEmpty || hasActiveChips;

  /// Promos stay above the list unless the user is typing a search.
  bool get showPromos => query.trim().isEmpty;

  CatalogFilter copyWith({
    String? query,
    Set<PricingType>? pricingTypes,
    Set<AccessMode>? accessModes,
    Set<String>? countryCodes,
  }) {
    return CatalogFilter(
      query: query ?? this.query,
      pricingTypes: pricingTypes ?? this.pricingTypes,
      accessModes: accessModes ?? this.accessModes,
      countryCodes: countryCodes ?? this.countryCodes,
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

/// Price OR, mode OR, region OR; groups AND search AND chips.
///
/// Search matches any locale's title + description on the challenge.
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
