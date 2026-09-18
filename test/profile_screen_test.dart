import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/data/verified_places.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/profile_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

AppServices _services({
  MemoryProgress? progress,
  VerifiedPlacesStore? verifiedPlaces,
}) {
  final open = sampleOpenChallenge();
  final story = sampleStoryChallenge();
  return AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: MemoryAuth(
      user: const Profile(
        id: 'user-1',
        locale: 'en',
        displayName: 'Ada',
        email: 'ada@example.com',
      ),
    ),
    catalog: MemoryCatalog(
      challenges: [open.challenge, story.challenge],
      details: [open, story],
    ),
    progress: progress ?? MemoryProgress(details: [open, story]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    verifiedPlaces: verifiedPlaces,
  );
}

List<Place> _places() => [
  ...samplePlaces(),
  const Place(
    id: 'vitkovice',
    name: 'Ostrava-Vítkovice',
    category: PlaceCategory.technical,
    location: GeoPoint(49.81, 18.28),
  ),
];

Widget _wrap(
  AppServices services, {
  String locale = 'en',
  LastOpenedChallengeStore? lastOpened,
}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => Scaffold(
          body: ProfileScreen(places: MemoryPlaceCatalog(_places())),
        ),
      ),
      GoRoute(
        path: '/challenge/:id',
        builder: (context, state) => Text(
          'opened-${state.pathParameters['id']}',
          key: const Key('opened-challenge'),
        ),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: locale)),
      ChangeNotifierProvider(
        create: (_) => lastOpened ?? LastOpenedChallengeStore(),
      ),
      Provider.value(value: services),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows 0 / N per category and empty completed list', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(_wrap(_services()));
    await tester.pumpAndSettle();

    expect(find.text(strings.visitedPlaces), findsOneWidget);
    expect(find.byKey(const Key('profile-visited-city')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-visited-city'))).data,
      '0 / 1',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-visited-nature'))).data,
      '0 / 1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-visited-technical')))
          .data,
      '0 / 1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-visited-historical')))
          .data,
      '0 / 1',
    );
    expect(find.text(strings.t('catCity')), findsOneWidget);
    expect(find.text(strings.completedChallenges), findsOneWidget);
    expect(find.text(strings.completedChallengesEmpty), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(strings.signOut),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(strings.language), findsOneWidget);
    expect(find.text(strings.signOut), findsOneWidget);

    final profileContext = tester.element(find.byType(ProfileScreen));
    expect(Theme.of(profileContext).scaffoldBackgroundColor, BrandColors.cream);
  });

  testWidgets('shows verified counts and completed challenges', (tester) async {
    final strings = AppStrings('en');
    final progress = MemoryProgress(details: [sampleOpenChallenge()]);
    progress.statuses['open-1'] = ChallengeRunStatus.completed;
    progress.completed['open-1'] = {'ow-1', 'ow-2'};
    final lastOpened = LastOpenedChallengeStore();

    await tester.pumpWidget(
      _wrap(
        _services(
          progress: progress,
          verifiedPlaces: VerifiedPlacesStore(
            initial: {'staromestske', 'karlstejn'},
          ),
        ),
        lastOpened: lastOpened,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('profile-visited-city'))).data,
      '1 / 1',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-visited-nature'))).data,
      '0 / 1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-visited-technical')))
          .data,
      '0 / 1',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-visited-historical')))
          .data,
      '1 / 1',
    );
    expect(find.text(strings.completedChallengesEmpty), findsNothing);
    expect(find.byKey(const Key('profile-completed-open-1')), findsOneWidget);
    expect(find.text('Open trail'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-completed-open-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opened-challenge')), findsOneWidget);
    expect(find.text('opened-open-1'), findsOneWidget);
    expect(lastOpened.challengeId, 'open-1');
  });

  testWidgets('Czech labels stay on the profile stats block', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(_wrap(_services(), locale: 'cs'));
    await tester.pumpAndSettle();
    expect(find.text(strings.visitedPlaces), findsOneWidget);
    expect(find.text(strings.t('catCity')), findsOneWidget);
    expect(find.text(strings.completedChallengesEmpty), findsOneWidget);
  });
}
