import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Provider;
import 'package:provider/provider.dart';
import 'package:viateria/core/map/map_runtime.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/features/map/application/map_providers.dart';
import 'package:viateria/features/map/data/location_service.dart';
import 'package:viateria/features/map/data/poi_repository.dart';
import 'package:viateria/features/map/domain/poi.dart';
import 'package:viateria/features/map/domain/poi_category.dart';
import 'package:viateria/l10n/locale_controller.dart';

void configureMapWidgetTests() {
  MapRuntime.embedNativeMap = false;
}

Widget wrapWithProviders(
  Widget child,
  AppServices services, {
  LocaleController? locale,
  LastOpenedChallengeStore? lastOpened,
  PoiRepository? pois,
  LocationService? location,
}) {
  return ProviderScope(
    overrides: [
      if (pois != null) poiRepositoryProvider.overrideWithValue(pois),
      if (location != null) locationServiceProvider.overrideWithValue(location),
    ],
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => locale ?? LocaleController(initial: 'en'),
        ),
        ChangeNotifierProvider(
          create: (_) => lastOpened ?? LastOpenedChallengeStore(),
        ),
        Provider.value(value: services),
      ],
      child: child,
    ),
  );
}

List<Poi> samplePois() => const [
  Poi(
    id: 'karlstejn',
    name: 'Karlštejn',
    category: PoiCategory.castle,
    location: GeoPoint(49.9394, 14.1881),
  ),
  Poi(
    id: 'lednice',
    name: 'Lednice',
    category: PoiCategory.chateau,
    location: GeoPoint(48.7997, 16.8056),
  ),
  Poi(
    id: 'trosky',
    name: 'Trosky',
    category: PoiCategory.ruin,
    location: GeoPoint(50.5164, 15.2306),
  ),
];
