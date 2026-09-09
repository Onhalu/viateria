import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/map/map_style_config.dart';

void main() {
  test(
    'empty MAP_STYLE_URL uses the documented non-prod OpenFreeMap style',
    () {
      expect(MapStyleConfig.styleUrlFromEnv, isEmpty);
      expect(MapStyleConfig.usingFallbackStyle, isTrue);
      expect(MapStyleConfig.styleUrl, MapStyleConfig.nonProdFallbackStyleUrl);
      expect(
        MapStyleConfig.nonProdFallbackStyleUrl,
        'https://tiles.openfreemap.org/styles/liberty',
      );
      expect(
        MapStyleConfig.styleUrl.contains('tile.openstreetmap.org'),
        isFalse,
      );
    },
  );

  test('Batch A cluster and marker sizes', () {
    expect(MapStyleConfig.clusterRadius, 40);
    expect(MapStyleConfig.clusterMaxZoom, 13);
    expect(MapStyleConfig.markerIconSize, 0.75);
    expect(MapStyleConfig.selectedMarkerIconSize, 0.9);
    expect(MapStyleConfig.selectedUnderlayRadius, 22);
    expect(MapStyleConfig.clusterCountTextSize, inInclusiveRange(11, 12));
    expect(MapStyleConfig.clusterCountTextColor, '#35483C');
    expect(MapStyleConfig.selectedUnderlayColor, 'rgba(53, 72, 60, 0.22)');
    expect(MapStyleConfig.forestHex, '#35483C');
    expect(MapStyleConfig.barkHex, '#756653');
    expect(MapStyleConfig.creamHex, '#F3EFE5');
  });
}
