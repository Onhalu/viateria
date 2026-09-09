import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../domain/photo_verify.dart';
import 'repositories.dart';
import 'route_services.dart';

typedef ExternalUrlOpener = Future<void> Function(Uri url);

Future<void> launchExternalUrl(Uri url) async {
  await launchUrl(
    url,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}

class AppServices {
  AppServices({
    required this.config,
    required this.auth,
    required this.catalog,
    required this.progress,
    required this.purchases,
    required this.photos,
    required this.photoCapture,
    RoutingClient? routing,
    PlaceGeocoder? geocoder,
    DeviceLocation? deviceLocation,
    ElevationLookup? elevation,
    ExternalUrlOpener? openUrl,
  }) : routing = routing ?? OsrmRoutingClient(),
       geocoder = geocoder ?? NominatimGeocoder(),
       deviceLocation = deviceLocation ?? const GeolocatorDeviceLocation(),
       elevation = elevation ?? PublicElevationLookup(),
       openUrl = openUrl ?? launchExternalUrl;

  final AppConfig config;
  final AuthRepository auth;
  final CatalogRepository catalog;
  final ProgressRepository progress;
  final PurchaseRepository purchases;
  final PhotoStorage photos;
  final PhotoCapture photoCapture;
  final RoutingClient routing;
  final PlaceGeocoder geocoder;
  final DeviceLocation deviceLocation;
  final ElevationLookup elevation;
  final ExternalUrlOpener openUrl;
}
