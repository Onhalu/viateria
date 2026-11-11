import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/diploma_client.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/ui/diploma_share.dart';
import 'package:viateria/ui/screens/diploma_screen.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/catalog_cards.dart';
import 'package:viateria/ui/widgets/challenge_cta_panel.dart';
import 'package:viateria/ui/widgets/shell_bottom_surface.dart';
import 'package:viateria/ui/widgets/challenge_map.dart';

import 'auth_register_form_test.dart';
import 'bottom_nav_test.dart';
import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

/// Before/after frames for the UX audit.
///
/// `CAPTURE_UX=1 UX_SHOT_PREFIX=after flutter test test/ux_shots_test.dart`
void main() {
  if (Platform.environment['CAPTURE_UX'] != '1') return;

  TestWidgetsFlutterBinding.ensureInitialized();
  final prefix = Platform.environment['UX_SHOT_PREFIX'] ?? 'after';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDisableShadows = false;
  });

  tearDown(() {
    debugDisableShadows = true;
  });

  Future<void> loadFonts() async {
    await _loadFamily('Roboto', const [
      '/usr/share/fonts/truetype/macos/Inter-Regular.ttf',
      '/usr/share/fonts/truetype/macos/Inter-Medium.ttf',
      '/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf',
      '/usr/share/fonts/truetype/macos/Inter-Bold.ttf',
    ]);
    await _loadFamily('Onest', const [
      'assets/fonts/Onest[wght].ttf',
    ], fromBundle: true);
    await _loadFamily('MaterialIcons', const [
      '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
    for (final asset in const [
      'assets/challenges/beskydy-autumn.jpg',
      'assets/challenges/alice-manfield.jpg',
    ]) {
      final done = Completer<void>();
      final stream = AssetImage(asset)
          .resolve(ImageConfiguration(bundle: rootBundle, devicePixelRatio: 1));
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, _) {
          stream.removeListener(listener);
          if (!done.isCompleted) done.complete();
        },
        onError: (error, stack) {
          stream.removeListener(listener);
          if (!done.isCompleted) done.completeError(error, stack);
        },
      );
      stream.addListener(listener);
      await done.future;
    }
  }

  void useView(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
  }

  testWidgets('ux audit frames', (tester) async {
    await tester.runAsync(loadFonts);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> shot(String name) => saveShot(tester, '$prefix-$name.png');

    Future<void> resetTree() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    for (final frame in const [
      (name: 'login-mobile', size: Size(390, 844)),
      (name: 'login-desktop', size: Size(1280, 800)),
    ]) {
      useView(tester, frame.size);
      await resetTree();
      await tester.pumpWidget(wrapAuth());
      await tester.pumpAndSettle();
      await shot(frame.name);
    }

    for (final frame in const [
      (name: 'catalog-mobile', size: Size(390, 844)),
      (name: 'catalog-desktop', size: Size(1280, 900)),
    ]) {
      useView(tester, frame.size);
      await resetTree();
      await tester.pumpWidget(
        wrapApp(buildServices(), locale: LocaleController(initial: 'cs')),
      );
      await tester.pumpAndSettle();
      await shot(frame.name);
    }

    for (final frame in const [
      (name: 'challenge-mobile', size: Size(390, 1400)),
      (name: 'challenge-desktop', size: Size(1280, 1200)),
    ]) {
      useView(tester, frame.size);
      await resetTree();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LocaleController(initial: 'cs'),
            ),
            ChangeNotifierProvider(
              create: (_) => LastOpenedChallengeStore(initialId: 'story-1'),
            ),
            Provider.value(value: buildServices()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const ChallengeScreen(challengeId: 'story-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('challenge-pay-diploma')), findsOneWidget);
      expect(find.byKey(const Key('challenge-pay-medal')), findsOneWidget);
      await shot(frame.name);
    }

    for (final frame in const [
      (name: 'map-mobile', size: Size(390, 844)),
      (name: 'map-desktop', size: Size(1280, 800)),
    ]) {
      useView(tester, frame.size);
      await resetTree();
      await tester.pumpWidget(
        wrapApp(buildServices(), locale: LocaleController(initial: 'cs')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.map_outlined).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await shot(frame.name);
    }

    final story = sampleStoryChallenge(
      coverImageUrl: 'asset://assets/challenges/beskydy-autumn.jpg',
    );
    final open = sampleOpenChallenge();
    final purchases = MemoryPurchases()
      ..pay('story-1', paidAt: DateTime(2026, 4, 14));
    useView(tester, const Size(390, 1400));
    await resetTree();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'cs'),
          ),
          ChangeNotifierProvider(
            create: (_) => LastOpenedChallengeStore(initialId: 'story-1'),
          ),
          Provider.value(
            value: buildServices(
              challenges: [open.challenge, story.challenge],
              details: [open, story],
              purchases: purchases,
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ChallengeScreen(challengeId: 'story-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shot('challenge-hero-map');
    await tester.scrollUntilVisible(
      find.byKey(const Key('challenge-reward-deadline')),
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('challenge-feed-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await shot('reward-deadline');

    useView(tester, const Size(1280, 900));
    await resetTree();
    await tester.pumpWidget(
      wrapApp(buildServices(), locale: LocaleController(initial: 'cs')),
    );
    await tester.pumpAndSettle();
    await shot('filters-featured');

    final openSample = sampleOpenChallenge();
    final openCopy = _shotChallenge(
      openSample.challenge,
      translations: [
        for (final text in open.challenge.translations)
          LocalizedText(
            locale: text.locale,
            title: text.title,
            description: switch (text.locale) {
              'cs' => 'Navštivte libovolnou zastávku na stezce a sbírejte razítka po cestě.',
              'de' =>
                'Besuchen Sie einen beliebigen Halt und sammeln Sie Stempel.',
              _ =>
                'Visit any stop along the trail and collect stamps as you go.',
            },
          ),
      ],
      difficulty: CatalogDifficulty.easy,
      length: ChallengeLength.short,
      coverImageUrl: 'asset://assets/challenges/alice-manfield.jpg',
    );
    final storyCopy = _shotChallenge(
      story.challenge,
      translations: const [
        LocalizedText(
          locale: 'cs',
          title: 'Příběhová stezka',
          description:
              'Odemykejte zastávky postupně a přečtěte si příběh mezi nimi.',
        ),
        LocalizedText(
          locale: 'en',
          title: 'Story trail',
          description:
              'Unlock each stop in order and read the story between them.',
          diplomaHeadline: 'Story master',
        ),
        LocalizedText(
          locale: 'de',
          title: 'Geschichtenpfad',
          description: 'Schalten Sie die Stopps der Reihe nach frei.',
        ),
      ],
      difficulty: CatalogDifficulty.normal,
      length: ChallengeLength.medium,
      region: 'Beskydy',
    );
    final shotDetails = [
      ChallengeDetail(challenge: storyCopy, waypoints: story.waypoints),
      ChallengeDetail(challenge: openCopy, waypoints: openSample.waypoints),
    ];
    final progress = MemoryProgress(details: shotDetails);
    progress.statuses['open-1'] = ChallengeRunStatus.completed;
    progress.completed['open-1'] = {'ow-1', 'ow-2'};
    final shotServices = buildServices(
      challenges: [storyCopy, openCopy],
      details: shotDetails,
      progress: progress,
      places: MemoryPlaceCatalog(samplePlaces()),
      routing: MemoryRoutingClient(),
      elevation: MemoryElevationLookup(),
      deviceLocation: MemoryDeviceLocation(),
    );
    for (final locale in ['cs', 'en', 'de']) {
      final strings = AppStrings(locale);
      for (final width in [390.0, 1280.0]) {
        final tag = '$locale-${width.round()}';
        useView(tester, Size(width, width < 600 ? 844 : 900));
        await resetTree();
        await tester.pumpWidget(
          wrapApp(shotServices, locale: LocaleController(initial: locale)),
        );
        await tester.pumpAndSettle();
        await shot('home-$tag');
        await _pumpThumbPair(
          tester,
          locale: locale,
          portrait: openCopy,
          landscape: storyCopy,
        );
        await shot('home-cards-$tag');
        await tester.pumpWidget(
          wrapApp(shotServices, locale: LocaleController(initial: locale)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(strings.navProfile));
        await tester.pumpAndSettle();
        await shot('profile-$tag');
        final completedDate = find.byKey(
          const Key('profile-completed-date-open-1'),
        );
        if (completedDate.evaluate().isNotEmpty) {
          final dateRect = tester.getRect(completedDate);
          final viewHeight = tester.view.physicalSize.height;
          if (dateRect.top < 0 || dateRect.bottom > viewHeight - 8) {
            await tester.ensureVisible(completedDate);
            await tester.pumpAndSettle();
            await shot('profile-date-$tag');
          }
        }

        await tester.tap(find.text(strings.navMap));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await shot('map-$tag');
        expect(find.byKey(const Key('map-plan-route')), findsNothing);
        await tester.enterText(
          find.byKey(const Key('map-search-field')),
          'Karl',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('map-search-karlstejn')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-poi-sheet')), findsOneWidget);
        expect(find.text(strings.planRoute), findsOneWidget);
        if (width == 390 && (locale == 'cs' || locale == 'en')) {
          await shot('map-popup-$tag');
        }
        await tester.tap(find.byKey(const Key('map-poi-add-route')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map-route-panel')), findsOneWidget);
        expect(find.byKey(const Key('route-mode-toggle')), findsOneWidget);
        expect(find.byKey(const Key('route-hike-stats')), findsOneWidget);
        expect(find.text(strings.routeModeWalk), findsOneWidget);
        expect(find.text(strings.routeModeBike), findsOneWidget);
        await shot('map-route-$tag');

        await tester.tap(find.text(strings.catalogTitle));
        await tester.pumpAndSettle();
        final heroCard = find.byKey(const Key('catalog-hero-story-1'));
        await tester.ensureVisible(heroCard);
        await tester.pumpAndSettle();
        await tester.tap(heroCard);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('challenge-title')), findsOneWidget);
        expect(find.byKey(const Key('challenge-back')), findsOneWidget);
        expect(find.byKey(const Key('challenge-hero-photo')), findsOneWidget);
        expect(
          find.byKey(const Key('challenge-hero-letterbox')),
          findsNothing,
          reason:
              'hero ${tester.getSize(find.byKey(const Key('challenge-hero-expanded')))} '
              'view ${tester.view.physicalSize}',
        );
        await shot('hero-$tag');
        await _revealInChallenge(tester, const Key('challenge-description'));
        await tester.pumpAndSettle();
        final mapRect = tester.getRect(find.byType(ChallengeMap));
        final descriptionRect = tester.getRect(
          find.byKey(const Key('challenge-description')),
        );
        expect(mapRect.bottom, lessThanOrEqualTo(descriptionRect.top + 1));
        if (locale == 'cs') await shot('order-$tag');
        await shot('description-$tag');
        await _revealInChallenge(tester, const Key('challenge-pay-ctas'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            strings.payCtaAmount(
              strings.payDigitalDiploma,
              formatChallengePrice(499, 'eur', locale)!,
            ),
          ),
          findsWidgets,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('challenge-pay-heading')))
              .textAlign,
          TextAlign.center,
        );
        await shot('pay-inline-$tag');
        await tester.drag(
          find.byKey(const Key('challenge-feed-scroll')),
          const Offset(0, -240),
        );
        await tester.pump();
        await shot('hero-collapsed-$tag');
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
        expect(find.text(strings.joinChallenge), findsWidgets);
        expect(
          find.byKey(const Key('challenge-paybar-heading')),
          findsOneWidget,
        );
        await shot('paybar-$tag');
      }
    }

    for (final locale in ['cs', 'en']) {
      useView(tester, const Size(390, 844));
      await resetTree();
      final story = sampleStoryChallenge(
        coverImageUrl: 'asset://assets/challenges/beskydy-autumn.jpg',
      );
      final purchases = MemoryPurchases(
        completeOnRefresh: false,
        purchases: {
          story.challenge.id: Purchase(
            challengeId: story.challenge.id,
            status: PurchaseStatus.pending,
            rewardVariant: RewardVariant.diploma,
          ),
        },
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LocaleController(initial: locale),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  LastOpenedChallengeStore(initialId: story.challenge.id),
            ),
            Provider.value(
              value: buildServices(
                challenges: [story.challenge],
                details: [story],
                purchases: purchases,
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: ChallengeScreen(challengeId: story.challenge.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _revealInChallenge(tester, const Key('challenge-pay-pending'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings(locale).purchasePending), findsOneWidget);
      await shot('pending-$locale-390');
    }

    final previousProvider = diplomaImageProvider;
    diplomaImageProvider = (_) => MemoryImage(Uint8List.fromList(_shotPng));
    addTearDown(() => diplomaImageProvider = previousProvider);
    final diplomaServices = buildServices(
      diplomas: MemoryDiplomaClient(
        accessState: 'ready',
        imageUrl: 'https://example.test/diploma.png',
        completionLabel: 'dokončeno dne 7. 9. 2026',
      ),
    );
    for (final locale in ['cs', 'en']) {
      for (final frame in const [
        (name: 'sheet', size: Size(390, 844)),
        (name: 'dialog', size: Size(1280, 900)),
      ]) {
        useView(tester, frame.size);
        await resetTree();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => LocaleController(initial: locale),
              ),
              Provider.value(value: diplomaServices),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: () => showDiplomaWindow(context, 'open-1'),
                        child: const Text('open-diploma'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('open-diploma'));
        await tester.pumpAndSettle();
        await shot('diploma-${frame.name}-$locale');
      }
    }
    debugDisableShadows = true;
  });

  testWidgets('hero and place sheet frames', (tester) async {
    await tester.runAsync(loadFonts);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final story = sampleStoryChallenge(
      coverImageUrl: 'asset://assets/challenges/beskydy-autumn.jpg',
    );
    final open = sampleOpenChallenge();
    for (final frame in const [
      Size(412, 900),
      Size(1280, 900),
      Size(1920, 1080),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = frame;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LocaleController(initial: 'cs'),
            ),
            ChangeNotifierProvider(
              create: (_) => LastOpenedChallengeStore(initialId: 'story-1'),
            ),
            Provider.value(
              value: buildServices(
                challenges: [open.challenge, story.challenge],
                details: [open, story],
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const ChallengeScreen(challengeId: 'story-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await saveShot(tester, 'detail-hero-${frame.width.round()}.png');
    }

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      wrapApp(
        buildServices(
          places: MemoryPlaceCatalog(samplePlaces()),
          routing: MemoryRoutingClient(),
          elevation: MemoryElevationLookup(),
          deviceLocation: MemoryDeviceLocation(),
        ),
        locale: LocaleController(initial: 'cs'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('map-search-field')), 'Karl');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('map-search-karlstejn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-poi-close')), findsOneWidget);
    expect(find.text(AppStrings('cs').cancelRoute), findsNothing);
    await saveShot(tester, 'detail-map-sheet-cs.png');
    debugDisableShadows = true;
  });

  testWidgets('challenge cta panel frames', (tester) async {
    await tester.runAsync(loadFonts);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> resetTree() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    final story = sampleStoryChallenge(
      coverImageUrl: 'asset://assets/challenges/beskydy-autumn.jpg',
    );
    final open = sampleOpenChallenge();
    const photo = AssetImage('assets/challenges/beskydy-autumn.jpg');

    Widget detailPage(String locale) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: locale),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                LastOpenedChallengeStore(initialId: story.challenge.id),
          ),
          Provider.value(
            value: buildServices(
              challenges: [story.challenge, open.challenge],
              details: [story, open],
              places: const MemoryPlaceCatalog([]),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ChallengeScreen(challengeId: 'story-1'),
        ),
      );
    }

    Future<void> revealFloatingPanel() async {
      final feed = find.byKey(const Key('challenge-feed-scroll'));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: feed, matching: find.byType(Scrollable)).first,
      );
      final position = scrollable.position;
      if (position.maxScrollExtent > 0) {
        position.jumpTo(position.maxScrollExtent);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    Future<void> backdrop({
      required Size size,
      required String locale,
      required Widget background,
      required String name,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await resetTree();
      final strings = AppStrings(locale);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            extendBody: true,
            body: background,
            bottomNavigationBar: ShellBottomSurface(
              shown: true,
              panel: ChallengeCtaPanel(
                heading: strings.joinChallenge,
                diplomaLabel: strings.payDigitalDiploma,
                medalLabel: strings.payMedalAndDiploma,
                loadingLabel: strings.buttonLoading,
                onDiploma: () {},
                onMedal: () {},
              ),
              nav: const SizedBox(key: Key('app-bottom-nav'), height: 64),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => precacheImage(photo, tester.element(find.byType(Scaffold))),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.joinChallenge), findsOneWidget);
      await saveShot(tester, name);
    }

    final previousError = FlutterError.onError;
    FlutterError.onError = (details) {
      if ('${details.exception}'.contains('PlacesMapController')) return;
      previousError?.call(details);
    };
    try {
      for (final locale in ['cs', 'en', 'de']) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        await resetTree();
        await tester.pumpWidget(detailPage(locale));
        await tester.pumpAndSettle();
        await revealFloatingPanel();
        expect(
          tester
              .widget<SizeTransition>(
                find.byKey(const Key('challenge-cta-size')),
              )
              .sizeFactor
              .value,
          1,
          reason: 'floating panel at 390 $locale',
        );
        await saveShot(tester, 'detail-cta-$locale-390.png');
      }

      // At 1280 the in-page block stays on screen, so the hide rule keeps
      // the floating panel down. These frames still show it at that width.
      for (final locale in ['cs', 'en', 'de']) {
        await backdrop(
          size: const Size(1280, 900),
          locale: locale,
          background: const Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(image: photo, fit: BoxFit.cover),
                  ),
                ),
              ),
              Expanded(child: ColoredBox(color: BrandColors.cream)),
            ],
          ),
          name: 'detail-cta-$locale-1280.png',
        );
      }

      await backdrop(
        size: const Size(390, 844),
        locale: 'de',
        background: const DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(image: photo, fit: BoxFit.cover),
          ),
        ),
        name: 'detail-cta-over-photo-de-390.png',
      );
      await backdrop(
        size: const Size(390, 844),
        locale: 'cs',
        background: const ColoredBox(color: BrandColors.cream),
        name: 'detail-cta-over-light-cs-390.png',
      );
      await backdrop(
        size: const Size(1280, 900),
        locale: 'de',
        background: const DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(image: photo, fit: BoxFit.cover),
          ),
        ),
        name: 'detail-cta-over-photo-de-1280.png',
      );
    } finally {
      FlutterError.onError = previousError;
      debugDisableShadows = true;
    }
  });
}

/// Brings a challenge block on screen. Below the map it starts offstage, so
/// the feed has to scroll before [WidgetTester.ensureVisible] can see it.
/// On a wide layout the block lives under the side map and is already shown.
Future<void> _revealInChallenge(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('challenge-feed-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
}

Future<void> _loadFamily(
  String family,
  List<String> paths, {
  bool fromBundle = false,
}) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final Future<ByteData> data = fromBundle
        ? rootBundle.load(path)
        : _fileBytes(path);
    loader.addFont(data);
  }
  await loader.load();
}

Future<ByteData> _fileBytes(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(Uint8List.fromList(bytes));
}

Challenge _shotChallenge(
  Challenge source, {
  required List<LocalizedText> translations,
  CatalogDifficulty? difficulty,
  ChallengeLength? length,
  String? region,
  String? coverImageUrl,
}) {
  return Challenge(
    id: source.id,
    slug: source.slug,
    accessMode: source.accessMode,
    pricingType: source.pricingType,
    priceCents: source.priceCents,
    diplomaPriceCents: source.diplomaPriceCents,
    medalPriceCents: source.medalPriceCents,
    currency: source.currency,
    status: source.status,
    countryCode: source.countryCode,
    region: region ?? source.region,
    coverImageUrl: coverImageUrl ?? source.coverImageUrl,
    fapiFormUrlDiploma: source.fapiFormUrlDiploma,
    fapiFormUrlMedal: source.fapiFormUrlMedal,
    difficulty: difficulty ?? source.difficulty,
    length: length ?? source.length,
    translations: translations,
  );
}

Future<void> _pumpThumbPair(
  WidgetTester tester, {
  required String locale,
  required Challenge portrait,
  required Challenge landscape,
}) async {
  final width = tester.view.physicalSize.width;
  final card = width >= 600 ? 280.0 : (width - 48) / 2;
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LocaleController(initial: locale),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: card / (4 / 3) + 148,
                  child: CatalogFeaturedCard(
                    challenge: portrait,
                    onTap: () {},
                    width: card,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: card / (4 / 3) + 148,
                  child: CatalogFeaturedCard(
                    challenge: landscape,
                    onTap: () {},
                    width: card,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> saveShot(WidgetTester tester, String name) async {
  await tester.pump();
  goldenFileComparator = _ArtifactGolden();
  await expectLater(find.byType(MaterialApp).first, matchesGoldenFile(name));
}

const _shotPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  15,
  162,
  131,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

class _ArtifactGolden extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final name = golden.pathSegments.isEmpty
        ? golden.toString()
        : golden.pathSegments.last;
    final file = File('/opt/cursor/artifacts/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes, flush: true);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    return compare(imageBytes, golden);
  }
}
