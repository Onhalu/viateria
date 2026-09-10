import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/map/map_style_config.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/widgets/map_chrome.dart';

import 'helpers/map_harness.dart';

void main() {
  test('map palette replaces gold/moss/old forest/old bark on map UI', () {
    expect(MapPalette.forest, const Color(0xFF35483C));
    expect(MapPalette.sage, const Color(0xFF9C9A7B));
    expect(MapPalette.cream, const Color(0xFFF3EFE5));
    expect(MapPalette.neutral, const Color(0xFFFAF8F2));
    expect(MapPalette.beige, const Color(0xFFD8CDB8));
    expect(MapPalette.bark, const Color(0xFF756653));
    expect(MapPalette.creamFill.toARGB32(), 0xF0F3EFE5);
    expect(MapOverlayColors.fill, MapPalette.creamFill);
    expect(MapOverlayColors.accent, MapPalette.forest);
    expect(MapOverlayColors.surface, MapPalette.cream);

    expect(MapOverlayColors.accent, isNot(AppTheme.gold));
    expect(MapOverlayColors.accent, isNot(MapPalette.sage));
    expect(MapPalette.forest, isNot(AppTheme.forest));
    expect(MapPalette.bark, isNot(AppTheme.bark));
    expect(MapPalette.forest, isNot(const Color(0xFF1B4332)));
    expect(MapPalette.bark, isNot(const Color(0xFF3D2914)));
    expect(MapOverlayColors.fill, isNot(const Color(0xE61A1A1A)));
    expect(MapPalette.forestHex, '#35483C');
    expect(MapPalette.sageHex, '#9C9A7B');
    expect(MapPalette.forestRgba22, MapStyleConfig.selectedUnderlayColor);
    expect(MapPalette.sageRgba22, MapStyleConfig.sageUnderlayColor);
    expect(MapStyleConfig.forestHex, '#35483C');
    expect(MapStyleConfig.sageHex, '#9C9A7B');
    expect(MapStyleConfig.barkHex, '#756653');
  });

  test('full and compact chrome sizes', () {
    expect(MapChromeSizes.searchRadius, 24);
    expect(MapChromeSizes.toggleRadius, 20);
    expect(MapChromeSizes.attributionIcon, 16);
    expect(MapChromeSizes.listRowIcon, 22);

    expect(MapChromeSizes.inset(false), 12);
    expect(MapChromeSizes.inset(true), 8);
    expect(MapChromeSizes.searchHeight(false), 48);
    expect(MapChromeSizes.searchHeight(true), 40);
    expect(MapChromeSizes.searchFont(false), 15);
    expect(MapChromeSizes.searchFont(true), 13);
    expect(MapChromeSizes.searchIcon(false), 18);
    expect(MapChromeSizes.searchIcon(true), 16);
    expect(MapChromeSizes.circleButton(false), 44);
    expect(MapChromeSizes.circleButton(true), 36);
    expect(MapChromeSizes.circleIcon(false), 18);
    expect(MapChromeSizes.circleIcon(true), 16);
    expect(MapChromeSizes.countFont(false), 13);
    expect(MapChromeSizes.countFont(true), 11);
    expect(MapChromeSizes.toggleFont(false), 13);
    expect(MapChromeSizes.toggleFont(true), 12);
    expect(MapChromeSizes.toggleIcon(false), 16);
    expect(MapChromeSizes.toggleIcon(true), 14);
  });

  test('Czech category labels are Batch B names', () {
    final cs = AppStrings('cs');
    expect(cs.t('catCity'), 'Město');
    expect(cs.t('catNature'), 'Přírodní památka');
    expect(cs.t('catTechnical'), 'Technická památka');
    expect(cs.t('catHistorical'), 'Historická památka');
    expect(cs.verify, 'Ověřit zastávku');
    expect(cs.verifyInChallengeHint, 'Ověření je ve výzvě.');
  });

  test('GeoJSON marks selected and in-challenge places', () {
    final places = samplePlaces();
    final collection = featureCollectionOf(
      places,
      selectedId: 'karlstejn',
      challengePlaceIds: const {'karlstejn'},
    );
    final features = collection['features'] as List;
    final selected = features.cast<Map<String, dynamic>>().firstWhere(
      (feature) => feature['id'] == 'karlstejn',
    );
    expect((selected['properties'] as Map)['selected'], 1);
    expect((selected['properties'] as Map)['inChallenge'], 1);
    final other = features.cast<Map<String, dynamic>>().firstWhere(
      (feature) => feature['id'] == 'staromestske',
    );
    expect((other['properties'] as Map)['selected'], 0);
    expect((other['properties'] as Map)['inChallenge'], 0);
  });

  test('Mapa tab default is sage: no challenge ids means inChallenge 0', () {
    final collection = featureCollectionOf(samplePlaces());
    for (final raw in collection['features'] as List) {
      expect((raw as Map)['properties']['inChallenge'], 0);
    }
  });
}
