import '../config/app_config.dart';
import '../domain/photo_verify.dart';
import 'repositories.dart';
import 'route_services.dart';

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
  }) : routing = routing ?? OsrmRoutingClient(),
       geocoder = geocoder ?? NominatimGeocoder(),
       deviceLocation = deviceLocation ?? const GeolocatorDeviceLocation(),
       elevation = elevation ?? PublicElevationLookup();

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
}
