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
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      stripePublishableKey: String.fromEnvironment('STRIPE_PUBLISHABLE_KEY'),
      useAssetPlaceCatalog: bool.fromEnvironment('USE_ASSET_PLACE_CATALOG'),
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
