enum PlaceCategory {
  city,
  nature,
  technical,
  historical;

  String get l10nKey => switch (this) {
    PlaceCategory.city => 'catCity',
    PlaceCategory.nature => 'catNature',
    PlaceCategory.technical => 'catTechnical',
    PlaceCategory.historical => 'catHistorical',
  };

  /// Asset name under `assets/map/icons/`. One-to-one with the enum value,
  /// which is the `places.category` wire string (`city`, `nature`,
  /// `technical`, `historical`).
  String get iconName => name;

  /// Short profile-stat labels (město / příroda / …), not the map filter names.
  String get profileL10nKey => switch (this) {
    PlaceCategory.city => 'profileCatCity',
    PlaceCategory.nature => 'profileCatNature',
    PlaceCategory.technical => 'profileCatTechnical',
    PlaceCategory.historical => 'profileCatHistorical',
  };

  /// Maps a `places.category` string onto an icon.
  ///
  /// The four production values map 1:1. Anything else — missing, blank, or
  /// a pre-batch key (`castle`, `chateau`, `ruin`, `church`, `other`) — uses
  /// the single fallback [PlaceCategory.historical] (`historical` icon).
  /// Callers must not consult `place_type`, region, or the place name.
  static PlaceCategory fromWire(String value) {
    return switch (value) {
      'city' => PlaceCategory.city,
      'nature' => PlaceCategory.nature,
      'technical' => PlaceCategory.technical,
      'historical' => PlaceCategory.historical,
      'castle' ||
      'chateau' ||
      'ruin' ||
      'church' ||
      'other' => PlaceCategory.historical,
      _ => PlaceCategory.historical,
    };
  }
}
