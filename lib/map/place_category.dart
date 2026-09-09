enum PlaceCategory {
  castle,
  chateau,
  ruin,
  church,
  other;

  String get l10nKey => switch (this) {
    PlaceCategory.castle => 'catCastle',
    PlaceCategory.chateau => 'catChateau',
    PlaceCategory.ruin => 'catRuin',
    PlaceCategory.church => 'catChurch',
    PlaceCategory.other => 'catOther',
  };

  String get iconName => name;

  static PlaceCategory fromWire(String value) {
    return PlaceCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => PlaceCategory.other,
    );
  }
}
