import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/challenge_mapping.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/domain/catalog_query.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/screens/catalog_screen.dart';
import 'package:viateria/ui/widgets/catalog_filters.dart';
import 'package:viateria/ui/widgets/catalog_welcome_header.dart';
import 'package:viateria/ui/widgets/country_flag.dart';

import 'helpers/catalog_finders.dart';
import 'helpers/fakes.dart';

Challenge _challenge({
  required String id,
  required String title,
  String description = '',
  AccessMode mode = AccessMode.open,
  PricingType pricing = PricingType.free,
  String? countryCode,
  String? region,
  CatalogDifficulty? difficulty,
  List<LocalizedText>? translations,
}) {
  return Challenge(
    id: id,
    slug: id,
    accessMode: mode,
    pricingType: pricing,
    priceCents: pricing == PricingType.paid ? 499 : 0,
    currency: 'eur',
    status: PublishStatus.published,
    region: region,
    countryCode: countryCode,
    difficulty: difficulty,
    translations:
        translations ??
        [LocalizedText(locale: 'en', title: title, description: description)],
  );
}

AppServices _services({
  List<Challenge>? challenges,
  List<ChallengeDetail>? details,
  List<PromoStripe>? promos,
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
      user: const Profile(id: 'user-1', locale: 'en', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(
      challenges: challenges ?? [open.challenge, story.challenge],
      details: details ?? [open, story],
      promos: promos ?? [samplePromo()],
    ),
    progress: MemoryProgress(details: details ?? [open, story]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
  );
}

Widget _wrap(Widget child, AppServices services, {String locale = 'en'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: locale)),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider.value(value: services),
    ],
    child: MaterialApp(home: child),
  );
}

Future<void> _pumpCatalog(
  WidgetTester tester, {
  String locale = 'en',
  List<Challenge>? challenges,
  List<ChallengeDetail>? details,
  List<PromoStripe>? promos,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    _wrap(
      const CatalogScreen(),
      _services(challenges: challenges, details: details, promos: promos),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('filterCatalogChallenges', () {
    final freeOpenCz = _challenge(
      id: 'a',
      title: 'Pálava hike',
      description: 'White rocks',
      countryCode: 'CZ',
    );
    final paidStorySk = _challenge(
      id: 'b',
      title: 'Tatra story',
      description: 'Unlock in order',
      mode: AccessMode.story,
      pricing: PricingType.paid,
      countryCode: 'SK',
    );
    final paidOpenAt = _challenge(
      id: 'c',
      title: 'Alpine trail',
      description: 'Vienna woods',
      pricing: PricingType.paid,
      countryCode: 'AT',
    );
    final all = [freeOpenCz, paidStorySk, paidOpenAt];

    test('empty groups keep every challenge', () {
      expect(filterCatalogChallenges(all, const CatalogFilter()), all);
    });

    test('price is OR within the group', () {
      final filtered = filterCatalogChallenges(
        all,
        CatalogFilter(pricingTypes: {PricingType.free, PricingType.paid}),
      );
      expect(filtered, all);
    });

    test('single price chip keeps only that pricing', () {
      final filtered = filterCatalogChallenges(
        all,
        CatalogFilter(pricingTypes: {PricingType.free}),
      );
      expect(filtered, [freeOpenCz]);
    });

    test('mode is OR within the group', () {
      final filtered = filterCatalogChallenges(
        all,
        CatalogFilter(accessModes: {AccessMode.open, AccessMode.story}),
      );
      expect(filtered, all);
    });

    test('region is OR within the group', () {
      final filtered = filterCatalogChallenges(
        all,
        CatalogFilter(countryCodes: {'CZ', 'AT'}),
      );
      expect(filtered.map((c) => c.id), ['a', 'c']);
    });

    test('groups combine with AND', () {
      final filtered = filterCatalogChallenges(
        all,
        CatalogFilter(
          pricingTypes: {PricingType.paid},
          accessModes: {AccessMode.open},
          countryCodes: {'AT'},
        ),
      );
      expect(filtered, [paidOpenAt]);
    });

    test('AND across groups can yield no matches', () {
      final filtered = filterCatalogChallenges(
        all,
        CatalogFilter(
          pricingTypes: {PricingType.free},
          accessModes: {AccessMode.story},
        ),
      );
      expect(filtered, isEmpty);
    });

    test('search matches title and description from any i18n locale', () {
      final bilingual = _challenge(
        id: 'd',
        title: 'ignored',
        translations: const [
          LocalizedText(
            locale: 'en',
            title: 'Ridge walk',
            description: 'Forest path',
          ),
          LocalizedText(
            locale: 'cs',
            title: 'Hřebenovka',
            description: 'Pálava a vápencové skály',
          ),
        ],
      );
      expect(
        filterCatalogChallenges([
          bilingual,
        ], const CatalogFilter(query: 'hrebenovka')),
        [bilingual],
      );
      expect(
        filterCatalogChallenges([
          bilingual,
        ], const CatalogFilter(query: 'vápen')),
        [bilingual],
      );
      expect(
        filterCatalogChallenges([
          bilingual,
        ], const CatalogFilter(query: 'forest')),
        [bilingual],
      );
    });

    test('search ANDs with chips', () {
      final filtered = filterCatalogChallenges(
        all,
        CatalogFilter(query: 'trail', pricingTypes: {PricingType.paid}),
      );
      expect(filtered, [paidOpenAt]);
    });

    test('unknown country_code does not match a region chip', () {
      final unknown = _challenge(id: 'x', title: 'Mystery', countryCode: null);
      expect(
        filterCatalogChallenges([unknown], CatalogFilter(countryCodes: {'CZ'})),
        isEmpty,
      );
    });

    test('promos stay visible unless search is active', () {
      expect(const CatalogFilter().showPromos, isTrue);
      expect(
        CatalogFilter(pricingTypes: {PricingType.paid}).showPromos,
        isTrue,
      );
      expect(const CatalogFilter(query: '  hike ').showPromos, isFalse);
    });

    test('length chips filter by waypoint-derived hike time', () {
      final open = sampleOpenChallenge();
      final stats = catalogRouteStatsByChallenge([open]);
      expect(stats[open.challenge.id]?.lengthBand, CatalogLengthBand.short);
      expect(
        filterCatalogChallenges(
          [open.challenge],
          CatalogFilter(lengthBands: {CatalogLengthBand.short}),
          routeStats: stats,
        ),
        [open.challenge],
      );
      expect(
        filterCatalogChallenges(
          [open.challenge],
          CatalogFilter(lengthBands: {CatalogLengthBand.long}),
          routeStats: stats,
        ),
        isEmpty,
      );
    });

    test('difficulty chips exclude null and unmatched values', () {
      final easy = _challenge(
        id: 'easy',
        title: 'Easy walk',
        difficulty: CatalogDifficulty.easy,
      );
      final hard = _challenge(
        id: 'hard',
        title: 'Hard climb',
        difficulty: CatalogDifficulty.hard,
      );
      final unset = _challenge(id: 'unset', title: 'No grade');
      expect(
        filterCatalogChallenges([
          easy,
          hard,
          unset,
        ], CatalogFilter(difficulties: {CatalogDifficulty.easy})),
        [easy],
      );
      expect(
        filterCatalogChallenges(
          [easy, hard, unset],
          CatalogFilter(
            difficulties: {CatalogDifficulty.easy, CatalogDifficulty.hard},
          ),
        ),
        [easy, hard],
      );
      expect(
        filterCatalogChallenges([
          easy,
          hard,
          unset,
        ], CatalogFilter(difficulties: {CatalogDifficulty.normal})),
        isEmpty,
      );
    });

    test('length and difficulty AND with other groups', () {
      final match = _challenge(
        id: 'm',
        title: 'Match',
        pricing: PricingType.paid,
        difficulty: CatalogDifficulty.easy,
        countryCode: 'CZ',
      );
      final stats = {
        'm': const CatalogRouteStats(estimatedDuration: Duration(hours: 2)),
      };
      expect(
        filterCatalogChallenges(
          [match],
          CatalogFilter(
            pricingTypes: {PricingType.paid},
            lengthBands: {CatalogLengthBand.short},
            difficulties: {CatalogDifficulty.easy},
          ),
          routeStats: stats,
        ),
        [match],
      );
      expect(
        filterCatalogChallenges(
          [match],
          CatalogFilter(
            pricingTypes: {PricingType.paid},
            lengthBands: {CatalogLengthBand.long},
            difficulties: {CatalogDifficulty.easy},
          ),
          routeStats: stats,
        ),
        isEmpty,
      );
    });
  });

  group('country_code mapping', () {
    test('parses ISO codes and rejects junk', () {
      expect(parseCountryCode('cz'), 'CZ');
      expect(parseCountryCode(' SK '), 'SK');
      expect(parseCountryCode('US'), isNull);
      expect(parseCountryCode(''), isNull);
    });

    test('infers CZ from known Czech region labels', () {
      for (final region in [
        'Pálava',
        'Beskydy',
        'Vysočina',
        'Orlické hory',
        'České středohoří',
        'Morava',
        'Česko',
      ]) {
        expect(inferCountryCodeFromRegion(region), 'CZ', reason: region);
      }
    });

    test('leaves non-obvious regions null', () {
      expect(inferCountryCodeFromRegion('Alps'), isNull);
      expect(inferCountryCodeFromRegion(null), isNull);
    });

    test('challengeFromRow prefers country_code then infers region', () {
      final withCode = challengeFromRow({
        'id': 'c',
        'slug': 'c',
        'access_mode': 'open',
        'pricing_type': 'free',
        'price_cents': 0,
        'currency': 'eur',
        'status': 'published',
        'region': 'Pálava',
        'country_code': 'sk',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'C', 'description': ''},
        ],
      });
      expect(withCode.region, 'Pálava');
      expect(withCode.countryCode, 'SK');

      final inferred = challengeFromRow({
        'id': 'c2',
        'slug': 'c2',
        'access_mode': 'story',
        'pricing_type': 'paid',
        'price_cents': 1,
        'currency': 'eur',
        'status': 'published',
        'region': 'Beskydy',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'B', 'description': ''},
        ],
      });
      expect(inferred.accessMode, AccessMode.story);
      expect(inferred.region, 'Beskydy');
      expect(inferred.countryCode, 'CZ');
      expect(inferred.difficulty, isNull);

      final graded = challengeFromRow({
        'id': 'c3',
        'slug': 'c3',
        'access_mode': 'open',
        'pricing_type': 'free',
        'price_cents': 0,
        'currency': 'eur',
        'status': 'published',
        'difficulty': 'hard',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'H', 'description': ''},
        ],
      });
      expect(graded.difficulty, CatalogDifficulty.hard);
      expect(
        challengeFromRow({
          'id': 'c4',
          'slug': 'c4',
          'access_mode': 'open',
          'pricing_type': 'free',
          'price_cents': 0,
          'currency': 'eur',
          'status': 'published',
          'difficulty': 'legendary',
          'challenge_i18n': [
            {'locale': 'cs', 'title': 'X', 'description': ''},
          ],
        }).difficulty,
        isNull,
      );
    });
  });

  group('waypoint-derived catalog route stats', () {
    test('omits stats when there are fewer than two waypoints', () {
      expect(catalogRouteStatsFromWaypoints(const []), isNull);
      expect(
        catalogRouteStatsFromWaypoints([
          Waypoint(
            id: 'only',
            challengeId: 'c',
            sortOrder: 0,
            lat: 50,
            lng: 14,
            elevationM: 200,
            translations: const [],
          ),
        ]),
        isNull,
      );
    });

    test('uses RoutePlanner hike distance and time from waypoints', () {
      final stats = catalogRouteStatsFromWaypoints(
        sampleOpenChallenge().waypoints,
      );
      expect(stats, isNotNull);
      expect(stats!.distanceKm, greaterThan(1));
      expect(stats.distanceKm, lessThan(3));
      expect(stats.estimatedDuration, isNotNull);
      expect(stats.lengthBand, CatalogLengthBand.short);
    });

    test('classifies 3h as medium and 6h as long', () {
      expect(
        catalogLengthBandFor(const Duration(hours: 2, minutes: 59)),
        CatalogLengthBand.short,
      );
      expect(
        catalogLengthBandFor(const Duration(hours: 3)),
        CatalogLengthBand.medium,
      );
      expect(
        catalogLengthBandFor(const Duration(hours: 6)),
        CatalogLengthBand.long,
      );
    });
  });

  test('SVG flag assets exist for CZ SK AT DE PL', () {
    for (final code in catalogCountryCodes) {
      final path = 'assets/flags/${code.toLowerCase()}.svg';
      expect(File(path).existsSync(), isTrue, reason: path);
      final svg = File(path).readAsStringSync();
      expect(svg, contains('viewBox="0 0 22 16"'));
      expect(svg.toLowerCase(), isNot(contains('emoji')));
    }
  });

  testWidgets('country flags are 22×16 painted widgets, not emoji', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              CountryFlag(code: 'CZ'),
              CountryFlag(code: 'SK'),
              CountryFlag(code: 'AT'),
              CountryFlag(code: 'DE'),
              CountryFlag(code: 'PL'),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(CountryFlag), findsNWidgets(5));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('🇨🇿'), findsNothing);
    expect(find.text('🇸🇰'), findsNothing);
    expect(tester.getSize(find.byType(CountryFlag).first), const Size(22, 16));
  });

  testWidgets('catalog search filters title and description', (tester) async {
    await _pumpCatalog(tester);
    expect(find.text('Weekend hike'), findsOneWidget);
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsAtLeastNWidgets(1));

    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'unlock',
    );
    await tester.pumpAndSettle();
    expect(find.text('Weekend hike'), findsNothing);
    expect(find.text('Story trail'), findsAtLeastNWidgets(1));
    expect(find.text('Open trail'), findsNothing);
  });

  testWidgets('price and mode chips use AND across groups', (tester) async {
    await _pumpCatalog(tester);

    await tester.tap(find.byKey(const Key('catalog-filter-price-paid')));
    await tester.pumpAndSettle();
    expect(find.text('Story trail'), findsAtLeastNWidgets(1));
    expect(find.text('Open trail'), findsNothing);
    expect(find.text('Weekend hike'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-filter-mode-open')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings('en').catalogNoMatches), findsOneWidget);
    expect(find.text('Story trail'), findsNothing);
  });

  testWidgets('region chip keeps the matching country only', (tester) async {
    await _pumpCatalog(tester);

    await tester.tap(find.byKey(const Key('catalog-filter-region-CZ')));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsNothing);
  });

  testWidgets('empty state and clear filters restore the catalog', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'zzzz-no-match',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-no-matches')), findsOneWidget);
    expect(find.text(AppStrings('en').catalogNoMatches), findsOneWidget);
    expect(find.text(AppStrings('en').catalogNoMatchesHint), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsAtLeastNWidgets(1));
    expect(find.text('Weekend hike'), findsOneWidget);
    expect(find.byKey(const Key('catalog-no-matches')), findsNothing);
  });

  testWidgets('chip row clear-all also resets search', (tester) async {
    await _pumpCatalog(tester);
    await tester.tap(find.byKey(const Key('catalog-filter-price-free')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-clear-filters')), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('catalog-filter-chips')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('catalog-clear-filters')), findsNothing);
  });

  testWidgets('catalog search placeholder is localized', (tester) async {
    await _pumpCatalog(tester, locale: 'cs');
    final field = tester.widget<TextField>(
      find.byKey(const Key('catalog-search-field')),
    );
    expect(field.decoration?.hintText, 'Hledat výzvy');
    expect(find.text('Otevřené'), findsOneWidget);
    expect(find.text('Příběh'), findsWidgets);
    expect(find.text('Zdarma'), findsWidgets);
  });

  testWidgets('region chips expose country-code semantics, not emoji', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(find.byType(CatalogFilterChipRow), findsOneWidget);
    expect(find.byType(CountryFlag), findsNWidgets(10));
    expect(find.textContaining('🇨🇿'), findsNothing);
  });

  testWidgets('search and chips sit below the sage welcome panel', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byKey(const Key('catalog-search-field')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byKey(const Key('catalog-filter-chips')),
      ),
      findsNothing,
    );

    final header = tester.widget<Material>(
      find.byKey(const Key('catalog-welcome-header')),
    );
    expect(header.color, BrandColors.shellFill);
    final headerRect = tester.getRect(
      find.byKey(const Key('catalog-welcome-header')),
    );
    final searchRect = tester.getRect(
      find.byKey(const Key('catalog-search-field')),
    );
    final chipsRect = tester.getRect(
      find.byKey(const Key('catalog-filter-chips')),
    );
    expect(searchRect.top, greaterThan(headerRect.bottom));
    expect(chipsRect.top, greaterThan(searchRect.bottom));
    expect(searchRect.left, CatalogWelcomeHeader.horizontalInset);
    expect(chipsRect.left, CatalogWelcomeHeader.horizontalInset);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('catalog-search-field')))
          .decoration
          ?.fillColor,
      BrandColors.cream,
    );
  });

  testWidgets(
    'discover sections follow chips: hero, length, difficulty, featured, regions',
    (tester) async {
      await _pumpCatalog(tester);
      expect(find.byKey(const Key('catalog-hero-carousel')), findsOneWidget);
      expect(find.byKey(const Key('catalog-hero-open-1')), findsOneWidget);
      expect(find.byKey(const Key('catalog-hero-next')), findsOneWidget);
      expect(find.byKey(const Key('catalog-length-chips')), findsOneWidget);
      expect(
        find.byKey(const Key('catalog-filter-length-short')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('catalog-difficulty-chips')), findsOneWidget);
      expect(
        find.byKey(const Key('catalog-filter-difficulty-easy')),
        findsOneWidget,
      );
      expect(find.text(AppStrings('en').catalogFeatured), findsOneWidget);
      expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
      expect(find.byKey(const Key('catalog-regions')), findsOneWidget);

      final chipsRect = tester.getRect(
        find.byKey(const Key('catalog-filter-chips')),
      );
      final heroRect = tester.getRect(
        find.byKey(const Key('catalog-hero-carousel')),
      );
      final lengthRect = tester.getRect(
        find.byKey(const Key('catalog-length-chips')),
      );
      final difficultyRect = tester.getRect(
        find.byKey(const Key('catalog-difficulty-chips')),
      );
      final featuredRect = tester.getRect(
        find.byKey(const Key('catalog-featured')),
      );
      final regionsRect = tester.getRect(
        find.byKey(const Key('catalog-regions')),
      );
      expect(heroRect.top, greaterThan(chipsRect.bottom));
      expect(heroRect.width / heroRect.height, closeTo(16 / 9, 0.08));
      expect(lengthRect.top, greaterThan(heroRect.bottom - 0.5));
      expect(difficultyRect.top, greaterThan(lengthRect.bottom - 0.5));
      expect(featuredRect.top, greaterThan(difficultyRect.bottom - 0.5));
      expect(regionsRect.top, greaterThan(featuredRect.bottom - 0.5));
    },
  );

  testWidgets('length section is omitted without waypoint route data', (
    tester,
  ) async {
    await _pumpCatalog(
      tester,
      challenges: [
        _challenge(id: 'solo', title: 'No route yet', countryCode: 'CZ'),
      ],
      promos: const [],
    );
    expect(find.text('No route yet'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('catalog-hero-solo')), findsOneWidget);
    expect(find.byKey(const Key('catalog-length-chips')), findsNothing);
    expect(find.byKey(const Key('catalog-filter-length-short')), findsNothing);
    expect(find.byKey(const Key('catalog-difficulty-chips')), findsOneWidget);
    expect(find.text(AppStrings('en').catalogFeatured), findsOneWidget);
  });

  testWidgets('featured title is Czech', (tester) async {
    await _pumpCatalog(tester, locale: 'cs');
    expect(find.text('Vybrané'), findsOneWidget);
    expect(
      find.byKey(const Key('catalog-filter-length-short')),
      findsOneWidget,
    );
    expect(find.text('Krátká'), findsWidgets);
    expect(find.text('Lehká'), findsOneWidget);
    expect(find.text('Běžná'), findsOneWidget);
    expect(find.text('Náročná'), findsOneWidget);
  });

  testWidgets('featured title is German', (tester) async {
    await _pumpCatalog(tester, locale: 'de');
    expect(find.text('Ausgewählt'), findsOneWidget);
    expect(find.text('Kurz'), findsWidgets);
    expect(find.text('Leicht'), findsOneWidget);
    expect(find.text('Anspruchsvoll'), findsOneWidget);
  });

  testWidgets('regions section uses the same country_code filter', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('catalog-regions-CZ')),
      400,
      scrollable: catalogVerticalScrollable(),
    );
    await tester.tap(find.byKey(const Key('catalog-regions-CZ')));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsNothing);
    final filterChip = tester.widget<CatalogFilterChip>(
      find.byKey(const Key('catalog-filter-region-CZ')),
    );
    expect(filterChip.selected, isTrue);
  });

  testWidgets('featured follows the same chips as the rest of the catalog', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-story-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-filter-price-paid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-featured-open-1')), findsNothing);
    expect(find.byKey(const Key('catalog-featured-story-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-hero-open-1')), findsNothing);
    expect(find.byKey(const Key('catalog-hero-story-1')), findsOneWidget);
  });

  testWidgets('catalog hero and cards never show exact hours or km', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(find.textContaining(' h'), findsNothing);
    expect(find.textContaining(' km'), findsNothing);
    expect(find.text('1 h'), findsNothing);
    expect(find.text('2 h'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-featured-open-1')),
        matching: find.text(AppStrings('en').catalogLengthShort),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-featured-open-1')),
        matching: find.text(AppStrings('en').catalogDifficultyEasy),
      ),
      findsNothing,
    );
  });

  testWidgets('length chip filters featured and clear-all restores it', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('catalog-filter-length-long')),
      200,
      scrollable: catalogVerticalScrollable(),
    );
    await tester.tap(find.byKey(const Key('catalog-filter-length-long')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-no-matches')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-open-1')), findsNothing);

    await tester.fling(
      find.byKey(const Key('catalog-filter-chips')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-story-1')), findsOneWidget);
  });

  testWidgets(
    'difficulty chip hides ungraded challenges and clear-all resets',
    (tester) async {
      final easy = _challenge(
        id: 'easy-1',
        title: 'Easy walk',
        difficulty: CatalogDifficulty.easy,
        countryCode: 'CZ',
      );
      final hard = _challenge(
        id: 'hard-1',
        title: 'Hard climb',
        difficulty: CatalogDifficulty.hard,
        countryCode: 'SK',
      );
      final unset = _challenge(
        id: 'unset-1',
        title: 'No grade',
        countryCode: 'AT',
      );
      await _pumpCatalog(
        tester,
        challenges: [easy, hard, unset],
        details: [
          ChallengeDetail(
            challenge: easy,
            waypoints: sampleOpenChallenge().waypoints,
          ),
          ChallengeDetail(
            challenge: hard,
            waypoints: sampleStoryChallenge().waypoints,
          ),
          ChallengeDetail(challenge: unset, waypoints: const []),
        ],
        promos: const [],
      );

      expect(find.byKey(const Key('catalog-featured-easy-1')), findsOneWidget);
      expect(find.byKey(const Key('catalog-featured-hard-1')), findsOneWidget);
      expect(find.byKey(const Key('catalog-featured-unset-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-featured-easy-1')),
          matching: find.text('Easy'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-featured-unset-1')),
          matching: find.text('Easy'),
        ),
        findsNothing,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('catalog-filter-difficulty-easy')),
        200,
        scrollable: catalogVerticalScrollable(),
      );
      await tester.tap(find.byKey(const Key('catalog-filter-difficulty-easy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog-featured-easy-1')), findsOneWidget);
      expect(find.byKey(const Key('catalog-featured-hard-1')), findsNothing);
      expect(find.byKey(const Key('catalog-featured-unset-1')), findsNothing);
      expect(find.text('No grade'), findsNothing);

      await tester.fling(
        find.byKey(const Key('catalog-filter-chips')),
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-clear-filters')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog-featured-hard-1')), findsOneWidget);
      expect(find.byKey(const Key('catalog-featured-unset-1')), findsOneWidget);
    },
  );
}
