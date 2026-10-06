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

import 'helpers/fakes.dart';

Material _chipMaterial(WidgetTester tester, Key key) {
  return tester.widget<Material>(
    find.descendant(of: find.byKey(key), matching: find.byType(Material)),
  );
}

Challenge _challenge({
  required String id,
  required String title,
  String description = '',
  AccessMode mode = AccessMode.open,
  PricingType pricing = PricingType.free,
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
  Size viewSize = const Size(800, 2400),
  List<Challenge>? challenges,
  List<ChallengeDetail>? details,
  List<PromoStripe>? promos,
}) async {
  tester.view.physicalSize = viewSize;
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

Future<void> _revealChip(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

void _expectSameChipStrip(Rect a, Rect b) {
  expect((a.center.dy - b.center.dy).abs(), lessThan(1.5));
}

void _expectFilterRowsStacked(WidgetTester tester) {
  final storyRect = tester.getRect(
    find.byKey(const Key('catalog-filter-mode-story')),
  );
  final openRect = tester.getRect(
    find.byKey(const Key('catalog-filter-mode-open')),
  );
  final regionRect = tester.getRect(
    find.byKey(const Key('catalog-filter-region-chips')),
  );
  final difficultyRect = tester.getRect(
    find.byKey(const Key('catalog-difficulty-chips')),
  );
  final chipsRect = tester.getRect(
    find.byKey(const Key('catalog-filter-chips')),
  );

  expect(chipsRect.height, closeTo(CatalogFilterChipRow.areaHeight, 0.5));
  expect(regionRect.height, closeTo(CatalogFilterChip.height, 0.5));
  _expectSameChipStrip(storyRect, openRect);
  expect(openRect.left, greaterThan(storyRect.right - 0.5));
  expect(regionRect.top, greaterThan(storyRect.bottom - 0.5));
  expect(difficultyRect.top, greaterThan(regionRect.bottom - 0.5));
  expect(chipsRect.top, lessThanOrEqualTo(storyRect.top + 0.5));
  expect(chipsRect.bottom, greaterThanOrEqualTo(difficultyRect.bottom - 0.5));
  expect(find.byKey(const Key('catalog-filter-price-free')), findsNothing);
  expect(find.byKey(const Key('catalog-filter-price-paid')), findsNothing);
  expect(find.byKey(const Key('catalog-length-chips')), findsNothing);
  expect(find.byKey(const Key('catalog-filter-region-CZ')), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('filterCatalogChallenges', () {
    final openBeskydy = _challenge(
      id: 'a',
      title: 'Pálava hike',
      description: 'White rocks',
      region: 'Beskydy',
    );
    final storyMorava = _challenge(
      id: 'b',
      title: 'Tatra story',
      description: 'Unlock in order',
      mode: AccessMode.story,
      pricing: PricingType.paid,
      region: 'Morava',
    );
    final openUnset = _challenge(
      id: 'c',
      title: 'Alpine trail',
      description: 'Vienna woods',
      pricing: PricingType.paid,
    );
    final all = [openBeskydy, storyMorava, openUnset];

    test('empty groups keep every challenge', () {
      expect(filterCatalogChallenges(all, const CatalogFilter()), all);
    });

    test('mode is OR within the group', () {
      final filtered = filterCatalogChallenges(
        all,
        const CatalogFilter(accessModes: {AccessMode.open, AccessMode.story}),
      );
      expect(filtered, all);
    });

    test('single mode chip keeps only that access mode', () {
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(accessModes: {AccessMode.story}),
        ),
        [storyMorava],
      );
    });

    test('region is exact OR and hides null regions', () {
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(regions: {'Beskydy', 'Morava'}),
        ).map((c) => c.id),
        ['a', 'b'],
      );
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(regions: {'Beskydy'}),
        ).map((c) => c.id),
        ['a'],
      );
      expect(
        filterCatalogChallenges([
          openUnset,
        ], const CatalogFilter(regions: {'Beskydy'})),
        isEmpty,
      );
      expect(filterCatalogChallenges([openUnset], const CatalogFilter()), [
        openUnset,
      ]);
    });

    test('region match is the stored string, not a country code', () {
      final hills = _challenge(
        id: 's',
        title: 'Hills',
        region: 'České středohoří',
      );
      expect(
        filterCatalogChallenges([
          hills,
          openBeskydy,
        ], const CatalogFilter(regions: {'Česko'})),
        isEmpty,
      );
      expect(
        filterCatalogChallenges([
          hills,
        ], const CatalogFilter(regions: {'České středohoří'})),
        [hills],
      );
    });

    test('groups combine with AND', () {
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(
            accessModes: {AccessMode.open},
            regions: {'Beskydy'},
          ),
        ),
        [openBeskydy],
      );
    });

    test('AND across groups can yield no matches', () {
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(
            accessModes: {AccessMode.story},
            regions: {'Beskydy'},
          ),
        ),
        isEmpty,
      );
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
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(query: 'order', regions: {'Morava'}),
        ),
        [storyMorava],
      );
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(query: 'woods', regions: {'Beskydy'}),
        ),
        isEmpty,
      );
    });

    test('blank region stays visible only when no region is selected', () {
      final blank = _challenge(id: 'x', title: 'Mystery', region: '   ');
      expect(
        filterCatalogChallenges([
          blank,
        ], const CatalogFilter(regions: {'Beskydy'})),
        isEmpty,
      );
      expect(filterCatalogChallenges([blank], const CatalogFilter()), [blank]);
    });

    test('promos stay visible unless search is active', () {
      expect(const CatalogFilter().showPromos, isTrue);
      expect(const CatalogFilter(regions: {'Beskydy'}).showPromos, isTrue);
      expect(const CatalogFilter(query: '  hike ').showPromos, isFalse);
    });

    test('difficulty chips skip null and exclude unmatched values', () {
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
        ], const CatalogFilter(difficulties: {CatalogDifficulty.easy})),
        [easy, unset],
      );
      expect(
        filterCatalogChallenges(
          [easy, hard, unset],
          const CatalogFilter(
            difficulties: {CatalogDifficulty.easy, CatalogDifficulty.hard},
          ),
        ),
        [easy, hard, unset],
      );
      expect(
        filterCatalogChallenges([
          easy,
          hard,
          unset,
        ], const CatalogFilter(difficulties: {CatalogDifficulty.normal})),
        [unset],
      );
    });

    test('difficulty ANDs with region', () {
      final match = _challenge(
        id: 'm',
        title: 'Match',
        difficulty: CatalogDifficulty.easy,
        region: 'Vysočina',
      );
      expect(
        filterCatalogChallenges(
          [match],
          const CatalogFilter(
            regions: {'Vysočina'},
            difficulties: {CatalogDifficulty.easy},
          ),
        ),
        [match],
      );
      expect(
        filterCatalogChallenges(
          [match],
          const CatalogFilter(
            regions: {'Morava'},
            difficulties: {CatalogDifficulty.easy},
          ),
        ),
        isEmpty,
      );
    });
  });

  group('catalog region options', () {
    test('lists distinct published regions in locale dictionary order', () {
      final challenges = [
        _challenge(id: '1', title: 'a', region: 'Vysočina'),
        _challenge(id: '2', title: 'b', region: 'Beskydy'),
        _challenge(id: '3', title: 'c', region: 'Česko'),
        _challenge(id: '4', title: 'd', region: 'České středohoří'),
        _challenge(id: '5', title: 'e', region: 'Hradec Králové'),
        _challenge(id: '6', title: 'f', region: 'Morava'),
        _challenge(id: '7', title: 'g', region: 'Promo'),
        _challenge(id: '8', title: 'h', region: 'Beskydy'),
        _challenge(id: '9', title: 'i'),
        _challenge(id: '10', title: 'blank', region: '   '),
        Challenge(
          id: 'draft',
          slug: 'draft',
          accessMode: AccessMode.open,
          pricingType: PricingType.free,
          priceCents: 0,
          currency: 'eur',
          status: PublishStatus.draft,
          region: 'Hidden',
          translations: const [
            LocalizedText(locale: 'en', title: 'Hidden', description: ''),
          ],
        ),
        Challenge(
          id: 'promo',
          slug: 'promo',
          accessMode: AccessMode.open,
          pricingType: PricingType.free,
          priceCents: 0,
          currency: 'eur',
          status: PublishStatus.published,
          isPromo: true,
          region: 'Secret range',
          translations: const [
            LocalizedText(locale: 'en', title: 'Secret', description: ''),
          ],
        ),
      ];
      const expected = [
        'Beskydy',
        'České středohoří',
        'Česko',
        'Hradec Králové',
        'Morava',
        'Promo',
        'Vysočina',
      ];
      for (final locale in ['cs', 'en', 'de']) {
        expect(
          catalogRegionOptions(challenges, locale: locale),
          expected,
          reason: locale,
        );
      }
    });
  });

  group('challenge region mapping', () {
    test('challengeFromRow keeps region verbatim and ignores country_code', () {
      final withRegion = challengeFromRow({
        'id': 'c',
        'slug': 'c',
        'access_mode': 'open',
        'pricing_type': 'free',
        'price_cents': 0,
        'currency': 'eur',
        'status': 'published',
        'region': 'České středohoří',
        'country_code': 'sk',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'C', 'description': ''},
        ],
      });
      expect(withRegion.region, 'České středohoří');

      final nullRegion = challengeFromRow({
        'id': 'c2',
        'slug': 'c2',
        'access_mode': 'story',
        'pricing_type': 'paid',
        'price_cents': 1,
        'currency': 'eur',
        'status': 'published',
        'country_code': 'CZ',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'B', 'description': ''},
        ],
      });
      expect(nullRegion.accessMode, AccessMode.story);
      expect(nullRegion.region, isNull);
      expect(nullRegion.difficulty, isNull);

      final graded = challengeFromRow({
        'id': 'c3',
        'slug': 'c3',
        'access_mode': 'open',
        'pricing_type': 'free',
        'price_cents': 0,
        'currency': 'eur',
        'status': 'published',
        'difficulty': 'hard',
        'region': 'Beskydy',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'H', 'description': ''},
        ],
      });
      expect(graded.difficulty, CatalogDifficulty.hard);
      expect(graded.region, 'Beskydy');
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
    const flagCodes = ['CZ', 'SK', 'AT', 'DE', 'PL'];
    for (final code in flagCodes) {
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

  testWidgets('mode chip filters story versus open', (tester) async {
    await _pumpCatalog(tester);

    await tester.tap(find.byKey(const Key('catalog-filter-mode-story')));
    await tester.pumpAndSettle();
    expect(find.text('Story trail'), findsAtLeastNWidgets(1));
    expect(find.text('Open trail'), findsNothing);
    expect(find.text('Weekend hike'), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-filter-mode-open')));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsAtLeastNWidgets(1));
  });

  testWidgets('region chip keeps the matching region only', (tester) async {
    await _pumpCatalog(tester);

    await tester.tap(find.byKey(const Key('catalog-filter-region-Beskydy')));
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
    await tester.tap(find.byKey(const Key('catalog-filter-mode-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-clear-filters')), findsOneWidget);
    await tester.fling(
      find.byKey(const Key('catalog-filter-access-chips')),
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
    expect(find.text('Zdarma'), findsNothing);
    expect(find.text('Placené'), findsNothing);
  });

  testWidgets('region chips are catalog region labels, not country flags', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(find.byType(CatalogFilterChipRow), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CatalogFilterChipRow),
        matching: find.byType(CountryFlag),
      ),
      findsNothing,
    );
    expect(find.text('Beskydy'), findsOneWidget);
    expect(find.text('Morava'), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-region-CZ')), findsNothing);
    expect(find.textContaining('🇨🇿'), findsNothing);
  });

  testWidgets('search and chips sit inside the sage welcome panel', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byKey(const Key('catalog-search-field')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byKey(const Key('catalog-filter-chips')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byKey(const Key('catalog-filter-access-chips')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byKey(const Key('catalog-filter-region-chips')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byKey(const Key('catalog-difficulty-chips')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-results')),
        matching: find.byKey(const Key('catalog-search-field')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-results')),
        matching: find.byKey(const Key('catalog-filter-chips')),
      ),
      findsNothing,
    );

    final header = tester.widget<Material>(
      find.byKey(const Key('catalog-welcome-header')),
    );
    expect(header.color, BrandColors.shellFill);
    expect(BrandColors.shellFill, const Color(0xFF7D8B6A));
    final headerRect = tester.getRect(
      find.byKey(const Key('catalog-welcome-header')),
    );
    final searchRect = tester.getRect(
      find.byKey(const Key('catalog-search-field')),
    );
    final chipsRect = tester.getRect(
      find.byKey(const Key('catalog-filter-chips')),
    );
    expect(searchRect.top, greaterThan(headerRect.top));
    expect(searchRect.bottom, lessThan(headerRect.bottom));
    expect(chipsRect.top, greaterThan(searchRect.bottom));
    expect(chipsRect.bottom, lessThanOrEqualTo(headerRect.bottom + 0.5));
    expect(chipsRect.height, closeTo(CatalogFilterChipRow.areaHeight, 0.5));
    _expectFilterRowsStacked(tester);
    expect(
      searchRect.left,
      headerRect.left + CatalogWelcomeHeader.innerHorizontalPadding,
    );
    expect(
      chipsRect.left,
      headerRect.left + CatalogWelcomeHeader.innerHorizontalPadding,
    );
    expect(headerRect.left, CatalogWelcomeHeader.horizontalInset);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('catalog-search-field')))
          .decoration
          ?.fillColor,
      BrandColors.creamFill,
    );

    final unselected = _chipMaterial(
      tester,
      const Key('catalog-filter-mode-story'),
    );
    expect(unselected.color, BrandColors.creamPill);
    expect((unselected.shape as RoundedRectangleBorder).side, BorderSide.none);
    final unselectedLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('catalog-filter-mode-story')),
        matching: find.byType(Text),
      ),
    );
    expect(unselectedLabel.style?.color, BrandColors.cream);
    expect(unselectedLabel.style?.fontWeight, FontWeight.w600);
    expect(unselectedLabel.style?.fontSize, CatalogFilterChip.fontSize);

    await tester.tap(find.byKey(const Key('catalog-filter-mode-story')));
    await tester.pumpAndSettle();
    final selected = _chipMaterial(
      tester,
      const Key('catalog-filter-mode-story'),
    );
    expect(selected.color, BrandColors.cream);
    expect((selected.shape as RoundedRectangleBorder).side, BorderSide.none);
    final selectedLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('catalog-filter-mode-story')),
        matching: find.byType(Text),
      ),
    );
    expect(selectedLabel.style?.color, BrandColors.forest);
    expect(selectedLabel.style?.fontWeight, FontWeight.w600);

    final clear = tester.widget<TextButton>(
      find.byKey(const Key('catalog-clear-filters')),
    );
    expect(clear.style?.foregroundColor?.resolve({}), BrandColors.cream);
    final clearLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('catalog-clear-filters')),
        matching: find.byType(Text),
      ),
    );
    expect(clearLabel.style?.color, BrandColors.cream);
    expect(clearLabel.style?.decoration, TextDecoration.underline);
  });

  testWidgets('discover sections follow chips: hero, featured, promo', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(find.byKey(const Key('catalog-hero-carousel')), findsOneWidget);
    expect(find.byKey(const Key('catalog-hero-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-hero-next')), findsOneWidget);
    expect(
      find.byKey(const Key('catalog-filter-region-chips')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('catalog-filter-region-Beskydy')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('catalog-difficulty-chips')), findsOneWidget);
    expect(
      find.byKey(const Key('catalog-filter-difficulty-easy')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('catalog-length-chips')), findsNothing);
    expect(find.text(AppStrings('en').catalogFeatured), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
    expect(find.byKey(const Key('promo-widget')), findsOneWidget);
    expect(find.byKey(const Key('catalog-regions')), findsNothing);

    final chipsRect = tester.getRect(
      find.byKey(const Key('catalog-filter-chips')),
    );
    final difficultyRect = tester.getRect(
      find.byKey(const Key('catalog-difficulty-chips')),
    );
    final heroRect = tester.getRect(
      find.byKey(const Key('catalog-hero-carousel')),
    );
    final featuredRect = tester.getRect(
      find.byKey(const Key('catalog-featured')),
    );
    final promoRect = tester.getRect(find.byKey(const Key('promo-widget')));
    final list = tester.widget<ListView>(
      find.byKey(const Key('catalog-results')),
    );
    _expectFilterRowsStacked(tester);
    expect(heroRect.top, greaterThan(chipsRect.bottom));
    expect(heroRect.top, greaterThan(difficultyRect.bottom));
    expect(heroRect.width / heroRect.height, closeTo(16 / 9, 0.08));
    expect(featuredRect.top, greaterThan(heroRect.bottom - 0.5));
    expect(promoRect.top, greaterThan(featuredRect.bottom - 0.5));
    expect(promoRect.top - featuredRect.bottom, closeTo(16, 1));
    expect(list.padding, const EdgeInsets.fromLTRB(16, 8, 16, 16));
    expect(
      tester
          .widget<Material>(find.byKey(const Key('promo-surface-promo-1')))
          .color,
      BrandColors.forest,
    );
    expect(
      tester
          .widget<Material>(find.byKey(const Key('promo-surface-promo-1')))
          .color,
      isNot(BrandColors.shellFill),
    );
  });

  testWidgets('region chips come from loaded challenges without waypoints', (
    tester,
  ) async {
    await _pumpCatalog(
      tester,
      challenges: [
        _challenge(id: 'solo', title: 'No route yet', region: 'Vysočina'),
      ],
      promos: const [],
    );
    expect(find.text('No route yet'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('catalog-hero-solo')), findsOneWidget);
    expect(
      find.byKey(const Key('catalog-filter-region-Vysočina')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('catalog-filter-region-Beskydy')),
      findsNothing,
    );
    expect(find.byKey(const Key('catalog-difficulty-chips')), findsOneWidget);
    expect(find.byKey(const Key('catalog-length-chips')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-hero-solo')),
        matching: find.text(AppStrings('en').catalogLengthShort),
      ),
      findsNothing,
    );
    expect(find.text(AppStrings('en').catalogFeatured), findsOneWidget);
  });

  testWidgets(
    'region and difficulty sit under access in the welcome panel, not the results list',
    (tester) async {
      await _pumpCatalog(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-welcome-header')),
          matching: find.byKey(const Key('catalog-filter-region-chips')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-welcome-header')),
          matching: find.byKey(const Key('catalog-difficulty-chips')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CatalogFilterChipRow),
          matching: find.byKey(const Key('catalog-filter-region-Beskydy')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-filter-chips')),
          matching: find.byKey(const Key('catalog-difficulty-chips')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-filter-access-chips')),
          matching: find.byKey(const Key('catalog-filter-region-Beskydy')),
        ),
        findsNothing,
      );
      _expectFilterRowsStacked(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-results')),
          matching: find.byKey(const Key('catalog-filter-region-chips')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-results')),
          matching: find.byKey(const Key('catalog-difficulty-chips')),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('narrow panel keeps region and difficulty under access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _wrap(const CatalogScreen(), _services(), locale: 'en'),
    );
    await tester.pumpAndSettle();

    final chipsRect = tester.getRect(
      find.byKey(const Key('catalog-filter-chips')),
    );
    final heroRect = tester.getRect(
      find.byKey(const Key('catalog-hero-carousel')),
    );
    _expectFilterRowsStacked(tester);
    expect(heroRect.top, greaterThan(chipsRect.bottom));
  });

  testWidgets(
    'welcome panel stays within a third of a typical phone viewport',
    (tester) async {
      const viewport = Size(
        390,
        CatalogWelcomeHeader.typicalPhoneViewportHeight,
      );
      await _pumpCatalog(tester, viewSize: viewport);

      final headerRect = tester.getRect(
        find.byKey(const Key('catalog-welcome-header')),
      );
      final welcomeSize = tester.getSize(find.byType(CatalogWelcomeHeader));
      final chipsRect = tester.getRect(
        find.byKey(const Key('catalog-filter-chips')),
      );
      final maxHeight =
          viewport.height * CatalogWelcomeHeader.maxViewportFraction;

      expect(headerRect.height, lessThanOrEqualTo(maxHeight));
      expect(welcomeSize.height, lessThanOrEqualTo(maxHeight));
      expect(chipsRect.height, closeTo(CatalogFilterChipRow.areaHeight, 0.5));
      expect(
        tester
            .getSize(find.byKey(const Key('catalog-filter-mode-story')))
            .height,
        closeTo(CatalogFilterChip.height, 0.5),
      );
      expect(
        tester
            .getSize(find.byKey(const Key('catalog-filter-region-chips')))
            .height,
        closeTo(CatalogFilterChip.height, 0.5),
      );
      _expectFilterRowsStacked(tester);
    },
  );

  testWidgets('featured title is Czech', (tester) async {
    await _pumpCatalog(tester, locale: 'cs');
    expect(find.text('Vybrané'), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-length-short')), findsNothing);
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

  testWidgets('region chip filters featured by the stored region', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    await tester.tap(find.byKey(const Key('catalog-filter-region-Beskydy')));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsNothing);
    final filterChip = tester.widget<CatalogFilterChip>(
      find.byKey(const Key('catalog-filter-region-Beskydy')),
    );
    expect(filterChip.selected, isTrue);
    expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-story-1')), findsNothing);
  });

  testWidgets('featured follows the same chips as the rest of the catalog', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-story-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-filter-mode-story')));
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
    expect(find.text('1 h'), findsNothing);
    expect(find.text('2 h'), findsNothing);
    expect(find.textContaining(' km'), findsNothing);
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
        matching: find.textContaining(AppStrings('en').catalogDifficultyEasy),
      ),
      findsNothing,
    );
  });

  testWidgets('null region stays listed until a region chip is selected', (
    tester,
  ) async {
    final unset = _challenge(id: 'unset-region', title: 'No region');
    final named = _challenge(
      id: 'named',
      title: 'Named range',
      region: 'Promo',
    );
    await _pumpCatalog(
      tester,
      challenges: [unset, named],
      details: [
        ChallengeDetail(challenge: unset, waypoints: const []),
        ChallengeDetail(challenge: named, waypoints: const []),
      ],
      promos: const [],
    );
    expect(find.text('No region'), findsAtLeastNWidgets(1));
    expect(find.text('Named range'), findsAtLeastNWidgets(1));
    expect(
      find.byKey(const Key('catalog-filter-region-Promo')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('catalog-filter-region-Promo')));
    await tester.pumpAndSettle();
    expect(find.text('Named range'), findsAtLeastNWidgets(1));
    expect(find.text('No region'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('No region'), findsAtLeastNWidgets(1));
    expect(find.text('Named range'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'difficulty chip keeps ungraded challenges and clear-all resets',
    (tester) async {
      final easy = _challenge(
        id: 'easy-1',
        title: 'Gentle walk',
        difficulty: CatalogDifficulty.easy,
        region: 'Beskydy',
      );
      final hard = _challenge(
        id: 'hard-1',
        title: 'Hard climb',
        difficulty: CatalogDifficulty.hard,
        region: 'Morava',
      );
      final unset = _challenge(
        id: 'unset-1',
        title: 'No grade',
        region: 'Vysočina',
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
          matching: find.textContaining('Short · Easy'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('catalog-featured-unset-1')),
          matching: find.textContaining('Easy'),
        ),
        findsNothing,
      );

      await _revealChip(tester, const Key('catalog-filter-difficulty-easy'));
      await tester.tap(find.byKey(const Key('catalog-filter-difficulty-easy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog-featured-easy-1')), findsOneWidget);
      expect(find.byKey(const Key('catalog-featured-hard-1')), findsNothing);
      expect(find.byKey(const Key('catalog-featured-unset-1')), findsOneWidget);
      expect(find.text('No grade'), findsAtLeastNWidgets(1));

      await tester.fling(
        find.byKey(const Key('catalog-filter-access-chips')),
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
