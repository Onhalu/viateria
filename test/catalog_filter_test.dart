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
  String? countryCode,
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

void _expectAccessAndDifficultyAboveCountries(WidgetTester tester) {
  final storyRect = tester.getRect(
    find.byKey(const Key('catalog-filter-mode-story')),
  );
  final openRect = tester.getRect(
    find.byKey(const Key('catalog-filter-mode-open')),
  );
  final difficultyRect = tester.getRect(
    find.byKey(const Key('catalog-difficulty-chips')),
  );
  final countryRect = tester.getRect(
    find.byKey(const Key('catalog-filter-country-chips')),
  );
  final flagRect = tester.getRect(
    find.byKey(const Key('catalog-filter-region-CZ')),
  );
  final chipsRect = tester.getRect(
    find.byKey(const Key('catalog-filter-chips')),
  );

  expect(chipsRect.height, closeTo(CatalogFilterChipRow.areaHeight, 0.5));
  expect(countryRect.height, closeTo(CatalogFilterChip.height, 0.5));
  _expectSameChipStrip(storyRect, openRect);
  _expectSameChipStrip(openRect, difficultyRect);
  expect(difficultyRect.left, greaterThan(openRect.right - 0.5));
  expect(countryRect.top, greaterThan(storyRect.bottom - 0.5));
  expect(countryRect.top, greaterThan(difficultyRect.bottom - 0.5));
  _expectSameChipStrip(countryRect, flagRect);
  expect(chipsRect.top, lessThanOrEqualTo(storyRect.top + 0.5));
  expect(chipsRect.bottom, greaterThanOrEqualTo(flagRect.bottom - 0.5));
  expect(find.byKey(const Key('catalog-filter-price-free')), findsNothing);
  expect(find.byKey(const Key('catalog-filter-price-paid')), findsNothing);
  expect(find.byKey(const Key('catalog-length-chips')), findsNothing);
  expect(
    find.descendant(
      of: find.byKey(const Key('catalog-filter-country-chips')),
      matching: find.byType(CountryFlag),
    ),
    findsNWidgets(catalogCountryCodes.length),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('filterCatalogChallenges', () {
    final openCz = _challenge(
      id: 'a',
      title: 'Pálava hike',
      description: 'White rocks',
      region: 'Beskydy',
      countryCode: 'CZ',
    );
    final storySk = _challenge(
      id: 'b',
      title: 'Tatra story',
      description: 'Unlock in order',
      mode: AccessMode.story,
      pricing: PricingType.paid,
      region: 'Morava',
      countryCode: 'SK',
    );
    final openUnset = _challenge(
      id: 'c',
      title: 'Alpine trail',
      description: 'Vienna woods',
      pricing: PricingType.paid,
      region: 'Alps',
    );
    final all = [openCz, storySk, openUnset];

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
        [storySk],
      );
    });

    test('country is exact OR and hides a null country_code', () {
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(countryCodes: {'CZ', 'SK'}),
        ).map((c) => c.id),
        ['a', 'b'],
      );
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(countryCodes: {'CZ'}),
        ).map((c) => c.id),
        ['a'],
      );
      expect(
        filterCatalogChallenges([
          openUnset,
        ], const CatalogFilter(countryCodes: {'CZ'})),
        isEmpty,
      );
      expect(filterCatalogChallenges([openUnset], const CatalogFilter()), [
        openUnset,
      ]);
    });

    test('comma-separated country_code matches each listed code', () {
      final palava = _challenge(
        id: 'toulky-palavou',
        title: 'Toulky Pálavou',
        region: 'Morava',
        countryCode: 'CZ,AT',
      );
      final spaced = _challenge(
        id: 'spaced',
        title: 'Spaced codes',
        region: 'Tatry',
        countryCode: 'cz, at, pl',
      );
      final single = _challenge(
        id: 'single',
        title: 'Single CZ',
        countryCode: 'CZ',
      );
      final inferred = _challenge(
        id: 'inferred',
        title: 'Inferred CZ',
        region: 'Beskydy',
      );
      final rows = [palava, spaced, single, inferred];

      expect(
        filterCatalogChallenges(
          rows,
          const CatalogFilter(countryCodes: {'CZ'}),
        ).map((c) => c.id),
        ['toulky-palavou', 'spaced', 'single', 'inferred'],
      );
      expect(
        filterCatalogChallenges(
          rows,
          const CatalogFilter(countryCodes: {'AT'}),
        ).map((c) => c.id),
        ['toulky-palavou', 'spaced'],
      );
      expect(
        filterCatalogChallenges(
          rows,
          const CatalogFilter(countryCodes: {'SK'}),
        ),
        isEmpty,
      );
      expect(
        filterCatalogChallenges([
          inferred,
        ], const CatalogFilter(countryCodes: {'AT'})),
        isEmpty,
      );
    });

    test('country chip matches resolved country, and stored code wins', () {
      final hills = _challenge(id: 's', title: 'Hills', region: 'Česko');
      final labeledSk = _challenge(
        id: 't',
        title: 'Labeled SK',
        region: 'Česko',
        countryCode: 'SK',
      );
      final unknown = _challenge(id: 'u', title: 'Alps', region: 'Alps');
      expect(
        filterCatalogChallenges([
          hills,
          labeledSk,
          unknown,
          openCz,
        ], const CatalogFilter(countryCodes: {'CZ'})).map((c) => c.id),
        ['s', 'a'],
      );
      expect(
        filterCatalogChallenges([
          labeledSk,
        ], const CatalogFilter(countryCodes: {'SK'})).map((c) => c.id),
        ['t'],
      );
      expect(
        filterCatalogChallenges([
          unknown,
        ], const CatalogFilter(countryCodes: {'CZ'})),
        isEmpty,
      );
    });

    test('groups combine with AND', () {
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(
            accessModes: {AccessMode.open},
            countryCodes: {'CZ'},
          ),
        ),
        [openCz],
      );
    });

    test('AND across groups can yield no matches', () {
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(
            accessModes: {AccessMode.story},
            countryCodes: {'CZ'},
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
          const CatalogFilter(query: 'order', countryCodes: {'SK'}),
        ),
        [storySk],
      );
      expect(
        filterCatalogChallenges(
          all,
          const CatalogFilter(query: 'woods', countryCodes: {'CZ'}),
        ),
        isEmpty,
      );
    });

    test(
      'null country_code stays visible only when no country is selected',
      () {
        final blank = _challenge(id: 'x', title: 'Mystery', region: 'Alps');
        expect(
          filterCatalogChallenges([
            blank,
          ], const CatalogFilter(countryCodes: {'CZ'})),
          isEmpty,
        );
        expect(filterCatalogChallenges([blank], const CatalogFilter()), [
          blank,
        ]);
      },
    );

    test('promos stay visible unless search is active', () {
      expect(const CatalogFilter().showPromos, isTrue);
      expect(const CatalogFilter(countryCodes: {'CZ'}).showPromos, isTrue);
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

    test('difficulty ANDs with country', () {
      final match = _challenge(
        id: 'm',
        title: 'Match',
        difficulty: CatalogDifficulty.easy,
        region: 'Vysočina',
        countryCode: 'CZ',
      );
      expect(
        filterCatalogChallenges(
          [match],
          const CatalogFilter(
            countryCodes: {'CZ'},
            difficulties: {CatalogDifficulty.easy},
          ),
        ),
        [match],
      );
      expect(
        filterCatalogChallenges(
          [match],
          const CatalogFilter(
            countryCodes: {'SK'},
            difficulties: {CatalogDifficulty.easy},
          ),
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
      expect(parseCountryCode(null), isNull);
      expect(parseCountryCode('CZ,AT'), isNull);
    });

    test('parses a comma-separated country_code list', () {
      expect(parseCountryCodes('CZ,AT'), ['CZ', 'AT']);
      expect(parseCountryCodes(' cz, at , pl '), ['CZ', 'AT', 'PL']);
      expect(parseCountryCodes('CZ,CZ,AT'), ['CZ', 'AT']);
      expect(parseCountryCodes('CZ,US'), ['CZ']);
      expect(parseCountryCodes(''), isEmpty);
      expect(parseCountryCodes(null), isEmpty);
      expect(resolveCountryCodes(countryCode: 'CZ,AT', region: 'Tatry'), [
        'CZ',
        'AT',
      ]);
      expect(resolveCountryCodes(countryCode: null, region: 'Morava'), ['CZ']);
      expect(resolveCountryCodes(countryCode: '  ', region: 'Beskydy'), ['CZ']);
      expect(resolveCountryCode(countryCode: 'cz, at'), 'CZ,AT');
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
      expect(inferCountryCodeFromRegion('Tatry'), 'SK');
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
        'region': 'České středohoří',
        'country_code': 'sk',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'C', 'description': ''},
        ],
      });
      expect(withCode.region, 'České středohoří');
      expect(withCode.countryCode, 'SK');

      final palava = challengeFromRow({
        'id': 'toulky-palavou',
        'slug': 'toulky-palavou',
        'access_mode': 'open',
        'pricing_type': 'free',
        'price_cents': 0,
        'currency': 'eur',
        'status': 'published',
        'region': 'Morava',
        'country_code': 'CZ,AT',
        'challenge_i18n': [
          {'locale': 'cs', 'title': 'Toulky Pálavou', 'description': ''},
        ],
      });
      expect(palava.countryCode, 'CZ,AT');
      expect(
        filterCatalogChallenges([
          palava,
        ], const CatalogFilter(countryCodes: {'CZ'})),
        [palava],
      );
      expect(
        filterCatalogChallenges([
          palava,
        ], const CatalogFilter(countryCodes: {'AT'})),
        [palava],
      );
      expect(
        filterCatalogChallenges([
          palava,
        ], const CatalogFilter(countryCodes: {'SK'})),
        isEmpty,
      );

      final regionOnly = challengeFromRow({
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
      expect(regionOnly.accessMode, AccessMode.story);
      expect(regionOnly.region, 'Beskydy');
      expect(regionOnly.countryCode, 'CZ');
      expect(regionOnly.difficulty, isNull);

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
      expect(graded.countryCode, 'CZ');
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

  testWidgets('country flag keeps the matching country only', (tester) async {
    await _pumpCatalog(tester);

    await tester.tap(find.byKey(const Key('catalog-filter-region-CZ')));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsNothing);
    expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-story-1')), findsNothing);
    expect(find.byKey(const Key('catalog-country-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-story-1')), findsNothing);
    expect(
      tester
          .widget<CatalogFilterChip>(
            find.byKey(const Key('catalog-filter-region-CZ')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<CatalogFilterChip>(
            find.byKey(const Key('catalog-regions-CZ')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Výzvy ve vybrané zemi'), findsNothing);
    expect(find.text('Challenges in the selected country'), findsNothing);
    final promoRect = tester.getRect(find.byKey(const Key('promo-widget')));
    final flagsRect = tester.getRect(find.byKey(const Key('catalog-regions')));
    final resultsRect = tester.getRect(
      find.byKey(const Key('catalog-country-results')),
    );
    expect(flagsRect.top, greaterThan(promoRect.bottom - 0.5));
    expect(resultsRect.top - flagsRect.bottom, closeTo(16, 1));

    await tester.tap(find.byKey(const Key('catalog-filter-region-CZ')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-regions-SK')));
    await tester.pumpAndSettle();
    expect(find.text('Story trail'), findsAtLeastNWidgets(1));
    expect(find.text('Open trail'), findsNothing);
    expect(find.byKey(const Key('catalog-country-story-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-open-1')), findsNothing);
    expect(
      tester
          .widget<CatalogFilterChip>(
            find.byKey(const Key('catalog-filter-region-SK')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<CatalogFilterChip>(
            find.byKey(const Key('catalog-regions-SK')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<CatalogFilterChip>(
            find.byKey(const Key('catalog-regions-CZ')),
          )
          .selected,
      isFalse,
    );
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

  testWidgets('country chips are flags, not region names or emoji', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(find.byType(CatalogFilterChipRow), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CatalogFilterChipRow),
        matching: find.byType(CountryFlag),
      ),
      findsNWidgets(catalogCountryCodes.length),
    );
    expect(find.text('Beskydy'), findsNothing);
    expect(find.text('Morava'), findsNothing);
    expect(find.byKey(const Key('catalog-filter-region-CZ')), findsOneWidget);
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
        matching: find.byKey(const Key('catalog-filter-country-chips')),
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
    _expectAccessAndDifficultyAboveCountries(tester);
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
      find.byKey(const Key('catalog-filter-country-chips')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('catalog-filter-region-CZ')), findsOneWidget);
    expect(find.byKey(const Key('catalog-difficulty-chips')), findsOneWidget);
    expect(
      find.byKey(const Key('catalog-filter-difficulty-easy')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('catalog-length-chips')), findsNothing);
    expect(find.text(AppStrings('en').catalogFeatured), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
    expect(find.byKey(const Key('promo-widget')), findsOneWidget);
    expect(find.byKey(const Key('catalog-regions')), findsOneWidget);
    expect(find.byKey(const Key('catalog-regions-CZ')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-results')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-story-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-challenges')), findsNothing);
    expect(find.text('Výzvy ve vybrané zemi'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-regions')),
        matching: find.byType(CountryFlag),
      ),
      findsNWidgets(catalogCountryCodes.length),
    );

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
    _expectAccessAndDifficultyAboveCountries(tester);
    expect(heroRect.top, greaterThan(chipsRect.bottom));
    expect(heroRect.top, greaterThan(difficultyRect.bottom));
    expect(heroRect.width / heroRect.height, closeTo(16 / 9, 0.08));
    expect(featuredRect.top, greaterThan(heroRect.bottom - 0.5));
    expect(promoRect.top, greaterThan(featuredRect.bottom - 0.5));
    expect(promoRect.top - featuredRect.bottom, closeTo(16, 1));
    final countryRect = tester.getRect(
      find.byKey(const Key('catalog-regions')),
    );
    expect(countryRect.top, greaterThan(promoRect.bottom - 0.5));
    expect(countryRect.top - promoRect.bottom, closeTo(16, 1));
    final resultsRect = tester.getRect(
      find.byKey(const Key('catalog-country-results')),
    );
    expect(resultsRect.top - countryRect.bottom, closeTo(16, 1));
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

  testWidgets('country flags stay in the filter without waypoint data', (
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
    expect(find.byKey(const Key('catalog-filter-region-CZ')), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-region-PL')), findsOneWidget);
    expect(
      find.byKey(const Key('catalog-filter-region-Vysočina')),
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

  testWidgets('difficulty sits beside access, and country flags sit below', (
    tester,
  ) async {
    await _pumpCatalog(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-welcome-header')),
        matching: find.byKey(const Key('catalog-filter-country-chips')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-filter-access-chips')),
        matching: find.byKey(const Key('catalog-difficulty-chips')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CatalogFilterChipRow),
        matching: find.byKey(const Key('catalog-filter-region-CZ')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-filter-access-chips')),
        matching: find.byKey(const Key('catalog-filter-region-CZ')),
      ),
      findsNothing,
    );
    _expectAccessAndDifficultyAboveCountries(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('catalog-results')),
        matching: find.byKey(const Key('catalog-filter-country-chips')),
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
  });

  testWidgets('narrow panel keeps countries under access and difficulty', (
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
    _expectAccessAndDifficultyAboveCountries(tester);
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
            .getSize(find.byKey(const Key('catalog-filter-country-chips')))
            .height,
        closeTo(CatalogFilterChip.height, 0.5),
      );
      _expectAccessAndDifficultyAboveCountries(tester);
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

  testWidgets('country flag filters the main list and clear restores it', (
    tester,
  ) async {
    Challenge row({
      required String id,
      required String title,
      String? region,
      String? countryCode,
      String accessMode = 'open',
      String? difficulty,
    }) {
      return challengeFromRow({
        'id': id,
        'slug': id,
        'access_mode': accessMode,
        'pricing_type': 'free',
        'price_cents': 0,
        'currency': 'eur',
        'status': 'published',
        'region': region,
        'country_code': countryCode,
        'difficulty': difficulty,
        'challenge_i18n': [
          {'locale': 'en', 'title': title, 'description': ''},
        ],
      });
    }

    final beskydy = row(
      id: 'beskydy',
      title: 'Beskydy ridge',
      region: 'Beskydy',
      accessMode: 'story',
      difficulty: 'easy',
    );
    final tatry = row(
      id: 'tatry',
      title: 'Tatra path',
      region: 'Tatry',
      difficulty: 'hard',
    );
    final alps = row(id: 'alps', title: 'Alpine unknown', region: 'Alps');
    expect(beskydy.countryCode, 'CZ');
    expect(tatry.countryCode, 'SK');
    expect(alps.countryCode, isNull);

    await _pumpCatalog(
      tester,
      challenges: [beskydy, tatry, alps],
      details: [
        for (final challenge in [beskydy, tatry, alps])
          ChallengeDetail(challenge: challenge, waypoints: const []),
      ],
      promos: const [],
    );

    expect(find.text('Beskydy ridge'), findsAtLeastNWidgets(1));
    expect(find.text('Tatra path'), findsAtLeastNWidgets(1));
    expect(find.text('Alpine unknown'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('catalog-hero-beskydy')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-tatry')), findsOneWidget);
    expect(find.byKey(const Key('catalog-regions')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-results')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-beskydy')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-tatry')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-alps')), findsOneWidget);
    expect(find.text('Výzvy ve vybrané zemi'), findsNothing);
    final featuredBottom = tester
        .getRect(find.byKey(const Key('catalog-featured')))
        .bottom;
    final countryTop = tester
        .getRect(find.byKey(const Key('catalog-regions')))
        .top;
    expect(countryTop - featuredBottom, closeTo(16, 1));

    await tester.tap(find.byKey(const Key('catalog-regions-CZ')));
    await tester.pumpAndSettle();
    expect(find.text('Beskydy ridge'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('catalog-hero-beskydy')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-beskydy')), findsOneWidget);
    expect(
      tester
          .widget<CatalogFilterChip>(
            find.byKey(const Key('catalog-filter-region-CZ')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Tatra path'), findsNothing);
    expect(find.text('Alpine unknown'), findsNothing);
    expect(find.byKey(const Key('catalog-hero-tatry')), findsNothing);
    expect(find.byKey(const Key('catalog-featured-alps')), findsNothing);
    expect(find.byKey(const Key('catalog-country-beskydy')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-tatry')), findsNothing);
    expect(find.byKey(const Key('catalog-country-alps')), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-filter-mode-story')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-featured-beskydy')), findsOneWidget);

    await _revealChip(tester, const Key('catalog-filter-difficulty-hard'));
    await tester.tap(find.byKey(const Key('catalog-filter-difficulty-hard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-no-matches')), findsOneWidget);
    expect(find.text('Beskydy ridge'), findsNothing);
    expect(find.byKey(const Key('catalog-regions')), findsNothing);
    expect(find.byKey(const Key('catalog-country-results')), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-filter-difficulty-hard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-featured-beskydy')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-filter-region-CZ')));
    await tester.pumpAndSettle();
    expect(find.text('Beskydy ridge'), findsAtLeastNWidgets(1));
    expect(find.text('Tatra path'), findsNothing);
    expect(find.text('Alpine unknown'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-filter-mode-story')));
    await tester.pumpAndSettle();
    expect(find.text('Tatra path'), findsAtLeastNWidgets(1));
    expect(find.text('Alpine unknown'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('catalog-hero-beskydy')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-tatry')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-alps')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-beskydy')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-tatry')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-alps')), findsOneWidget);
    expect(
      tester
          .widget<CatalogFilterChip>(
            find.byKey(const Key('catalog-regions-CZ')),
          )
          .selected,
      isFalse,
    );
  });

  testWidgets('country flag filters featured by country_code', (tester) async {
    await _pumpCatalog(tester);
    await tester.tap(find.byKey(const Key('catalog-filter-region-CZ')));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.text('Story trail'), findsNothing);
    final filterChip = tester.widget<CatalogFilterChip>(
      find.byKey(const Key('catalog-filter-region-CZ')),
    );
    expect(filterChip.selected, isTrue);
    expect(find.byKey(const Key('catalog-featured-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured-story-1')), findsNothing);
    expect(find.byKey(const Key('catalog-country-open-1')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-story-1')), findsNothing);
    expect(
      tester
          .widget<CatalogFilterChip>(
            find.byKey(const Key('catalog-regions-CZ')),
          )
          .selected,
      isTrue,
    );
    final promoBottom = tester
        .getRect(find.byKey(const Key('promo-widget')))
        .bottom;
    final countryTop = tester
        .getRect(find.byKey(const Key('catalog-regions')))
        .top;
    expect(countryTop - promoBottom, closeTo(16, 1));
    final resultsTop = tester
        .getRect(find.byKey(const Key('catalog-country-results')))
        .top;
    expect(
      resultsTop -
          tester.getRect(find.byKey(const Key('catalog-regions'))).bottom,
      closeTo(16, 1),
    );
  });

  testWidgets('CZ flag keeps resolved CZ rows in the list under the flags', (
    tester,
  ) async {
    Challenge row({
      required String id,
      required String title,
      String? region,
      String? countryCode,
    }) {
      return challengeFromRow({
        'id': id,
        'slug': id,
        'access_mode': 'open',
        'pricing_type': 'free',
        'price_cents': 0,
        'currency': 'eur',
        'status': 'published',
        'region': region,
        'country_code': countryCode,
        'challenge_i18n': [
          {'locale': 'en', 'title': title, 'description': ''},
        ],
      });
    }

    final stored = row(id: 'stored', title: 'Stored CZ', countryCode: 'CZ');
    final inferred = row(
      id: 'inferred',
      title: 'Inferred CZ',
      region: 'Morava',
    );
    final slovak = row(
      id: 'slovak',
      title: 'Stored SK',
      region: 'Beskydy',
      countryCode: 'SK',
    );
    await _pumpCatalog(
      tester,
      challenges: [stored, inferred, slovak],
      details: [
        for (final challenge in [stored, inferred, slovak])
          ChallengeDetail(challenge: challenge, waypoints: const []),
      ],
      promos: const [],
    );

    await tester.tap(find.byKey(const Key('catalog-filter-region-CZ')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-country-stored')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-inferred')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-slovak')), findsNothing);
    expect(find.text('Stored SK'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-regions-CZ')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-country-stored')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-inferred')), findsOneWidget);
    expect(find.byKey(const Key('catalog-country-slovak')), findsOneWidget);
  });

  testWidgets('CZ,AT challenge stays under both the CZ and AT flags', (
    tester,
  ) async {
    Challenge row({
      required String id,
      required String title,
      String? region,
      String? countryCode,
    }) {
      return challengeFromRow({
        'id': id,
        'slug': id,
        'access_mode': 'open',
        'pricing_type': 'free',
        'price_cents': 0,
        'currency': 'eur',
        'status': 'published',
        'region': region,
        'country_code': countryCode,
        'challenge_i18n': [
          {'locale': 'en', 'title': title, 'description': ''},
        ],
      });
    }

    final palava = row(
      id: 'toulky-palavou',
      title: 'Toulky Palavou',
      region: 'Morava',
      countryCode: 'CZ,AT',
    );
    final tatry = row(
      id: 'tatry',
      title: 'Tatra path',
      region: 'Morava',
      countryCode: 'SK',
    );
    expect(palava.countryCode, 'CZ,AT');

    await _pumpCatalog(
      tester,
      challenges: [palava, tatry],
      details: [
        for (final challenge in [palava, tatry])
          ChallengeDetail(challenge: challenge, waypoints: const []),
      ],
      promos: const [],
    );

    await tester.tap(find.byKey(const Key('catalog-filter-region-CZ')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('catalog-country-toulky-palavou')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('catalog-country-tatry')), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-filter-region-CZ')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-regions-AT')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('catalog-country-toulky-palavou')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('catalog-country-tatry')), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-regions-AT')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-regions-SK')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('catalog-country-toulky-palavou')),
      findsNothing,
    );
    expect(find.byKey(const Key('catalog-country-tatry')), findsOneWidget);
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

  testWidgets('null country_code stays listed until a flag is selected', (
    tester,
  ) async {
    final unset = _challenge(
      id: 'unset-country',
      title: 'No country',
      region: 'Beskydy',
    );
    final named = _challenge(
      id: 'named',
      title: 'Named range',
      region: 'Promo',
      countryCode: 'PL',
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
    expect(find.text('No country'), findsAtLeastNWidgets(1));
    expect(find.text('Named range'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('catalog-filter-region-PL')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-filter-region-PL')));
    await tester.pumpAndSettle();
    expect(find.text('Named range'), findsAtLeastNWidgets(1));
    expect(find.text('No country'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('No country'), findsAtLeastNWidgets(1));
    expect(find.text('Named range'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'difficulty chip keeps ungraded challenges and clear-all resets',
    (tester) async {
      final easy = _challenge(
        id: 'easy-1',
        title: 'Gentle walk',
        difficulty: CatalogDifficulty.easy,
        countryCode: 'CZ',
      );
      final hard = _challenge(
        id: 'hard-1',
        title: 'Hard climb',
        difficulty: CatalogDifficulty.hard,
        countryCode: 'SK',
      );
      final unset = _challenge(id: 'unset-1', title: 'No grade');
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
