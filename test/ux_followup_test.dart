import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:viateria/ui/layout/breakpoints.dart';
import 'package:viateria/ui/layout/map_search_metrics.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
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
    final cover = tester.getRect(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ColoredBox && widget.color == BrandColors.forest,
            ),
          )
          .first,
    );
    expect(cover.left, 0);
    expect(cover.right, 390);
    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
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
    final cover = tester.getRect(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ColoredBox && widget.color == BrandColors.forest,
            ),
          )
          .first,
    );
    expect(cover.top, 0);
    expect(cover.left, 0);
    expect(cover.right, 390);
    expect(
      cover.height,
      challengeHeroExtent(layoutWidth: 390, windowWidth: 390),
    );
  });

  test('hero is 3:2 under 600 and 16:9 from 600, capped at 300 and 480', () {
    expect(challengeHeroAspect(390), 3 / 2);
    expect(challengeHeroAspect(800), 16 / 9);
    expect(challengeHeroMaxHeight(390), 300);
    expect(challengeHeroMaxHeight(1280), 480);
    expect(challengeHeroExtent(layoutWidth: 390, windowWidth: 390), 260);
    expect(challengeHeroExtent(layoutWidth: 800, windowWidth: 800), 450);
    expect(challengeHeroExtent(layoutWidth: 1280, windowWidth: 1280), 480);
    expect(challengeHeroExtent(layoutWidth: 640, windowWidth: 1280), 360);
    expect(challengeHeroAlignment(null), const Alignment(0, -0.2));
    expect(challengeHeroAlignment(0.4), const Alignment(0, 0.4));
  });

  test('the floating bar hides while the in-page block is still 30 percent visible', () {
    expect(
      floatingPayBarShouldShow(
        scrolledEnough: true,
        inlineVisibleFraction: 0.30,
        suppressed: false,
        paid: false,
      ),
      isFalse,
    );
    expect(
      floatingPayBarShouldShow(
        scrolledEnough: true,
        inlineVisibleFraction: 0.29,
        suppressed: false,
        paid: false,
      ),
      isTrue,
    );
    expect(
      floatingPayBarShouldShow(
        scrolledEnough: false,
        inlineVisibleFraction: 0,
        suppressed: false,
        paid: false,
      ),
      isFalse,
    );
    expect(
      floatingPayBarShouldShow(
        scrolledEnough: true,
        inlineVisibleFraction: 0,
        suppressed: true,
        paid: false,
      ),
      isFalse,
    );
    expect(
      floatingPayBarShouldShow(
        scrolledEnough: true,
        inlineVisibleFraction: 0,
        suppressed: false,
        paid: true,
      ),
      isFalse,
    );
    expect(
      inlinePayVisibleFraction(
        blockTop: 100,
        blockBottom: 200,
        scrollOffset: 80,
        viewport: 100,
      ),
      closeTo(0.8, 0.001),
    );
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

    expect(tester.getSize(find.byType(ChallengeHero)), const Size(390, 260));
    final photo = tester.widget<Image>(
      find.byKey(const Key('challenge-hero-photo')),
    );
    expect(photo.fit, BoxFit.contain);
    expect(photo.alignment, const Alignment(0, -0.2));
    expect(find.byKey(const Key('challenge-hero-scrim')), findsOneWidget);
    expect(find.byKey(const Key('challenge-hero-letterbox')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ChallengeHero),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
    final title = tester.widget<Text>(find.byKey(const Key('challenge-title')));
    expect(title.maxLines, 1);
    expect(title.style?.fontSize, 24);
    expect(title.style?.fontFamily, AppTheme.displayFont);
    expect(title.style?.color, BrandColors.cream);
    expect(find.byKey(const Key('challenge-back')), findsOneWidget);
    expect(find.byTooltip('Zpět'), findsOneWidget);

    tester.view.physicalSize = const Size(390, 844);
    await tester.runAsync(_precacheCover);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChallengeHero(
            url: 'asset://assets/challenges/beskydy-autumn.jpg',
            title: 'Beskydy',
            backLabel: 'Zpět',
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final framed = tester.getSize(find.byType(ChallengeHero));
    expect(framed.width, 390);
    expect(framed.height, closeTo(390 / (1280 / 854), 0.5));
    expect(find.byKey(const Key('challenge-hero-letterbox')), findsNothing);
    expect(
      tester.widget<Image>(find.byKey(const Key('challenge-hero-photo'))).fit,
      BoxFit.contain,
    );
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

  testWidgets('a tall photo is cropped to the landscape frame', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChallengeHero(url: 'memory', focalY: 0.25, title: 'Tall ridge'),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ChallengeHero)).height, 260);
    expect(find.byKey(const Key('challenge-hero-letterbox')), findsNothing);
    final sharp = tester.widget<Image>(
      find.byKey(const Key('challenge-hero-photo')),
    );
    expect(sharp.fit, BoxFit.contain);
    expect(sharp.alignment, const Alignment(0, 0.25));
    final scrim = tester.getSize(find.byKey(const Key('challenge-hero-scrim')));
    expect(scrim.width, 390);
    expect(scrim.height, closeTo(65, 0.5));
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
    expect(tester.getSize(find.byType(ChallengeHero)), const Size(1280, 480));
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

  test('a known photo stays under the height cap without a wider crop', () {
    const beskydy = 1280 / 854;
    const portrait = 960 / 1114;
    for (final window in [360.0, 412.0, 768.0, 1280.0, 1920.0]) {
      final layout = window >= Breakpoints.mediumMax ? window / 2 : window;
      final width = challengeHeroPhotoWidth(
        layoutWidth: layout,
        windowWidth: window,
        imageAspect: beskydy,
      );
      final height = challengeHeroExtent(
        layoutWidth: layout,
        windowWidth: window,
        imageAspect: beskydy,
      );
      expect(height, lessThanOrEqualTo(challengeHeroMaxHeight(window) + 0.01));
      expect(width / height, closeTo(beskydy, 0.01), reason: 'window $window');
      expect(width, lessThanOrEqualTo(layout + 0.01));
      if (layout / beskydy <= challengeHeroMaxHeight(window)) {
        expect(width, closeTo(layout, 0.01), reason: 'full width at $window');
      }
    }
    expect(
      challengeHeroPhotoWidth(
        layoutWidth: 390,
        windowWidth: 390,
        imageAspect: portrait,
      ),
      closeTo(300 * portrait, 0.01),
    );
    expect(
      challengeHeroExtent(
        layoutWidth: 1920,
        windowWidth: 1920,
        imageAspect: beskydy,
      ),
      480,
    );
    expect(
      challengeHeroPhotoWidth(
        layoutWidth: 1920,
        windowWidth: 1920,
        imageAspect: beskydy,
      ),
      closeTo(480 * beskydy, 0.01),
    );
  });

  testWidgets('the hero shows the whole photo at each viewport width', (
    tester,
  ) async {
    const beskydy = 1280 / 854;
    await tester.runAsync(
      () => _resolveImage(
        const AssetImage('assets/challenges/beskydy-autumn.jpg'),
      ),
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final window in [360.0, 412.0, 768.0, 1280.0, 1920.0]) {
      final layout = window >= Breakpoints.mediumMax ? window / 2 : window;
      tester.view.physicalSize = Size(window, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: layout,
                child: const ChallengeHero(
                  url: 'asset://assets/challenges/beskydy-autumn.jpg',
                  title: 'Beskydy',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final hero = tester.getRect(find.byType(ChallengeHero));
      final photo = tester.getRect(
        find.byKey(const Key('challenge-hero-photo')),
      );
      final expectedWidth = challengeHeroPhotoWidth(
        layoutWidth: layout,
        windowWidth: window,
        imageAspect: beskydy,
      );
      final expectedHeight = challengeHeroExtent(
        layoutWidth: layout,
        windowWidth: window,
        imageAspect: beskydy,
      );
      expect(hero.width, closeTo(layout, 0.6), reason: 'band $window');
      expect(photo.width, closeTo(expectedWidth, 0.6), reason: 'photo $window');
      expect(
        photo.height,
        closeTo(expectedHeight, 0.6),
        reason: 'photo $window',
      );
      expect(photo.width / photo.height, closeTo(beskydy, 0.02));
      expect(photo.center.dx, closeTo(hero.center.dx, 0.6));
      expect(photo.top, closeTo(hero.top, 0.6));
      expect(photo.left, greaterThanOrEqualTo(hero.left - 0.6));
      expect(photo.right, lessThanOrEqualTo(hero.right + 0.6));
      expect(photo.bottom, lessThanOrEqualTo(hero.bottom + 0.6));
      expect(
        tester.widget<Image>(find.byKey(const Key('challenge-hero-photo'))).fit,
        BoxFit.contain,
      );
      expect(
        find.descendant(
          of: find.byType(ChallengeHero),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('challenge-hero-letterbox')), findsNothing);
    }
  });

  testWidgets('a portrait hero is shown whole under the mobile cap', (
    tester,
  ) async {
    const portrait = 960 / 1114;
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => _resolveImage(
        const AssetImage('assets/challenges/alice-manfield.jpg'),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChallengeHero(
            url: 'asset://assets/challenges/alice-manfield.jpg',
            title: 'Alice',
          ),
        ),
      ),
    );
    await tester.pump();
    final hero = tester.getRect(find.byType(ChallengeHero));
    final photo = tester.getRect(find.byKey(const Key('challenge-hero-photo')));
    expect(hero.width, 390);
    expect(hero.height, 300);
    expect(photo.height, closeTo(300, 0.6));
    expect(photo.width, closeTo(300 * portrait, 0.6));
    expect(photo.width / photo.height, closeTo(portrait, 0.02));
    expect(photo.center.dx, closeTo(hero.center.dx, 0.6));
    expect(
      find.descendant(
        of: find.byType(ChallengeHero),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
  });

  testWidgets('payment bar lines up with the bottom nav pill', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
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
    final position = scrollable.position;
    expect(
      position.maxScrollExtent,
      greaterThanOrEqualTo(position.viewportDimension * 0.5),
    );
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 1),
    );
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );
    expect(find.text('Accept the challenge'), findsOneWidget);
    final diploma = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-diploma')),
    );
    final medal = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-medal')),
    );
    expect(
      diploma.width,
      lessThanOrEqualTo(ChallengePaymentBarMetrics.buttonMaxWidth),
    );
    expect(
      medal.width,
      lessThanOrEqualTo(ChallengePaymentBarMetrics.buttonMaxWidth),
    );
    expect(
      medal.left - diploma.right,
      closeTo(ChallengePaymentBarMetrics.rowGap, 0.5),
    );
    expect((diploma.left + medal.right) / 2, closeTo(195, 1));
    final nav = tester.getRect(find.byKey(const Key('app-bottom-nav')));
    expect(nav.top - diploma.bottom, closeTo(12, 1));
    expect(
      tester.widget(find.byKey(const Key('challenge-payment-bar'))),
      isA<Padding>(),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('challenge-floating-pay-diploma')))
          .height,
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
      const Size(64, 44),
    );
    expect(
      AppTheme.light().outlinedButtonTheme.style?.minimumSize?.resolve({}),
      const Size(64, 44),
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

Future<void> _precacheCover() {
  return _resolveImage(
    const AssetImage('assets/challenges/beskydy-autumn.jpg'),
  );
}

Future<void> _resolveImage(ImageProvider provider) {
  return provider
      .resolve(ImageConfiguration(bundle: rootBundle, devicePixelRatio: 1))
      .timeout();
}

extension on ImageStream {
  Future<void> timeout() {
    final done = Completer<void>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        removeListener(listener);
        if (!done.isCompleted) done.complete();
      },
      onError: (error, stack) {
        removeListener(listener);
        if (!done.isCompleted) done.completeError(error, stack);
      },
    );
    addListener(listener);
    return done.future;
  }
}
