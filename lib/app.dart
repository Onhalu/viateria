import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/app_services.dart';
import 'l10n/locale_controller.dart';
import 'l10n/sdk_fallback_localizations.dart';
import 'map/place.dart';
import 'theme/app_theme.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/catalog_screen.dart';
import 'ui/screens/challenge_screen.dart';
import 'ui/screens/challenges_map_screen.dart';
import 'ui/screens/diploma_screen.dart';
import 'ui/screens/last_challenge_screen.dart';
import 'ui/screens/missing_config_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/screens/verify_waypoint_screen.dart';
import 'ui/widgets/app_shell.dart';

class ViateriaApp extends StatefulWidget {
  const ViateriaApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<ViateriaApp> createState() => _ViateriaAppState();
}

class _ViateriaAppState extends State<ViateriaApp> {
  late final GoRouter _router = widget.router ?? _buildRouter();

  GoRouter _buildRouter() {
    final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
    return GoRouter(
      navigatorKey: rootKey,
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
        GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const CatalogScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/last',
                  builder: (context, state) => const LastChallengeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/map',
                  builder: (context, state) => const ChallengesMapScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/settings', redirect: (context, state) => '/profile'),
        GoRoute(
          parentNavigatorKey: rootKey,
          path: '/challenge/:id',
          builder: (context, state) =>
              ChallengeScreen(challengeId: state.pathParameters['id']!),
        ),
        GoRoute(
          parentNavigatorKey: rootKey,
          path: '/verify/place/:placeId',
          builder: (context, state) {
            final extra = state.extra;
            return VerifyWaypointScreen(
              placeId: state.pathParameters['placeId']!,
              place: extra is Place ? extra : null,
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootKey,
          path: '/verify/:challengeId/:waypointId',
          builder: (context, state) {
            final extra = state.extra;
            return VerifyWaypointScreen(
              challengeId: state.pathParameters['challengeId']!,
              waypointId: state.pathParameters['waypointId']!,
              placeId: extra is Place ? extra.id : null,
              place: extra is Place ? extra : null,
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootKey,
          path: '/diploma/:id',
          builder: (context, state) =>
              DiplomaScreen(challengeId: state.pathParameters['id']!),
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
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: _router,
    );
  }
}

class AppStringsLocales {
  static const supported = [Locale('cs'), Locale('en'), Locale('de')];
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(AppServices services) {
    services.auth.authState().listen((_) => notifyListeners());
  }
}
