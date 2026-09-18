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

Challenge _challenge({
  required String id,
  required String title,
  String description = '',
  AccessMode mode = AccessMode.open,
  PricingType pricing = PricingType.free,
  String? countryCode,
  String? region,
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
    translations:
        translations ??
        [LocalizedText(locale: 'en', title: title, description: description)],
  );
}

AppServices _services({
  List<Challenge>? challenges,
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
      details: [open, story],
      promos: promos ?? [samplePromo()],
    ),
    progress: MemoryProgress(details: [open, story]),
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
  List<PromoStripe>? promos,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    _wrap(
      const CatalogScreen(),
      _services(challenges: challenges, promos: promos),
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
    expect(find.text('Open trail'), findsOneWidget);
    expect(find.text('Story trail'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'unlock',
    );
    await tester.pumpAndSettle();
    expect(find.text('Weekend hike'), findsNothing);
    expect(find.text('Story trail'), findsOneWidget);
    expect(find.text('Open trail'), findsNothing);
  });

  testWidgets('price and mode chips use AND across groups', (tester) async {
    await _pumpCatalog(tester);

    await tester.tap(find.byKey(const Key('catalog-filter-price-paid')));
    await tester.pumpAndSettle();
    expect(find.text('Story trail'), findsOneWidget);
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
    expect(find.text('Open trail'), findsOneWidget);
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
    expect(find.text('Open trail'), findsOneWidget);
    expect(find.text('Story trail'), findsOneWidget);
    expect(find.text('Weekend hike'), findsOneWidget);
    expect(find.byKey(const Key('catalog-no-matches')), findsNothing);
  });

  testWidgets('chip row clear-all also resets search', (tester) async {
    await _pumpCatalog(tester);
    await tester.tap(find.byKey(const Key('catalog-filter-price-free')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-clear-filters')), findsOneWidget);
    await tester.tap(find.byKey(const Key('catalog-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Open trail'), findsOneWidget);
    expect(find.text('Story trail'), findsOneWidget);
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
    expect(find.byType(CountryFlag), findsNWidgets(5));
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
    expect(searchRect.top, greaterThan(headerRect.top));
    expect(searchRect.bottom, lessThan(headerRect.bottom));
    expect(chipsRect.top, greaterThan(searchRect.bottom));
    expect(chipsRect.bottom, lessThanOrEqualTo(headerRect.bottom + 0.5));
    expect(
      searchRect.left,
      headerRect.left + CatalogWelcomeHeader.innerHorizontalPadding,
    );
    expect(
      chipsRect.left,
      headerRect.left + CatalogWelcomeHeader.innerHorizontalPadding,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('catalog-search-field')))
          .decoration
          ?.fillColor,
      BrandColors.cream,
    );
  });
}
