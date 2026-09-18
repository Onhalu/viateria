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

  String get iconName => name;

  /// Short profile-stat labels (město / příroda / …), not the map filter names.
  String get profileL10nKey => switch (this) {
    PlaceCategory.city => 'profileCatCity',
    PlaceCategory.nature => 'profileCatNature',
    PlaceCategory.technical => 'profileCatTechnical',
    PlaceCategory.historical => 'profileCatHistorical',
  };

  static PlaceCategory fromWire(String value) {
    return switch (value) {
      'city' => PlaceCategory.city,
      'nature' => PlaceCategory.nature,
      'technical' => PlaceCategory.technical,
      'historical' => PlaceCategory.historical,
      // Pre-Batch-B keys all collapse to historical.
      'castle' ||
      'chateau' ||
      'ruin' ||
      'church' ||
      'other' => PlaceCategory.historical,
      _ => PlaceCategory.historical,
    };
  }
}
