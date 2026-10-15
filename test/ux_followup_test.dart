import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/route_services.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/map/poi_source_sync.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/layout/map_search_metrics.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/app_shell.dart';
import 'package:viateria/ui/widgets/catalog_cards.dart';
import 'package:viateria/ui/widgets/challenge_hero.dart';
import 'package:viateria/ui/widgets/cooperative_map_gestures.dart';
import 'package:viateria/ui/widgets/route_start_field.dart';

import 'bottom_nav_test.dart' show buildServices, wrapApp;
import 'helpers/catalog_finders.dart';
import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reduced motion snaps the hero fade', () {
    expect(
      challengeHeroExpandedFade(
        shrinkOffset: 20,
        maxExtent: 160,
        minExtent: 64,
        reduceMotion: false,
      ),
      closeTo(76 / 96, 0.001),
    );
    expect(
      challengeHeroExpandedFade(
        shrinkOffset: 20,
        maxExtent: 160,
        minExtent: 64,
        reduceMotion: true,
      ),
      1,
    );
    expect(
      challengeHeroExpandedFade(
        shrinkOffset: 80,
        maxExtent: 160,
        minExtent: 64,
        reduceMotion: true,
      ),
      0,
    );
  });

  test('location line prefers the region, then a locale country name', () {
    const region = Challenge(
      id: 'a',
      slug: 'a',
      accessMode: AccessMode.open,
      pricingType: PricingType.free,
      priceCents: 0,
      currency: 'eur',
      status: PublishStatus.published,
      region: 'Beskydy',
      countryCode: 'CZ',
      translations: [],
    );
    expect(challengeLocationLine(region, 'en'), 'Beskydy');
    const country = Challenge(
      id: 'a',
      slug: 'a',
      accessMode: AccessMode.open,
      pricingType: PricingType.free,
      priceCents: 0,
      currency: 'eur',
      status: PublishStatus.published,
      countryCode: 'SK',
      translations: [],
    );
    expect(challengeLocationLine(country, 'cs'), 'Slovensko');
    expect(challengeLocationLine(country, 'en'), 'Slovakia');
    expect(challengeLocationLine(country, 'de'), 'Slowakei');
  });

  testWidgets('scrolling collapses the hero into a pinned forest bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              ChallengeCollapsingHero(
                url: 'https://example.invalid/cover.jpg',
                title: 'Příběhová stezka',
                location: 'Beskydy',
                backLabel: 'Zpět',
                onBack: () {},
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('challenge-hero-expanded')))
          .opacity,
      1,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('challenge-hero-collapsed')))
          .opacity,
      0,
    );
    expect(find.byTooltip('Zpět'), findsOneWidget);

    controller.jumpTo(400);
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('challenge-hero-expanded')))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('challenge-hero-collapsed')))
          .opacity,
      1,
    );
    final bar = tester.widget<Text>(
      find.byKey(const Key('challenge-collapsed-title')),
    );
    expect(bar.maxLines, 1);
    expect(bar.style?.fontFamily, AppTheme.displayFont);
    expect(bar.style?.color, BrandColors.cream);
    expect(find.text('Beskydy'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('challenge-back'))).dy, 12);
    final collapsed = tester.getSize(
      find.byKey(const Key('challenge-hero-collapsed')),
    );
    expect(collapsed.height, 64);
    final frame = tester.getRect(find.byKey(const Key('challenge-hero-frame')));
    expect(frame.left, AppShell.horizontalInset);
    expect(frame.right, 390 - AppShell.horizontalInset);
    expect(frame.top, 0);
    expect(frame.height, ChallengeCollapsingHero.collapsedBody);
    expect(
      tester
          .widget<ClipRRect>(find.byKey(const Key('challenge-hero-frame')))
          .borderRadius,
      BorderRadius.circular(challengeHeroRadius),
    );
  });

  testWidgets('the hero frame sits under the safe area', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 30);
    tester.view.viewPadding = const FakeViewPadding(top: 30);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ChallengeCollapsingHero(
                url: 'https://example.invalid/cover.jpg',
                title: 'Příběhová stezka',
                location: 'Beskydy',
              ),
              SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
    final frame = tester.getRect(find.byKey(const Key('challenge-hero-frame')));
    expect(frame.top, 30);
    expect(frame.left, AppShell.horizontalInset);
    expect(frame.height, challengeHeroHeight(390));
  });

  test('hero is about 4:1, clamped to 160 and 240', () {
    expect(challengeHeroHeight(390), 160);
    expect(challengeHeroHeight(800), 200);
    expect(challengeHeroHeight(1280), 240);
    expect(challengeHeroHeight(2000), 240);
  });

  testWidgets('hero title, scrim, and back control', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChallengeHero(
            url: 'https://example.invalid/cover.jpg',
            title: 'A long challenge title that must ellipsize',
            backLabel: 'Zpět',
            onBack: () {},
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ChallengeHero)).height, 160);
    final frame = tester.getRect(find.byKey(const Key('challenge-hero-frame')));
    expect(frame.left, AppShell.horizontalInset);
    expect(frame.right, 390 - AppShell.horizontalInset);
    expect(frame.top, 0);
    expect(frame.height, 160);
    expect(
      tester
          .widget<ClipRRect>(find.byKey(const Key('challenge-hero-frame')))
          .borderRadius,
      BorderRadius.circular(challengeHeroRadius),
    );
    final title = tester.widget<Text>(find.byKey(const Key('challenge-title')));
    expect(title.maxLines, 1);
    expect(title.style?.fontSize, 24);
    expect(title.style?.fontFamily, AppTheme.displayFont);
    expect(title.style?.color, BrandColors.cream);
    expect(find.byKey(const Key('challenge-back')), findsOneWidget);
    expect(find.byTooltip('Zpět'), findsOneWidget);
    final circle = tester.getSize(find.byType(InkWell));
    expect(circle, const Size(40, 40));
    final tap = tester.getSize(
      find
          .ancestor(of: find.byType(InkWell), matching: find.byType(SizedBox))
          .first,
    );
    expect(tap.width, greaterThanOrEqualTo(48));
    expect(tap.height, greaterThanOrEqualTo(48));
  });

  testWidgets('desktop hero allows two title lines and caps height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChallengeHero(
            url: 'https://example.invalid/cover.jpg',
            title: 'Title',
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ChallengeHero)).height, 240);
    final frame = tester.getRect(find.byKey(const Key('challenge-hero-frame')));
    expect(frame.left, AppShell.horizontalInset);
    expect(frame.right, 1280 - AppShell.horizontalInset);
    expect(frame.height, 240);
    expect(
      tester.widget<Text>(find.byKey(const Key('challenge-title'))).maxLines,
      2,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('challenge-title')))
          .style
          ?.fontSize,
      28,
    );
  });

  testWidgets('payment bar lines up with the bottom nav pill', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapApp(buildServices(), locale: LocaleController(initial: 'en')),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('catalog-hero-open-1'));
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: catalogVerticalScrollable(),
    );
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('challenge-back')), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-nav')), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('challenge-feed-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final nav = tester.getRect(find.byKey(const Key('app-bottom-nav')));
    final bar = tester.getRect(find.byKey(const Key('challenge-payment-bar')));
    expect(bar.left, closeTo(nav.left, 0.01));
    expect(bar.right, closeTo(nav.right, 0.01));
    expect(
      tester.getSize(find.byKey(const Key('challenge-pay-diploma'))).height,
      ChallengePaymentBarMetrics.tapTarget,
    );
  });

  test('payment bar uses a 40 dp hysteresis around half the viewport', () {
    expect(
      paymentBarShouldShow(currentlyVisible: false, offset: 199, viewport: 400),
      isFalse,
    );
    expect(
      paymentBarShouldShow(currentlyVisible: false, offset: 200, viewport: 400),
      isTrue,
    );
    expect(
      paymentBarShouldShow(currentlyVisible: true, offset: 160, viewport: 400),
      isTrue,
    );
    expect(
      paymentBarShouldShow(currentlyVisible: true, offset: 159, viewport: 400),
      isFalse,
    );
  });

  test('verified disk is sage-green with a forest ring and no badge file', () {
    expect(BrandColors.verifiedDiskHex, '#A7B78C');
    expect(File('lib/map/verified_badge_icon.dart').existsSync(), isFalse);
    expect(
      File('lib/ui/widgets/places_map_host.dart').readAsStringSync(),
      isNot(contains('verifiedBadge')),
    );
  });

  test('a viewport change does not reset the poi source', () {
    const place = Place(
      id: 'p1',
      name: 'Rock',
      category: PlaceCategory.nature,
      location: GeoPoint(50, 14),
    );
    final first = [place];
    final viewportPass = [place];
    final gate = PoiSourceGate();
    final signature = poiMarkerSignature(
      places: first,
      selectedId: null,
      challengePlaceIds: const {},
      verifiedPlaceIds: const {'p1'},
    );
    final again = poiMarkerSignature(
      places: viewportPass,
      selectedId: null,
      challengePlaceIds: const {},
      verifiedPlaceIds: const {'p1'},
    );
    expect(signature, again);
    expect(gate.shouldReplace(signature), isTrue);
    expect(gate.shouldReplace(again), isFalse);
    final moved = poiMarkerSignature(
      places: viewportPass,
      selectedId: 'p1',
      challengePlaceIds: const {},
      verifiedPlaceIds: const {'p1'},
    );
    expect(gate.shouldReplace(moved), isTrue);
  });

  test('map search width follows the viewport and focus', () {
    expect(
      mapSearchFieldWidth(
        viewportWidth: 1280,
        slotWidth: 1200,
        margin: 12,
        controlsWidth: 44,
        focused: false,
      ),
      360,
    );
    expect(
      mapSearchFieldWidth(
        viewportWidth: 700,
        slotWidth: 640,
        margin: 12,
        controlsWidth: 44,
        focused: false,
      ),
      350,
    );
    final narrow = mapSearchFieldWidth(
      viewportWidth: 390,
      slotWidth: 330,
      margin: 8,
      controlsWidth: 36,
      focused: false,
    );
    expect(narrow, greaterThanOrEqualTo(200));
    expect(narrow, lessThanOrEqualTo(390 - 16 - 36));
    expect(
      mapSearchFieldWidth(
        viewportWidth: 390,
        slotWidth: 330,
        margin: 8,
        controlsWidth: 36,
        focused: true,
      ),
      330,
    );
  });

  test(
    'route start uses GPS when it is allowed and stays quiet otherwise',
    () async {
      final here = await resolveRouteStart(
        location: MemoryDeviceLocation(
          point: const RouteEndpoint(lat: 50, lng: 14, label: 'GPS'),
        ),
        label: 'Moje poloha',
      );
      expect(here?.label, 'Moje poloha');
      expect(here?.lat, 50);
      final missing = await resolveRouteStart(
        location: MemoryDeviceLocation(error: const LocationFailure('denied')),
        label: 'Moje poloha',
      );
      expect(missing, isNull);
    },
  );

  test('deadline dates and plurals follow the locale', () {
    final due = DateTime(2026, 10, 21);
    expect(formatLocalDate(due, 'cs'), '21. 10. 2026');
    expect(formatLocalDate(due, 'en'), 'Oct 21, 2026');
    expect(formatLocalDate(due, 'de'), '21. Okt. 2026');
    final now = DateTime(2026, 10, 14);
    expect(AppStrings('cs').rewardDaysLeftSuffix(due, now), '· zbývá 7 dní');
    expect(
      AppStrings('cs').rewardDaysLeftSuffix(DateTime(2026, 10, 15), now),
      '· zbývá 1 den',
    );
    expect(
      AppStrings('cs').rewardDaysLeftSuffix(DateTime(2026, 10, 16), now),
      '· zbývá 2 dny',
    );
    expect(AppStrings('cs').routeStopsSummary(1, 1), '1 místo · 1.0 km');
    expect(AppStrings('cs').routeStopsSummary(3, 2), '3 místa · 2.0 km');
    expect(AppStrings('cs').routeStopsSummary(5, 2), '5 míst · 2.0 km');
    expect(
      AppStrings('cs').completedOnLabel(due),
      'Dokončeno dne 21. 10. 2026',
    );
    expect(AppStrings('en').completedOnLabel(due), 'Completed on Oct 21, 2026');
    expect(
      AppStrings('de').completedOnLabel(due),
      'Abgeschlossen am 21. Okt. 2026',
    );
  });

  test('themed buttons lay out side by side in a Row', () {
    expect(
      AppTheme.light().filledButtonTheme.style?.minimumSize?.resolve({}),
      const Size(64, 52),
    );
    expect(
      AppTheme.light().outlinedButtonTheme.style?.minimumSize?.resolve({}),
      const Size(64, 48),
    );
  });

  testWidgets('filled and outlined buttons share a finite Row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: _noop, child: Text('A')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: _noop, child: Text('B')),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final a = tester.getTopLeft(find.text('A'));
    final b = tester.getTopLeft(find.text('B'));
    expect(a.dx, lessThan(b.dx));
  });

  test('web wheel zoom requires Ctrl; other pointers do not', () {
    expect(mapWheelZoomEnabled(isWeb: false, controlPressed: false), isTrue);
    expect(mapWheelZoomEnabled(isWeb: true, controlPressed: false), isFalse);
    expect(mapWheelZoomEnabled(isWeb: true, controlPressed: true), isTrue);
    expect(cooperativeMapIgnoresChild(0), isFalse);
    expect(cooperativeMapIgnoresChild(1), isTrue);
    expect(cooperativeMapIgnoresChild(2), isFalse);
  });

  testWidgets('mouse taps pass through cooperative map gestures', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CooperativeMapGestures(
            child: Center(
              child: GestureDetector(
                key: const Key('pin'),
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const ColoredBox(
                  color: Color(0xFF35483C),
                  child: SizedBox(width: 48, height: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const Key('pin')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('home card shows a bark excerpt under the badge', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final challenge = sampleOpenChallenge().challenge;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ChangeNotifierProvider(
          create: (_) => LocaleController(initial: 'en'),
          child: Scaffold(
            body: SizedBox(
              height: 360,
              child: CatalogFeaturedSection(
                challenges: [challenge, sampleStoryChallenge().challenge],
                routeStats: const {},
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final excerpt = tester.widget<Text>(
      find.byKey(const Key('catalog-featured-excerpt-open-1')),
    );
    expect(excerpt.data, 'Visit any stop');
    expect(excerpt.maxLines, 2);
    expect(excerpt.style?.fontSize, 14);
    expect(excerpt.style?.color, BrandColors.bark);
    final first = tester.getRect(
      find.byKey(const Key('catalog-featured-open-1')),
    );
    final second = tester.getRect(
      find.byKey(const Key('catalog-featured-story-1')),
    );
    expect(second.left - first.right, 16);
    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byKey(const Key('catalog-featured-open-1')),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(padding.padding, const EdgeInsets.all(16));
  });

  test('the map planner and the challenge planner share RouteStartField', () {
    final map = File('lib/ui/screens/places_map_screen.dart')
        .readAsStringSync();
    final challenge = File('lib/ui/widgets/route_planner_panel.dart')
        .readAsStringSync();
    expect(map, contains('RouteStartField'));
    expect(challenge, contains('RouteStartField'));
    expect(map, isNot(contains('SharedPreferences')));
    expect(map, contains('resolveRouteStart'));
  });
}

void _noop() {}
