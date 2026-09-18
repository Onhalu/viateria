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
  List<Place>? places,
}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => Scaffold(
          backgroundColor: BrandColors.cream,
          body: ProfileScreen(places: MemoryPlaceCatalog(places ?? _places())),
        ),
        routes: [
          GoRoute(
            path: 'challenge/:id',
            builder: (context, state) => Text(
              'opened-${state.pathParameters['id']}',
              key: const Key('opened-challenge'),
            ),
          ),
        ],
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

    expect(find.byKey(const Key('profile-visited-places')), findsOneWidget);
    expect(find.byKey(const Key('profile-visited-card-city')), findsOneWidget);
    expect(
      find.byKey(const Key('profile-visited-card-nature')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile-visited-card-technical')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile-visited-card-historical')),
      findsOneWidget,
    );
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

    final cityCard = tester.getTopLeft(
      find.byKey(const Key('profile-visited-card-city')),
    );
    final natureCard = tester.getTopLeft(
      find.byKey(const Key('profile-visited-card-nature')),
    );
    final technicalCard = tester.getTopLeft(
      find.byKey(const Key('profile-visited-card-technical')),
    );
    final historicalCard = tester.getTopLeft(
      find.byKey(const Key('profile-visited-card-historical')),
    );
    expect(cityCard.dy, closeTo(natureCard.dy, 1));
    expect(technicalCard.dy, closeTo(historicalCard.dy, 1));
    expect(natureCard.dx, greaterThan(cityCard.dx + 20));
    expect(technicalCard.dy, greaterThan(cityCard.dy + 20));

    expect(find.text(strings.profileCatCity), findsOneWidget);
    expect(find.text(strings.profileCatNature), findsOneWidget);
    expect(find.text(strings.profileCatTechnical), findsOneWidget);
    expect(find.text(strings.profileCatHistorical), findsOneWidget);

    final countStyle = tester
        .widget<Text>(find.byKey(const Key('profile-visited-city')))
        .style;
    expect(countStyle?.fontSize, 20);
    expect(countStyle?.fontWeight, FontWeight.w700);
    expect(countStyle?.color, BrandColors.forest);

    final labelStyle = tester
        .widget<Text>(find.text(strings.profileCatCity))
        .style;
    expect(labelStyle?.fontSize, 12);
    expect(labelStyle?.color, BrandColors.bark);

    final card = tester.widget<DecoratedBox>(
      find.byKey(const Key('profile-visited-card-city')),
    );
    final decoration = card.decoration as BoxDecoration;
    expect(decoration.color, BrandColors.cream);
    expect(decoration.color, isNot(BrandColors.shellFill));
    expect(decoration.borderRadius, BorderRadius.circular(16));
    expect(
      decoration.border,
      const Border.fromBorderSide(BorderSide(color: BrandColors.beige)),
    );

    final icon = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('profile-visited-card-city')),
        matching: find.byType(Image),
      ),
    );
    expect(icon.width, 22);
    expect(icon.height, 22);

    expect(find.text(strings.completedChallenges), findsOneWidget);
    expect(find.text(strings.completedChallengesEmpty), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(strings.signOut),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(strings.language), findsOneWidget);
    expect(find.text(strings.signOut), findsOneWidget);

    final profileMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(profileMaterial.color, BrandColors.cream);
    expect(profileMaterial.color, isNot(BrandColors.shellFill));
    expect(
      Theme.of(tester.element(find.byType(ProfileScreen)))
          .scaffoldBackgroundColor,
      BrandColors.cream,
    );
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
    expect(find.text(strings.profileCatCity), findsOneWidget);
    expect(find.text(strings.profileCatNature), findsOneWidget);
    expect(find.text(strings.profileCatTechnical), findsOneWidget);
    expect(find.text(strings.profileCatHistorical), findsOneWidget);
    expect(find.text(strings.completedChallenges), findsOneWidget);
    expect(find.text(strings.completedChallengesEmpty), findsOneWidget);
  });

  testWidgets('missing catalog still shows four 0 / 0 cards', (tester) async {
    await tester.pumpWidget(_wrap(_services(), places: const []));
    await tester.pumpAndSettle();
    for (final category in PlaceCategory.values) {
      expect(
        tester
            .widget<Text>(find.byKey(Key('profile-visited-${category.name}')))
            .data,
        '0 / 0',
      );
      expect(
        find.byKey(Key('profile-visited-card-${category.name}')),
        findsOneWidget,
      );
    }
  });
}
