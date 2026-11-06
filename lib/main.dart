import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/app_services.dart';
import 'data/diploma_client.dart';
import 'data/last_opened_challenge.dart';
import 'data/live_camera_capture.dart';
import 'data/place_visit_hydrate.dart';
import 'data/supabase_leaderboard.dart';
import 'data/supabase_membership.dart';
import 'data/vandery_plus_session.dart';
import 'data/supabase_place_catalog.dart';
import 'data/supabase_repositories.dart';
import 'data/unconfigured.dart';
import 'data/verified_places.dart';
import 'l10n/locale_controller.dart';
import 'theme/brand_typography.dart';

/// Mobile return from the FAPI form. Failures stay on the submitting poll.
Future<void> listenForVanderyPlusLinks(VanderyPlusSession session) async {
  try {
    final links = AppLinks();
    final initial = await links.getInitialLink();
    if (initial != null) await session.consumeReturnUri(initial);
    links.uriLinkStream.listen(
      (uri) => unawaited(session.consumeReturnUri(uri)),
      onError: (_) {},
    );
  } catch (_) {}
}

Future<void> syncLocaleFromProfile(
  LocaleController controller,
  SupabaseClient client,
) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    await controller.load();
    return;
  }
  try {
    final row = await client
        .from('profiles')
        .select('locale')
        .eq('id', userId)
        .maybeSingle();
    controller.adoptResolvedLocale(
      resolveSessionLocale(
        signedIn: true,
        profileLocale: row?['locale'] as String?,
      ),
    );
  } catch (_) {
    // Keep the SharedPreferences locale loaded before sign-in.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerOnestLicense();
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
    final leaderboard = SupabaseLeaderboardRepository(client);
    final vanderyPlus = VanderyPlusSession(
      repository: SupabaseMembershipRepository(client),
      priceLabel: config.vanderyPlusPriceLabel,
      openUrl: launchExternalUrl,
    );
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
      leaderboard: leaderboard,
      diplomas: SupabaseDiplomaClient(client),
      vanderyPlus: vanderyPlus,
    );
    if (!kIsWeb) {
      unawaited(listenForVanderyPlusLinks(vanderyPlus));
    }
    if (userId != null && userId.isNotEmpty) {
      await refreshVerifiedPlacesOnLogin(
        userId: userId,
        store: verifiedPlaces,
        leaderboard: leaderboard,
      );
      await vanderyPlus.refresh();
    }
    await syncLocaleFromProfile(localeController, client);
    services.auth.authState().listen((profile) {
      unawaited(() async {
        await syncLocaleFromProfile(localeController, client);
        await verifiedPlaces.bindUser(profile?.id);
        await lastOpened.bindUser(profile?.id);
        final id = profile?.id;
        if (id == null || id.isEmpty) return;
        await refreshVerifiedPlacesOnLogin(
          userId: id,
          store: verifiedPlaces,
          leaderboard: leaderboard,
        );
        await vanderyPlus.refresh();
      }());
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
