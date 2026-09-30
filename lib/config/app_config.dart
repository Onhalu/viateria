import 'package:flutter/foundation.dart';

/// Compile-time secrets via `--dart-define` / `--dart-define-from-file=.env`.
///
/// Never hardcode keys. Empty values mean the backend is not configured.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.stripePublishableKey,
    this.useAssetPlaceCatalog = false,
  });

  factory AppConfig.fromEnvironment() {
    const useAssetPlaceCatalog = bool.fromEnvironment(
      'USE_ASSET_PLACE_CATALOG',
    );
    refuseAssetPlaceCatalogInRelease(
      releaseMode: kReleaseMode,
      useAssetPlaceCatalog: useAssetPlaceCatalog,
    );
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      stripePublishableKey: String.fromEnvironment('STRIPE_PUBLISHABLE_KEY'),
      useAssetPlaceCatalog: useAssetPlaceCatalog,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String stripePublishableKey;

  /// Explicit opt-in to the bundled `assets/map/pois.geojson` catalog.
  /// Production leaves this false and reads `public.places`.
  final bool useAssetPlaceCatalog;

  bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get isStripeConfigured => stripePublishableKey.isNotEmpty;
}

/// Release reads `public.places`. The bundled GeoJSON catalog is a debug opt-in.
///
/// Dart `assert` is stripped from release binaries, so a release build with
/// [useAssetPlaceCatalog] throws instead of starting on the asset file.
void refuseAssetPlaceCatalogInRelease({
  required bool releaseMode,
  required bool useAssetPlaceCatalog,
}) {
  if (releaseMode && useAssetPlaceCatalog) {
    throw StateError(
      'USE_ASSET_PLACE_CATALOG is refused in release. '
      'The production catalog is public.places.',
    );
  }
}
