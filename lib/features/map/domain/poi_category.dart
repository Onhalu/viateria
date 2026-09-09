enum PoiCategory {
  castle,
  chateau,
  ruin,
  church,
  other;

  String get l10nKey => switch (this) {
    PoiCategory.castle => 'catCastle',
    PoiCategory.chateau => 'catChateau',
    PoiCategory.ruin => 'catRuin',
    PoiCategory.church => 'catChurch',
    PoiCategory.other => 'catOther',
  };

  String get iconName => name;

  static PoiCategory fromWire(String value) {
    return PoiCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => PoiCategory.other,
    );
  }
}
