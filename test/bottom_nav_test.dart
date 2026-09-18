import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/app.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/catalog_screen.dart';
import 'package:viateria/ui/screens/last_challenge_screen.dart';
import 'package:viateria/ui/screens/profile_screen.dart';
import 'package:viateria/ui/widgets/app_shell.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/widgets/catalog_cards.dart';
import 'package:viateria/ui/widgets/catalog_welcome_header.dart';

import 'helpers/fakes.dart';

AppServices buildServices({
  List<Challenge>? challenges,
  List<PromoStripe>? promos,
  List<ChallengeDetail>? details,
  MemoryCatalog? catalog,
  MemoryProgress? progress,
  Profile? user,
  bool configured = true,
}) {
  final open = sampleOpenChallenge();
  final story = sampleStoryChallenge();
  final draft = Challenge(
    id: 'draft-1',
    slug: 'hidden',
    accessMode: AccessMode.open,
    pricingType: PricingType.free,
    priceCents: 0,
    currency: 'eur',
    status: PublishStatus.draft,
    translations: const [
      LocalizedText(locale: 'en', title: 'Hidden draft', description: ''),
    ],
  );
  final resolvedDetails = details ?? [open, story];
  return AppServices(
    config: AppConfig(
      supabaseUrl: configured ? 'https://example.supabase.co' : '',
      supabaseAnonKey: configured ? 'anon' : '',
      stripePublishableKey: configured ? 'pk_test' : '',
    ),
    auth: MemoryAuth(
      user:
          user ??
          const Profile(
            id: 'user-1',
            locale: 'en',
            displayName: 'Ada',
            email: 'ada@example.com',
          ),
    ),
    catalog:
        catalog ??
        MemoryCatalog(
          challenges: challenges ?? [open.challenge, story.challenge, draft],
          details: resolvedDetails,
          promos: promos ?? [samplePromo()],
        ),
    progress: progress ?? MemoryProgress(details: resolvedDetails),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
  );
}

Widget wrapScreen(
  Widget child,
  AppServices services, {
  LocaleController? locale,
  LastOpenedChallengeStore? lastOpened,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => locale ?? LocaleController(initial: 'en'),
      ),
      ChangeNotifierProvider(
        create: (_) => lastOpened ?? LastOpenedChallengeStore(),
      ),
      Provider.value(value: services),
    ],
    child: MaterialApp(home: child),
  );
}

Widget wrapApp(
  AppServices services, {
  LocaleController? locale,
  LastOpenedChallengeStore? lastOpened,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => locale ?? LocaleController(initial: 'en'),
      ),
      ChangeNotifierProvider(
        create: (_) => lastOpened ?? LastOpenedChallengeStore(),
      ),
      Provider.value(value: services),
    ],
    child: const ViateriaApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signed-in shell shows four bottom destinations', (tester) async {
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    final nav = find.byKey(const Key('app-bottom-nav'));
    expect(nav, findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav-shell')), findsOneWidget);

    final strings = AppStrings('en');
    expect(find.text(strings.catalogTitle), findsOneWidget);
    expect(find.text(strings.navLastChallenge), findsOneWidget);
    expect(find.text(strings.navMap), findsOneWidget);
    expect(find.text(strings.navProfile), findsOneWidget);

    final screenSize = tester.getSize(find.byType(Scaffold).first);
    final navTop = tester.getTopLeft(nav).dy;
    expect(navTop, greaterThan(screenSize.height / 2));
    expect(find.text('Weekend hike'), findsOneWidget);

    final navRect = tester.getRect(nav);
    expect(navRect.left, 0);
    expect(navRect.right, screenSize.width);

    final shell = tester.widget<Material>(
      find.byKey(const Key('app-bottom-nav-shell')),
    );
    expect(shell.color, BrandColors.sage);
    final shellRect = tester.getRect(
      find.byKey(const Key('app-bottom-nav-shell')),
    );
    expect(shellRect.left, 0);
    expect(shellRect.right, screenSize.width);
    expect(shellRect.bottom, screenSize.height);
  });

  testWidgets('bottom nav is full-width sage including the home indicator', (
    tester,
  ) async {
    const homeIndicator = 34.0;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: homeIndicator);
    tester.view.viewPadding = const FakeViewPadding(bottom: homeIndicator);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });

    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    final screenSize = tester.getSize(find.byType(Scaffold).first);
    final shellRect = tester.getRect(
      find.byKey(const Key('app-bottom-nav-shell')),
    );
    expect(shellRect.left, 0);
    expect(shellRect.right, screenSize.width);
    expect(shellRect.bottom, screenSize.height);

    final navRect = tester.getRect(find.byKey(const Key('app-bottom-nav')));
    expect(navRect.left, 0);
    expect(navRect.right, screenSize.width);
    expect(
      navRect.bottom,
      lessThanOrEqualTo(screenSize.height - homeIndicator + 0.5),
    );
    expect(navRect.bottom, lessThan(screenSize.height));
  });

  testWidgets('last-challenge tab shows empty state when none opened', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navLastChallenge));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('last-challenge-empty')), findsOneWidget);
    expect(find.text(strings.lastChallengeEmpty), findsOneWidget);
    expect(find.text(strings.lastChallengeEmptyHint), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
  });

  testWidgets('opening a catalog challenge updates last-opened tab', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final store = LastOpenedChallengeStore();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapApp(buildServices(), lastOpened: store));
    await tester.pumpAndSettle();

    final card = find.widgetWithText(ChallengeCard, 'Open trail');
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('catalog-results')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.challengeId, 'open-1');
    expect(find.text('Visit any stop'), findsWidgets);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navLastChallenge));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Open trail'), findsWidgets);
    expect(find.text('Visit any stop'), findsWidgets);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
  });

  testWidgets('map tab shows places search, filters and list toggle', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navMap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('map-empty')), findsNothing);
    expect(find.byKey(const Key('map-search-field')), findsOneWidget);
    expect(find.byKey(const Key('map-filter-button')), findsOneWidget);
    expect(find.byKey(const Key('map-view-toggle')), findsOneWidget);
    expect(find.byKey(const Key('map-poi-count')), findsOneWidget);
    expect(find.byKey(const Key('map-locate-fab')), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
  });

  testWidgets('profile tab shows identity and sign out', (tester) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navProfile));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.text('Ada'),
      ),
      findsOneWidget,
    );
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text(strings.signOut), findsOneWidget);
    expect(find.text(strings.language), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
  });

  testWidgets(
    'catalog screen still lists published challenges without drafts',
    (tester) async {
      await tester.pumpWidget(
        wrapScreen(const CatalogScreen(), buildServices()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weekend hike'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Open trail'),
        400,
        scrollable: find.descendant(
          of: find.byKey(const Key('catalog-results')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Open trail'), findsOneWidget);
      expect(find.text('Hidden draft'), findsNothing);
    },
  );

  testWidgets('last challenge missing id is an empty state, not an error', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(
      wrapScreen(
        const LastChallengeScreen(),
        buildServices(),
        lastOpened: LastOpenedChallengeStore(initialId: 'gone-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('last-challenge-missing')), findsOneWidget);
    expect(find.text(strings.lastChallengeMissing), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsNothing);
  });

  testWidgets('last challenge keeps retry when a transient load fails', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final open = sampleOpenChallenge();
    await tester.pumpWidget(
      wrapScreen(
        const LastChallengeScreen(),
        buildServices(
          progress: MemoryProgress(details: [open])
            ..fetchProgressError = Exception('timeout'),
        ),
        lastOpened: LastOpenedChallengeStore(initialId: open.challenge.id),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('last-challenge-missing')), findsNothing);
    expect(find.byKey(const Key('challenge-load-error')), findsOneWidget);
    expect(find.text(strings.errorGeneric), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
  });

  testWidgets('map tab still loads when challenge details fail', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final open = sampleOpenChallenge();
    await tester.pumpWidget(
      wrapApp(
        buildServices(
          catalog: MemoryCatalog(challenges: [open.challenge], details: [open])
            ..fetchChallengeError = Exception('timeout'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.navMap));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-load-error')), findsNothing);
    expect(find.byKey(const Key('map-search-field')), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
  });

  testWidgets(
    'bottom nav is sage with cream selected pill and forest unselected',
    (tester) async {
      await tester.pumpWidget(wrapApp(buildServices()));
      await tester.pumpAndSettle();

      final shell = tester.widget<Material>(
        find.byKey(const Key('app-bottom-nav-shell')),
      );
      expect(shell.color, BrandColors.sage);

      final pillSize = tester.getSize(
        find.byKey(const Key('sage-nav-indicator')),
      );
      expect(pillSize.width, AppShell.indicatorSize.width);
      expect(pillSize.height, AppShell.indicatorSize.height);

      final pill = tester.widget<Container>(
        find.byKey(const Key('sage-nav-indicator')),
      );
      final decoration = pill.decoration! as BoxDecoration;
      expect(decoration.color, AppShell.selectedPill);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppShell.indicatorRadius),
      );

      expect(
        tester.widget<Icon>(find.byIcon(Icons.explore)).color,
        BrandColors.cream,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.flag_outlined)).color,
        AppShell.unselectedForeground,
      );

      final selectedLabel = tester.widget<Text>(
        find.text(AppStrings('en').catalogTitle),
      );
      expect(selectedLabel.style?.color, BrandColors.cream);
      expect(selectedLabel.style?.fontWeight, FontWeight.w600);

      final unselectedLabel = tester.widget<Text>(
        find.text(AppStrings('en').navLastChallenge),
      );
      expect(unselectedLabel.style?.color, AppShell.unselectedForeground);
    },
  );

  testWidgets('opening a challenge keeps the shell so tabs stay reachable', (
    tester,
  ) async {
    final strings = AppStrings('en');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    final card = find.widgetWithText(ChallengeCard, 'Open trail');
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('catalog-results')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('challenge-title')), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);

    await tester.tap(find.text(strings.navMap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('map-search-field')), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);

    await tester.tap(find.text(strings.catalogTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('challenge-title')), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog-results')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
  });

  testWidgets('catalog welcome header greets the signed-in display name', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog-welcome-header')), findsOneWidget);
    expect(find.text(strings.welcomeBack), findsOneWidget);
    expect(find.byKey(const Key('catalog-welcome-name')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('catalog-welcome-name'))).data,
      'Ada',
    );
    expect(find.byType(Badge), findsNothing);
    expect(find.byKey(const Key('catalog-search-field')), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-chips')), findsOneWidget);

    final header = tester.widget<ColoredBox>(
      find.byKey(const Key('catalog-welcome-header')),
    );
    expect(header.color, BrandColors.sage);

    expect(
      tester.getSize(find.byKey(const Key('catalog-welcome-avatar'))),
      const Size(
        CatalogWelcomeHeader.avatarSize,
        CatalogWelcomeHeader.avatarSize,
      ),
    );

    final greeting = tester.widget<Text>(
      find.byKey(const Key('catalog-welcome-greeting')),
    );
    expect(greeting.style?.color, BrandColors.cream.withValues(alpha: 0.85));
    final name = tester.widget<Text>(
      find.byKey(const Key('catalog-welcome-name')),
    );
    expect(name.style?.color, BrandColors.cream);
    expect(name.style?.fontWeight, FontWeight.w700);

    final headerRect = tester.getRect(
      find.byKey(const Key('catalog-welcome-header')),
    );
    expect(headerRect.left, 0);
    expect(headerRect.top, 0);
    expect(
      tester.getTopLeft(find.byKey(const Key('catalog-search-field'))).dy,
      greaterThan(headerRect.bottom),
    );
  });

  testWidgets(
    'catalog welcome header falls back when display name is missing',
    (tester) async {
      await tester.pumpWidget(
        wrapApp(
          buildServices(
            user: const Profile(
              id: 'user-1',
              locale: 'en',
              email: 'ada@example.com',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('catalog-welcome-name'))).data,
        AppStrings('en').welcomeNameFallback,
      );
    },
  );

  testWidgets('catalog welcome header copy is Czech by locale', (tester) async {
    await tester.pumpWidget(
      wrapApp(buildServices(), locale: LocaleController(initial: 'cs')),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings('cs').welcomeBack), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('catalog-welcome-name'))).data,
      'Ada',
    );
  });

  testWidgets('catalog welcome map and profile buttons switch tabs', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog-welcome-map')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('map-search-field')), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);

    await tester.tap(find.text(strings.catalogTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('catalog-welcome-profile')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.text('Ada'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
  });
}
