import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/app_services.dart';
import 'data/last_opened_challenge.dart';
import 'data/live_camera_capture.dart';
import 'data/supabase_place_catalog.dart';
import 'data/supabase_repositories.dart';
import 'data/unconfigured.dart';
import 'data/verified_places.dart';
import 'l10n/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final localeController = LocaleController();
  await localeController.load();
  final lastOpened = LastOpenedChallengeStore();
  final verifiedPlaces = VerifiedPlacesStore();

  AppServices services;
  if (config.isSupabaseConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    await verifiedPlaces.bindUser(userId);
    await lastOpened.bindUser(userId);
    services = AppServices(
      config: config,
      auth: SupabaseAuthRepository(client),
      catalog: SupabaseCatalogRepository(client),
      progress: SupabaseProgressRepository(client),
      purchases: SupabasePurchaseRepository(client),
      photos: SupabasePhotoStorage(client),
      photoCapture: LiveCameraPhotoCapture(),
      verifiedPlaces: verifiedPlaces,
      places: resolvePlaceCatalog(config: config, client: client),
    );
    services.auth.authState().listen((profile) {
      unawaited(verifiedPlaces.bindUser(profile?.id));
      unawaited(lastOpened.bindUser(profile?.id));
    });
  } else {
    await lastOpened.load();
    await verifiedPlaces.load();
    services = AppServices(
      config: config,
      auth: UnconfiguredAuth(),
      catalog: UnconfiguredCatalog(),
      progress: UnconfiguredProgress(),
      purchases: UnconfiguredPurchases(),
      photos: UnconfiguredPhotos(),
      photoCapture: UnconfiguredCapture(),
      verifiedPlaces: verifiedPlaces,
      places: resolvePlaceCatalog(config: config),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeController),
        ChangeNotifierProvider.value(value: lastOpened),
        Provider.value(value: services),
      ],
      child: const ViateriaApp(),
    ),
  );
}
