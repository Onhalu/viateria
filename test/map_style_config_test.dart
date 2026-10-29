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
    expect(MapStyleConfig.markerIconSize, 0.36);
    expect(MapStyleConfig.selectedMarkerIconSize, 0.41);
    // City content 56 px × 0.36 ≈ 20 dp inside the 32 dp disk.
    expect(56 * MapStyleConfig.markerIconSize, closeTo(20, 0.5));
    expect(
      MapStyleConfig.selectedMarkerIconSize,
      closeTo(
        MapStyleConfig.markerIconSize *
            MapStyleConfig.selectedDiskDiameter /
            MapStyleConfig.diskDiameter,
        0.01,
      ),
    );
    expect(MapStyleConfig.diskDiameter, 32);
    expect(MapStyleConfig.selectedDiskDiameter, 36.8);
    expect(MapStyleConfig.diskRadius, 16);
    expect(MapStyleConfig.selectedDiskRadius, 18.4);
    expect(MapStyleConfig.diskStrokeWidth, 1.5);
    expect(MapStyleConfig.inChallengeDiskStrokeWidth, 2);
    expect(MapStyleConfig.verifiedDiskStrokeWidth, 1.5);
    expect(MapStyleConfig.diskFillColor, '#F3EFE5');
    expect(MapStyleConfig.outsideDiskFill, '#FAF8F2');
    expect(
      MapStyleConfig.pinImageId('city', 'inChallenge'),
      'pin-city-inChallenge',
    );
    expect(MapStyleConfig.pinImageId('historical', 'verified'), 'pin-verified');
    expect(
      MapStyleConfig.pinImageExpression,
      contains(MapStyleConfig.verifiedPinImageId),
    );
    expect(MapStyleConfig.diskLayerId, 'poi-disks');
    expect(MapStyleConfig.forestHex, '#35483C');
    expect(MapStyleConfig.sageHex, '#9C9A7B');
    expect(MapStyleConfig.barkHex, '#756653');
    expect(MapStyleConfig.creamHex, '#F3EFE5');
    expect(MapStyleConfig.verifiedIconHex, MapStyleConfig.creamHex);
    expect(MapStyleConfig.verifiedIconHex, isNot(MapStyleConfig.barkHex));
    expect(MapStyleConfig.verifiedDiskFill, '#A7B78C');
    expect(MapStyleConfig.verifiedDiskFill, isNot(MapStyleConfig.forestHex));
    expect(MapStyleConfig.markerColorExpression.first, 'match');
    expect(
      MapStyleConfig.markerColorExpression,
      contains(MapStyleConfig.placeStateVerified),
    );
    expect(
      MapStyleConfig.markerColorExpression,
      contains(MapStyleConfig.creamHex),
    );
    expect(
      MapStyleConfig.markerColorExpression,
      contains(MapStyleConfig.barkHex),
    );
    expect(
      MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.creamHex),
      lessThan(
        MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.forestHex),
      ),
    );
    expect(
      MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.forestHex),
      lessThan(
        MapStyleConfig.markerColorExpression.indexOf(MapStyleConfig.barkHex),
      ),
    );
    expect(
      MapStyleConfig.diskFillExpression,
      contains(MapStyleConfig.placeStateVerified),
    );
    expect(
      MapStyleConfig.diskFillExpression,
      contains(MapStyleConfig.verifiedDiskFill),
    );
    expect(MapStyleConfig.symbolOpacityExpression, contains(0));
    expect(
      MapStyleConfig.diskFillExpression.contains(MapStyleConfig.barkHex),
      isFalse,
    );
    expect(
      MapStyleConfig.diskFillExpression,
      contains(MapStyleConfig.diskFillColor),
    );
    expect(
      MapStyleConfig.diskFillExpression,
      contains(MapStyleConfig.outsideDiskFill),
    );
    expect(
      MapStyleConfig.diskStrokeWidthExpression,
      contains(MapStyleConfig.verifiedDiskStrokeWidth),
    );
    expect(
      MapStyleConfig.diskStrokeWidthExpression,
      contains(MapStyleConfig.diskStrokeWidth),
    );
    expect(
      MapStyleConfig.diskStrokeColorExpression.contains(MapStyleConfig.barkHex),
      isFalse,
    );
    expect(
      MapStyleConfig.diskStrokeColorExpression.contains(
        MapStyleConfig.creamHex,
      ),
      isFalse,
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
      expect(File(host).readAsStringSync().contains('addCircleLayer'), isFalse);
      expect(File(host).readAsStringSync().contains('diskLayerId'), isFalse);
      expect(
        File(host).readAsStringSync().contains('selectedUnderlayLayerId'),
        isFalse,
      );
      expect(
        File(host).readAsStringSync().contains('pinImageExpression'),
        isTrue,
      );
      expect(
        File(host)
            .readAsStringSync()
            .contains('verifiedPlaceIds: widget.verifiedPlaceIds'),
        isTrue,
      );
      expect(File(host).readAsStringSync().contains('_syncPaint'), isFalse);
      final hostSource = File(host).readAsStringSync();
      expect(hostSource.contains('pinImageExpression'), isTrue);
      expect(hostSource.contains('addImage(id, png, false)'), isTrue);
      expect(hostSource.contains('sdfSilhouettePng'), isFalse);
      expect(hostSource.contains('iconColor'), isFalse);
      expect(hostSource.contains('symbolOpacityExpression'), isFalse);
      expect(hostSource.contains('iconOpacity: 1'), isTrue);
      expect(hostSource.contains('iconAllowOverlap: true'), isTrue);
      expect(hostSource.contains("symbolZOrder: 'viewport-y'"), isTrue);
      expect(hostSource.contains('selectedSymbolLayerId'), isTrue);
      expect(hostSource.contains('backgroundPinFilter'), isTrue);
      expect(hostSource.contains('foregroundPinFilter'), isTrue);
      expect(
        hostSource.indexOf('symbolLayerId,'),
        lessThan(hostSource.indexOf('selectedSymbolLayerId,')),
      );
      expect(
        hostSource.indexOf('backgroundPinFilter'),
        lessThan(hostSource.indexOf('foregroundPinFilter')),
      );
      expect(File(config).readAsStringSync().contains('verifiedHex'), isFalse);
      expect(File(host).readAsStringSync().contains('verifiedBadge'), isFalse);
      expect(
        File(host).readAsStringSync().contains('verified_badge_icon'),
        isFalse,
      );
      expect(File(config).readAsStringSync().contains('#B8860B'), isFalse);
    },
  );
}
