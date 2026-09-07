import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/app_services.dart';
import 'data/live_camera_capture.dart';
import 'data/supabase_repositories.dart';
import 'data/unconfigured.dart';
import 'l10n/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final localeController = LocaleController();
  await localeController.load();

  AppServices services;
  if (config.isSupabaseConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
    final client = Supabase.instance.client;
    services = AppServices(
      config: config,
      auth: SupabaseAuthRepository(client),
      catalog: SupabaseCatalogRepository(client),
      progress: SupabaseProgressRepository(client),
      purchases: SupabasePurchaseRepository(client),
      photos: SupabasePhotoStorage(client),
      photoCapture: LiveCameraPhotoCapture(),
    );
  } else {
    services = AppServices(
      config: config,
      auth: UnconfiguredAuth(),
      catalog: UnconfiguredCatalog(),
      progress: UnconfiguredProgress(),
      purchases: UnconfiguredPurchases(),
      photos: UnconfiguredPhotos(),
      photoCapture: UnconfiguredCapture(),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeController),
        Provider.value(value: services),
      ],
      child: const ViateriaApp(),
    ),
  );
}
