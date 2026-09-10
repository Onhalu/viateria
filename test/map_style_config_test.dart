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
    expect(MapStyleConfig.diskDiameter, 28);
    expect(MapStyleConfig.selectedDiskDiameter, 32);
    expect(MapStyleConfig.diskRadius, 14);
    expect(MapStyleConfig.selectedDiskRadius, 16);
    expect(MapStyleConfig.diskStrokeWidth, 1.5);
    expect(MapStyleConfig.diskFillColor, 'rgba(243, 239, 229, 0.94)');
    expect(MapStyleConfig.diskLayerId, 'poi-disks');
    expect(MapStyleConfig.forestHex, '#35483C');
    expect(MapStyleConfig.sageHex, '#9C9A7B');
    expect(MapStyleConfig.barkHex, '#756653');
    expect(MapStyleConfig.creamHex, '#F3EFE5');
    expect(MapStyleConfig.verifiedHex, MapStyleConfig.barkHex);
    expect(MapStyleConfig.verifiedHex, '#756653');
    expect(MapStyleConfig.markerColorExpression.first, 'match');
    expect(
      MapStyleConfig.markerColorExpression,
      contains(MapStyleConfig.placeStateVerified),
    );
    expect(
      MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.barkHex),
      lessThan(
        MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.forestHex),
      ),
    );
    expect(
      MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.forestHex),
      lessThan(
        MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.sageHex),
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
      expect(File(host).readAsStringSync().contains('diskLayerId'), isTrue);
      expect(
        File(host).readAsStringSync().contains('selectedUnderlayLayerId'),
        isFalse,
      );
      expect(File(config).readAsStringSync().contains('#B8860B'), isFalse);
    },
  );
}
