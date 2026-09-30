import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/challenge_mapping.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/domain/catalog_query.dart';
import 'package:viateria/domain/promo.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/screens/catalog_screen.dart';
import 'package:viateria/ui/widgets/promo_widget.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('promo audience', () {
    const viewer = PromoViewer(
      userId: 'ada',
      locale: 'cs',
      countryCode: 'CZ',
      segmentIds: {'new_users'},
    );

    test('zero assignments is everyone', () {
      expect(promoMatchesViewer(const [], viewer), isTrue);
    });

    test('any matching assignment is enough', () {
      expect(
        promoMatchesViewer(const [
          PromoAssignment(targetType: PromoTargetType.user, userId: 'other'),
          PromoAssignment(targetType: PromoTargetType.locale, locale: 'cs'),
        ], viewer),
        isTrue,
      );
      expect(
        promoMatchesViewer(const [
          PromoAssignment(targetType: PromoTargetType.user, userId: 'ada'),
        ], viewer),
        isTrue,
      );
      expect(
        promoMatchesViewer(const [
          PromoAssignment(
            targetType: PromoTargetType.segment,
            segmentId: 'new_users',
          ),
        ], viewer),
        isTrue,
      );
      expect(
        promoMatchesViewer(const [
          PromoAssignment(targetType: PromoTargetType.country, countryCode: 'cz'),
        ], viewer),
        isTrue,
      );
      expect(
        promoMatchesViewer(const [
          PromoAssignment(targetType: PromoTargetType.all),
        ], viewer),
        isTrue,
      );
    });

    test('a non-matching assignment hides the stripe', () {
      expect(
        promoMatchesViewer(const [
          PromoAssignment(targetType: PromoTargetType.user, userId: 'ondrej'),
        ], viewer),
        isFalse,
      );
      expect(
        promoMatchesViewer(const [
          PromoAssignment(targetType: PromoTargetType.locale, locale: 'de'),
          PromoAssignment(
            targetType: PromoTargetType.country,
            countryCode: 'SK',
          ),
        ], viewer),
        isFalse,
      );
      expect(
        promoMatchesViewer(const [
          PromoAssignment(targetType: PromoTargetType.country, countryCode: 'CZ'),
        ], const PromoViewer(userId: 'ada')),
        isFalse,
      );
    });
  });

  group('countdown', () {
    final strings = AppStrings('cs');
    final now = DateTime(2026, 9, 30, 15);

    String? label(DateTime? endsAt) => promoValidityLabel(
      now: now,
      endsAt: endsAt,
      strings: strings,
    );

    test('null and expired draw no row', () {
      expect(label(null), isNull);
      expect(label(now.subtract(const Duration(seconds: 1))), isNull);
    });

    test('under an hour, ceil hours, then a calendar date', () {
      expect(label(now.add(const Duration(minutes: 59))), strings.promoUnderHour);
      expect(
        label(now.add(const Duration(hours: 1))),
        'Zbývá 1 h',
      );
      expect(
        label(now.add(const Duration(hours: 1, minutes: 1))),
        'Zbývá 2 h',
      );
      expect(
        label(now.add(const Duration(hours: 47, minutes: 1))),
        'Zbývá 48 h',
      );
      expect(label(now.add(const Duration(hours: 48))), 'Zbývá 48 h');
      expect(
        label(now.add(const Duration(hours: 48, seconds: 1))),
        'Platí do 2. 10.',
      );
      expect(
        label(DateTime(2026, 10, 14, 18)),
        'Platí do 14. 10.',
      );
      expect(
        label(DateTime(2027, 1, 2, 12)),
        'Platí do 2. 1. 2027',
      );
    });

    test('english and german use the same date and their own words', () {
      final ends = DateTime(2026, 10, 14, 18);
      expect(
        promoValidityLabel(now: now, endsAt: ends, strings: AppStrings('en')),
        'Valid until 14. 10.',
      );
      expect(
        promoValidityLabel(now: now, endsAt: ends, strings: AppStrings('de')),
        'Gültig bis 14. 10.',
      );
      expect(
        promoValidityLabel(
          now: now,
          endsAt: now.add(const Duration(minutes: 10)),
          strings: AppStrings('en'),
        ),
        'Less than an hour left',
      );
    });
  });

  test('visible promos drop expired rows and sort by sortOrder', () {
    final now = DateTime(2026, 9, 30, 12);
    final promos = [
      PromoStripe(
        id: 'later',
        status: PublishStatus.published,
        sortOrder: 2,
        translations: const [],
      ),
      PromoStripe(
        id: 'expired',
        status: PublishStatus.published,
        sortOrder: 0,
        endsAt: now.subtract(const Duration(minutes: 1)),
        translations: const [],
      ),
      PromoStripe(
        id: 'draft',
        status: PublishStatus.draft,
        sortOrder: 0,
        translations: const [],
      ),
      PromoStripe(
        id: 'first',
        status: PublishStatus.published,
        sortOrder: 1,
        endsAt: now.add(const Duration(days: 1)),
        translations: const [],
      ),
    ];
    expect(
      visiblePromos(promos, now).map((promo) => promo.id),
      ['first', 'later'],
    );
    expect(promoCarouselItemWidth(400), 376);
    expect(promoCarouselItemWidth(20), 20);
  });

  test('exclusive challenges stay out of filters, search, and list queries', () async {
    final exclusive = Challenge(
      id: 'secret',
      slug: 'promo-mock',
      accessMode: AccessMode.open,
      pricingType: PricingType.free,
      priceCents: 0,
      currency: 'eur',
      status: PublishStatus.published,
      isPromo: true,
      translations: const [
        LocalizedText(
          locale: 'cs',
          title: 'Promo výzva',
          description: 'skrytá',
        ),
      ],
    );
    final open = Challenge(
      id: 'open-1',
      slug: 'open',
      accessMode: AccessMode.open,
      pricingType: PricingType.free,
      priceCents: 0,
      currency: 'eur',
      status: PublishStatus.published,
      translations: const [
        LocalizedText(locale: 'en', title: 'Open trail', description: ''),
      ],
    );
    expect(
      filterCatalogChallenges([
        exclusive,
        open,
      ], const CatalogFilter()).map((c) => c.id),
      ['open-1'],
    );
    expect(
      filterCatalogChallenges([
        exclusive,
      ], const CatalogFilter(query: 'Promo')),
      isEmpty,
    );

    final catalog = MemoryCatalog(challenges: [exclusive, open]);
    final listed = await catalog.fetchPublishedChallenges();
    expect(listed.map((challenge) => challenge.id), ['open-1']);
  });

  test('promoFromRow keeps kind, prices, and schedule', () {
    final promo = promoFromRow({
      'id': 'stripe-1',
      'status': 'published',
      'kind': 'exclusive',
      'sort_order': 3,
      'image_url': 'https://cdn.example/cover.jpg',
      'challenge_id': 'chal-1',
      'ends_at': '2026-10-14T12:00:00Z',
      'promo_diploma_price_cents': 150,
      'promo_medal_price_cents': null,
      'promo_stripe_i18n': [
        {
          'locale': 'cs',
          'title': 'Promo výzva',
          'subtitle': 'Na čtrnáct dní',
          'cta_label': 'Získat výzvu',
        },
      ],
    });
    expect(promo.kind, PromoKind.exclusive);
    expect(promo.hasCover, isTrue);
    expect(promo.promoDiplomaPriceCents, 150);
    expect(promo.promoMedalPriceCents, isNull);
    expect(promo.copyFor('cs').ctaLabel, 'Získat výzvu');
    expect(promo.endsAt, DateTime.utc(2026, 10, 14, 12));
    expect(
      promosFromRpc([
        {'id': 'a', 'status': 'published', 'sort_order': 0},
      ]).single.id,
      'a',
    );

    final mapped = challengeFromRow({
      'id': 'c',
      'slug': 'promo-mock',
      'access_mode': 'open',
      'pricing_type': 'free',
      'price_cents': 0,
      'status': 'published',
      'is_promo': true,
    });
    expect(mapped.isPromo, isTrue);
  });

  testWidgets('empty and expired promos leave no section', (tester) async {
    await _pumpCatalog(tester, promos: const []);
    expect(find.byKey(const Key('promo-widget')), findsNothing);
    expect(find.byKey(const Key('catalog-hero-carousel')), findsOneWidget);
    expect(find.byKey(const Key('catalog-featured')), findsOneWidget);
    expect(find.byKey(const Key('catalog-regions')), findsOneWidget);
    final featured = tester.getRect(find.byKey(const Key('catalog-featured')));
    final regions = tester.getRect(find.byKey(const Key('catalog-regions')));
    expect(regions.top - featured.bottom, closeTo(16, 1));
    expect(find.text('Promo'), findsNothing);

    await _pumpCatalog(
      tester,
      promos: [
        PromoStripe(
          id: 'gone',
          status: PublishStatus.published,
          sortOrder: 0,
          endsAt: DateTime.utc(2020),
          translations: const [
            LocalizedText(locale: 'en', title: 'Expired offer'),
          ],
        ),
      ],
    );
    expect(find.text('Expired offer'), findsNothing);
    expect(find.byKey(const Key('promo-widget')), findsNothing);
    expect(find.byKey(const Key('catalog-regions')), findsOneWidget);
  });

  testWidgets('promo fetch error keeps the catalog and hides the slot', (
    tester,
  ) async {
    final services = _services();
    (services.catalog as MemoryCatalog).promosError = StateError('promo down');
    await _pumpCatalog(tester, services: services);
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('promo-widget')), findsNothing);
    expect(find.text(AppStrings('en').errorGeneric), findsNothing);
    expect(find.byKey(const Key('catalog-regions')), findsOneWidget);
  });

  testWidgets('exclusive challenge is absent from hero, featured, and search', (
    tester,
  ) async {
    final open = sampleOpenChallenge();
    final exclusive = Challenge(
      id: 'secret',
      slug: 'promo-mock',
      accessMode: AccessMode.open,
      pricingType: PricingType.free,
      priceCents: 0,
      currency: 'eur',
      status: PublishStatus.published,
      isPromo: true,
      countryCode: 'CZ',
      translations: const [
        LocalizedText(
          locale: 'en',
          title: 'Secret exclusive',
          description: 'not in the catalog',
        ),
      ],
    );
    await _pumpCatalog(
      tester,
      challenges: [open.challenge, exclusive],
      details: [open],
      promos: const [],
    );
    expect(find.text('Secret exclusive'), findsNothing);
    expect(find.byKey(const Key('catalog-hero-secret')), findsNothing);
    expect(find.byKey(const Key('catalog-featured-secret')), findsNothing);
    expect(find.text('Open trail'), findsAtLeastNWidgets(1));

    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'Secret',
    );
    await tester.pumpAndSettle();
    expect(find.text('Secret exclusive'), findsNothing);
  });

  testWidgets('one stripe is a forest card under featured, not above the hero', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpCatalog(
      tester,
      locale: 'cs',
      promos: [
        PromoStripe(
          id: 'promo-1',
          status: PublishStatus.published,
          sortOrder: 0,
          kind: PromoKind.exclusive,
          challengeId: 'open-1',
          endsAt: now.add(const Duration(days: 14)),
          translations: const [
            LocalizedText(
              locale: 'cs',
              title: 'Promo výzva',
              subtitle: 'Exkluzivní trasa',
              ctaLabel: 'Získat výzvu',
            ),
          ],
        ),
      ],
    );

    final hero = tester.getRect(find.byKey(const Key('catalog-hero-carousel')));
    final featured = tester.getRect(find.byKey(const Key('catalog-featured')));
    final promo = tester.getRect(find.byKey(const Key('promo-widget')));
    final regions = tester.getRect(find.byKey(const Key('catalog-regions')));
    expect(featured.top, greaterThan(hero.bottom - 0.5));
    expect(promo.top, greaterThan(featured.bottom - 0.5));
    expect(regions.top, greaterThan(promo.bottom - 0.5));
    expect(find.byKey(const Key('promo-carousel')), findsNothing);
    expect(find.byKey(const Key('promo-page-view')), findsNothing);

    final surface = tester.widget<Material>(
      find.byKey(const Key('promo-surface-promo-1')),
    );
    expect(surface.color, BrandColors.forest);
    expect(surface.color, isNot(BrandColors.shellFill));
    expect(surface.color, isNot(BrandColors.cream));
    expect(surface.elevation, 0);
    final radius = (surface.shape! as RoundedRectangleBorder).borderRadius;
    expect(radius, BorderRadius.circular(16));

    final tag = tester.widget<Container>(
      find.byKey(const Key('promo-tag-promo-1')),
    );
    final decoration = tag.decoration! as BoxDecoration;
    expect(decoration.color, BrandColors.sage);
    expect(decoration.borderRadius, BorderRadius.circular(999));
    expect(tag.padding, const EdgeInsets.symmetric(horizontal: 10, vertical: 4));
    expect(find.text('Promo'), findsOneWidget);
    expect(find.text('Sleva'), findsNothing);

    final title = tester.widget<Text>(
      find.byKey(const Key('promo-title-promo-1')),
    );
    expect(title.style?.fontFamily, 'Playfair Display');
    expect(title.style?.color, BrandColors.cream);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(title.style?.fontSize, 20);
    expect(title.maxLines, 2);

    final subtitle = tester.widget<Text>(
      find.byKey(const Key('promo-subtitle-promo-1')),
    );
    expect(subtitle.style?.fontSize, 14);
    expect(subtitle.maxLines, 2);
    expect(subtitle.style?.color, BrandColors.cream.withValues(alpha: 0.8));

    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.textContaining('Platí do'), findsOneWidget);
    expect(find.text('Získat výzvu'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('promo-cta-promo-1')),
    );
    final style = button.style!;
    expect(style.backgroundColor?.resolve({}), BrandColors.cream);
    expect(style.foregroundColor?.resolve({}), BrandColors.forest);
    expect(
      style.backgroundColor?.resolve({WidgetState.disabled}),
      BrandColors.cream.withValues(alpha: 0.4),
    );
    final minimum = style.minimumSize?.resolve({});
    expect(minimum!.height, greaterThanOrEqualTo(44));
    final shape = style.shape?.resolve({}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(12));
    expect(find.byKey(const Key('promo-cover-promo-1')), findsNothing);
  });

  testWidgets('two stripes snap with forest and beige dots', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 400,
            child: PromoWidget(
              promos: [
                _stripe('b', sortOrder: 2),
                _stripe('a', sortOrder: 0),
              ],
              onOpen: (_) {},
              now: DateTime(2026, 9, 30),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('promo-carousel')), findsOneWidget);
    expect(find.byKey(const Key('promo-dots')), findsOneWidget);
    final page = tester.widget<PageView>(find.byType(PageView));
    expect(page.controller!.viewportFraction, closeTo(376 / 400, 0.001));
    expect(
      tester.widget<Container>(find.byKey(const Key('promo-dot-0'))).decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        BrandColors.forest,
      ),
    );
    expect(
      tester.widget<Container>(find.byKey(const Key('promo-dot-1'))).decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        BrandColors.beige,
      ),
    );
    expect(find.byKey(const Key('promo-strip-a')), findsOneWidget);
    expect(find.text('Weekend hike'), findsNothing);
  });

  testWidgets('cover sits in a clipped 4:3 frame', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PromoStrip(
          promo: _stripe('cover', imageUrl: 'https://cdn.example/cover.jpg'),
          now: DateTime(2026, 9, 30),
          onOpen: () {},
        ),
      ),
    );
    await tester.pump();
    final cover = find.byKey(const Key('promo-cover-cover'));
    expect(cover, findsOneWidget);
    expect(
      find.ancestor(of: cover, matching: find.byType(ClipRRect)),
      findsWidgets,
    );
    final ratio = tester.widget<AspectRatio>(
      find.ancestor(of: cover, matching: find.byType(AspectRatio)).first,
    );
    expect(ratio.aspectRatio, 4 / 3);
  });
}

PromoStripe _stripe(
  String id, {
  int sortOrder = 0,
  String? imageUrl,
}) {
  return PromoStripe(
    id: id,
    status: PublishStatus.published,
    sortOrder: sortOrder,
    kind: PromoKind.exclusive,
    imageUrl: imageUrl,
    challengeId: 'open-1',
    endsAt: DateTime(2026, 10, 14),
    translations: const [
      LocalizedText(locale: 'en', title: 'Route', subtitle: 'Soon', ctaLabel: 'Go'),
    ],
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

Widget _wrap(Widget child, {String locale = 'en', AppServices? services}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: locale)),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider<AppServices>.value(value: services ?? _services()),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

Future<void> _pumpCatalog(
  WidgetTester tester, {
  String locale = 'en',
  List<Challenge>? challenges,
  List<ChallengeDetail>? details,
  List<PromoStripe>? promos,
  AppServices? services,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    _wrap(
      const CatalogScreen(),
      locale: locale,
      services:
          services ??
          _services(challenges: challenges, details: details, promos: promos),
    ),
  );
  await tester.pumpAndSettle();
}
