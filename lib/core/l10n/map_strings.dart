/// Czech production copy for the Map Screen MVP, plus en/de for the
/// existing locale switcher. Production SPEC copy is Czech.
class MapStrings {
  MapStrings(this.locale) : _table = _tables[locale] ?? _tables['cs']!;

  final String locale;
  final Map<String, String> _table;

  String t(String key) => _table[key] ?? _tables['cs']![key] ?? key;

  String get searchHint => t('searchHint');
  String get filtersTitle => t('filtersTitle');
  String get viewList => t('viewList');
  String get viewMap => t('viewMap');
  String get detailCta => t('detailCta');
  String get closeCta => t('closeCta');
  String get detailPlaceholder => t('detailPlaceholder');
  String get locateDenied => t('locateDenied');
  String get locateDisabled => t('locateDisabled');
  String get mapLoadError => t('mapLoadError');
  String get catalogLoadError => t('catalogLoadError');
  String get retry => t('retry');
  String get osmAttribution => t('osmAttribution');
  String get osmAttributionLong => t('osmAttributionLong');
  String get comingSoon => t('comingSoon');
  String get navHome => t('navHome');
  String get navMap => t('navMap');
  String get navList => t('navList');
  String get navPlanner => t('navPlanner');
  String get navSaved => t('navSaved');
  String get navProfile => t('navProfile');
  String get applyFilters => t('applyFilters');
  String get selectAll => t('selectAll');
  String get locateTooltip => t('locateTooltip');
  String get lastChallenge => t('lastChallenge');
  String get challengesMap => t('challengesMap');

  String categoryLabel(String l10nKey) => t(l10nKey);

  String poiCount(int n) => '$n ${pamatkaPlural(n)}';

  /// Czech pluralization: 1 památka, 2–4 památky, 0/5+ památek.
  /// 21+ uses genitive plural (21 památek), matching common Czech UI counts.
  static String pamatkaPlural(int n, {String locale = 'cs'}) {
    if (locale != 'cs') {
      if (n == 1) return locale == 'de' ? 'Denkmal' : 'monument';
      return locale == 'de' ? 'Denkmäler' : 'monuments';
    }
    if (n == 1) return 'památka';
    if (n >= 2 && n <= 4) return 'památky';
    return 'památek';
  }

  String distanceKm(double km) {
    if (km < 10) {
      final formatted = km.toStringAsFixed(1).replaceAll('.', ',');
      return t('distanceKm').replaceFirst('{n}', formatted);
    }
    return t('distanceKm').replaceFirst('{n}', km.round().toString());
  }

  static const _tables = <String, Map<String, String>>{
    'cs': {
      'searchHint': 'Hledat hrad, zámek…',
      'filtersTitle': 'Filtry',
      'catCastle': 'Hrady',
      'catChateau': 'Zámky',
      'catRuin': 'Zříceniny',
      'catChurch': 'Kostely',
      'catOther': 'Ostatní',
      'viewList': 'V seznamu',
      'viewMap': 'Na mapě',
      'detailCta': 'Detail',
      'closeCta': 'Zavřít',
      'detailPlaceholder': 'Detail památky připravujeme.',
      'locateDenied':
          'Polohu nelze použít. Povolte přístup k poloze v nastavení.',
      'locateDisabled':
          'Polohové služby jsou vypnuté. Zapněte je v nastavení zařízení.',
      'mapLoadError': 'Mapu se nepodařilo načíst.',
      'catalogLoadError': 'Památky se nepodařilo načíst.',
      'retry': 'Zkusit znovu',
      'osmAttribution': '© OpenStreetMap',
      'osmAttributionLong': '© přispěvatelé OpenStreetMap',
      'comingSoon': 'Připravujeme',
      'navHome': 'Domů',
      'navMap': 'Mapa',
      'navList': 'Katalog',
      'navPlanner': 'Plánovač',
      'navSaved': 'Uloženo',
      'navProfile': 'Profil',
      'applyFilters': 'Použít',
      'selectAll': 'Vybrat vše',
      'locateTooltip': 'Moje poloha',
      'lastChallenge': 'Poslední výzva',
      'challengesMap': 'Mapa výzev',
      'distanceKm': '{n} km',
    },
    'en': {
      'searchHint': 'Search castle, chateau…',
      'filtersTitle': 'Filters',
      'catCastle': 'Castles',
      'catChateau': 'Chateaus',
      'catRuin': 'Ruins',
      'catChurch': 'Churches',
      'catOther': 'Other',
      'viewList': 'In list',
      'viewMap': 'On map',
      'detailCta': 'Details',
      'closeCta': 'Close',
      'detailPlaceholder': 'Place details are coming soon.',
      'locateDenied':
          'Location is unavailable. Allow location access in Settings.',
      'locateDisabled':
          'Location services are off. Turn them on in device settings.',
      'mapLoadError': 'The map could not be loaded.',
      'catalogLoadError': 'Monuments could not be loaded.',
      'retry': 'Retry',
      'osmAttribution': '© OpenStreetMap',
      'osmAttributionLong': '© OpenStreetMap contributors',
      'comingSoon': 'Coming soon',
      'navHome': 'Home',
      'navMap': 'Map',
      'navList': 'Catalog',
      'navPlanner': 'Planner',
      'navSaved': 'Saved',
      'navProfile': 'Profile',
      'applyFilters': 'Apply',
      'selectAll': 'Select all',
      'locateTooltip': 'My location',
      'lastChallenge': 'Last challenge',
      'challengesMap': 'Challenges map',
      'distanceKm': '{n} km',
    },
    'de': {
      'searchHint': 'Burg, Schloss suchen…',
      'filtersTitle': 'Filter',
      'catCastle': 'Burgen',
      'catChateau': 'Schlösser',
      'catRuin': 'Ruinen',
      'catChurch': 'Kirchen',
      'catOther': 'Sonstiges',
      'viewList': 'Als Liste',
      'viewMap': 'Auf Karte',
      'detailCta': 'Details',
      'closeCta': 'Schließen',
      'detailPlaceholder': 'Objektdetails folgen.',
      'locateDenied':
          'Standort nicht nutzbar. Erlauben Sie den Zugriff in den Einstellungen.',
      'locateDisabled':
          'Ortungsdienste sind aus. Schalten Sie sie in den Geräteeinstellungen ein.',
      'mapLoadError': 'Die Karte konnte nicht geladen werden.',
      'catalogLoadError': 'Denkmäler konnten nicht geladen werden.',
      'retry': 'Erneut versuchen',
      'osmAttribution': '© OpenStreetMap',
      'osmAttributionLong': '© OpenStreetMap-Mitwirkende',
      'comingSoon': 'In Vorbereitung',
      'navHome': 'Start',
      'navMap': 'Karte',
      'navList': 'Katalog',
      'navPlanner': 'Planer',
      'navSaved': 'Gespeichert',
      'navProfile': 'Profil',
      'applyFilters': 'Übernehmen',
      'selectAll': 'Alle wählen',
      'locateTooltip': 'Mein Standort',
      'lastChallenge': 'Letzte Challenge',
      'challengesMap': 'Challenge-Karte',
      'distanceKm': '{n} km',
    },
  };
}
