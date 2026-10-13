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
import 'package:viateria/domain/diploma_phase.dart';
import 'package:viateria/ui/screens/missing_config_screen.dart';

import 'helpers/catalog_finders.dart';
import 'helpers/fakes.dart';

AppServices buildServices({
  List<Challenge>? challenges,
  List<PromoStripe>? promos,
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
  return AppServices(
    config: AppConfig(
      supabaseUrl: configured ? 'https://example.supabase.co' : '',
      supabaseAnonKey: configured ? 'anon' : '',
      stripePublishableKey: configured ? 'pk_test' : '',
    ),
    auth: MemoryAuth(
      user: const Profile(id: 'user-1', locale: 'en', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(
      challenges: challenges ?? [open.challenge, story.challenge, draft],
      details: [open, story],
      promos: promos ?? [samplePromo()],
    ),
    progress: MemoryProgress(details: [open, story]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
  );
}

Widget wrap(Widget child, AppServices services, {LocaleController? locale}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => locale ?? LocaleController(initial: 'en'),
      ),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider.value(value: services),
    ],
    child: MaterialApp(home: child),
  );
}

Widget wrapApp(AppServices services, {LocaleController? locale}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => locale ?? LocaleController(initial: 'en'),
      ),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider.value(value: services),
    ],
    child: const ViateriaApp(),
  );
}

Finder catalogResultsScrollable() => catalogVerticalScrollable();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'catalog smoke: published challenges and promo stripe, no drafts',
    (tester) async {
      await tester.pumpWidget(wrap(const CatalogScreen(), buildServices()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('catalog-hero-open-1')),
        400,
        scrollable: catalogResultsScrollable(),
      );
      expect(find.text('Open trail'), findsAtLeastNWidgets(1));
      await tester.scrollUntilVisible(
        find.byKey(const Key('catalog-featured-story-1')),
        400,
        scrollable: catalogResultsScrollable(),
      );
      expect(find.text('Story trail'), findsAtLeastNWidgets(1));
      await tester.scrollUntilVisible(
        find.text('Weekend hike'),
        400,
        scrollable: catalogResultsScrollable(),
      );
      expect(find.text('Weekend hike'), findsOneWidget);
      expect(find.text('Hidden draft'), findsNothing);
    },
  );

  testWidgets('catalog empty state when CMS has no published rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CatalogScreen(),
        buildServices(challenges: const [], promos: const []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings('en').catalogEmpty), findsOneWidget);
  });

  testWidgets('catalog controls render at the bottom, not in an AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
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

    final list = find.byType(ListView);
    expect(list, findsWidgets);
    expect(
      tester.getBottomLeft(list.first).dy,
      lessThanOrEqualTo(navTop + 0.5),
    );
    await tester.scrollUntilVisible(
      find.text('Weekend hike'),
      300,
      scrollable: catalogResultsScrollable(),
    );
    expect(find.text('Weekend hike'), findsOneWidget);
  });

  testWidgets('missing config screen is shown when secrets are absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MissingConfigScreen(), buildServices(configured: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings('en').missingConfig), findsOneWidget);
  });

  test('diploma download uses a square png name', () {
    expect(diplomaFileName('Open Trail'), 'vyslapni-diplom-open-trail.png');
    expect(diplomaFileName(''), 'vyslapni-diplom-vyzva.png');
  });
}
