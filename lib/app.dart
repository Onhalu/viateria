import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/app_services.dart';
import 'l10n/locale_controller.dart';
import 'theme/app_theme.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/catalog_screen.dart';
import 'ui/screens/challenge_screen.dart';
import 'ui/screens/diploma_screen.dart';
import 'ui/screens/missing_config_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/verify_waypoint_screen.dart';

class ViateriaApp extends StatefulWidget {
  const ViateriaApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<ViateriaApp> createState() => _ViateriaAppState();
}

class _ViateriaAppState extends State<ViateriaApp> {
  late final GoRouter _router = widget.router ?? _buildRouter();

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _AuthRefresh(context.read<AppServices>()),
      redirect: (context, state) {
        final services = context.read<AppServices>();
        if (!services.config.isSupabaseConfigured) {
          return state.matchedLocation == '/setup' ? null : '/setup';
        }
        final signedIn = services.auth.currentUser != null;
        final onAuth = state.matchedLocation == '/auth';
        if (!signedIn && !onAuth) return '/auth';
        if (signedIn && (onAuth || state.matchedLocation == '/setup')) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/setup',
          builder: (context, state) => const MissingConfigScreen(),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const CatalogScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/challenge/:id',
          builder: (context, state) => ChallengeScreen(
            challengeId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/verify/:challengeId/:waypointId',
          builder: (context, state) => VerifyWaypointScreen(
            challengeId: state.pathParameters['challengeId']!,
            waypointId: state.pathParameters['waypointId']!,
          ),
        ),
        GoRoute(
          path: '/diploma/:id',
          builder: (context, state) => DiplomaScreen(
            challengeId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    return MaterialApp.router(
      title: strings.appName,
      theme: AppTheme.light(),
      locale: Locale(locale),
      supportedLocales: AppStringsLocales.supported,
      routerConfig: _router,
    );
  }
}

class AppStringsLocales {
  static const supported = [
    Locale('cs'),
    Locale('en'),
    Locale('de'),
  ];
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(AppServices services) {
    services.auth.authState().listen((_) => notifyListeners());
  }
}
