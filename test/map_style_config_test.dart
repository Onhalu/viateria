import 'dart:io';

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

  test('Batch B marker sizes without clustering', () {
    expect(MapStyleConfig.markerIconSize, 0.45);
    expect(MapStyleConfig.selectedMarkerIconSize, 0.55);
    expect(MapStyleConfig.selectedUnderlayRadius, 15);
    expect(MapStyleConfig.selectedUnderlayColor, 'rgba(53, 72, 60, 0.22)');
    expect(MapStyleConfig.sageUnderlayColor, 'rgba(156, 154, 123, 0.22)');
    expect(MapStyleConfig.forestHex, '#35483C');
    expect(MapStyleConfig.sageHex, '#9C9A7B');
    expect(MapStyleConfig.barkHex, '#756653');
    expect(MapStyleConfig.creamHex, '#F3EFE5');
    expect(MapStyleConfig.verifiedHex, '#B8860B');
    expect(MapStyleConfig.verifiedUnderlayColor, 'rgba(184, 134, 11, 0.22)');
    expect(MapStyleConfig.markerColorExpression.first, 'case');
    expect(
      MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.verifiedHex),
      lessThan(
        MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.forestHex),
      ),
    );
  });

  test(
    'challenge overlay is hike/bike lines; numbered waypoint layers are gone',
    () {
      expect(MapStyleConfig.hikeLayerId, 'challenge-hike-line');
      expect(MapStyleConfig.bikeLayerId, 'challenge-bike-line');
      expect(MapStyleConfig.poiSourceId, 'pois');
      expect(MapStyleConfig.symbolLayerId, 'poi-symbols');
      const config = 'lib/map/map_style_config.dart';
      const host = 'lib/ui/widgets/places_map_host.dart';
      expect(
        File(config).readAsStringSync().contains('pointsSourceId'),
        isFalse,
      );
      expect(
        File(config).readAsStringSync().contains('circleLayerId'),
        isFalse,
      );
      expect(File(config).readAsStringSync().contains('labelLayerId'), isFalse);
      expect(File(host).readAsStringSync().contains('circleLayerId'), isFalse);
      expect(File(host).readAsStringSync().contains('labelLayerId'), isFalse);
      expect(File(host).readAsStringSync().contains('pointsSourceId'), isFalse);
    },
  );
}
