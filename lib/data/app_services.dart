import '../config/app_config.dart';
import '../domain/photo_verify.dart';
import 'repositories.dart';

class AppServices {
  const AppServices({
    required this.config,
    required this.auth,
    required this.catalog,
    required this.progress,
    required this.purchases,
    required this.photos,
    required this.photoCapture,
  });

  final AppConfig config;
  final AuthRepository auth;
  final CatalogRepository catalog;
  final ProgressRepository progress;
  final PurchaseRepository purchases;
  final PhotoStorage photos;
  final PhotoCapture photoCapture;
}
