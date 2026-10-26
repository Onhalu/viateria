import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/layout/map_search_metrics.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/app_shell.dart';
import 'package:viateria/ui/widgets/challenge_cta_panel.dart';
import 'package:viateria/ui/widgets/shell_bottom_surface.dart';

import 'challenge_reward_test.dart';
import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double extent(WidgetTester tester) {
    return tester
        .widget<SizeTransition>(find.byKey(const Key('challenge-cta-size')))
        .sizeFactor
        .value;
  }

  Future<void> pumpSurface(
    WidgetTester tester, {
    required Size size,
    String locale = 'cs',
    bool shown = true,
    bool disableAnimations = false,
    double textScale = 1,
    double safeBottom = 0,
    Color? navFill,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(bottom: safeBottom);
    tester.view.viewPadding = FakeViewPadding(bottom: safeBottom);
    final strings = AppStrings(locale);
    final panel = ChallengeCtaPanel(
      heading: strings.joinChallenge,
      diplomaLabel: strings.payDigitalDiploma,
      medalLabel: strings.payMedalAndDiploma,
      loadingLabel: strings.buttonLoading,
      onDiploma: () {},
      onMedal: () {},
      navFill: navFill ?? BrandColors.shellFill,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            var media = MediaQuery.of(context);
            if (disableAnimations) {
              media = media.copyWith(disableAnimations: true);
            }
            if (textScale != 1) {
              media = media.copyWith(textScaler: TextScaler.linear(textScale));
            }
            return MediaQuery(
              data: media,
              child: Scaffold(
                extendBody: true,
                body: const ColoredBox(
                  color: BrandColors.neutral,
                  child: SizedBox.expand(),
                ),
                bottomNavigationBar: ShellBottomSurface(
                  shown: shown,
                  panel: panel,
                  nav: const SizedBox(
                    key: Key('app-bottom-nav'),
                    height: AppShell.barHeight,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  test('olive nav clears WCAG AA for the heading and both labels', () {
    final chrome = ChallengeCtaChrome.resolve(BrandColors.shellFill);
    expect(chrome.fill, BrandColors.shellFill);
    expect(chrome.fill.a, 1);
    expect(chrome.tone, NavFillTone.mid);
    expect(chrome.heading, BrandColors.cream);
    expect(chrome.medalFill, BrandColors.forest);
    expect(chrome.medalLabel, BrandColors.cream);
    expect(chrome.diplomaFill, BrandColors.cream);
    expect(chrome.diplomaLabel, BrandColors.forest);
    expect(chrome.medalSide.color, BrandColors.cream.withValues(alpha: 0.30));
    expect(chrome.medalSide.width, 1);
    expect(chrome.diplomaSide.color, BrandColors.forest);
    expect(chrome.fill, isNot(BrandColors.sage));
    expect(chrome.heading, isNot(BrandColors.sage));

    final heading = contrastRatio(chrome.heading, chrome.fill);
    final medal = contrastRatio(chrome.medalLabel, chrome.medalFill);
    final diploma = contrastRatio(chrome.diplomaLabel, chrome.diplomaFill);
    expect(heading, greaterThanOrEqualTo(3), reason: 'heading $heading');
    expect(medal, greaterThanOrEqualTo(4.5), reason: 'medal $medal');
    expect(diploma, greaterThanOrEqualTo(4.5), reason: 'diploma $diploma');
    expect(heading, closeTo(3.17, 0.02));
    expect(medal, closeTo(8.53, 0.02));
    expect(diploma, closeTo(8.53, 0.02));

    final washed = ChallengeCtaChrome.resolve(
      BrandColors.shellFill.withValues(alpha: 0.5),
    );
    expect(washed.fill.a, greaterThanOrEqualTo(0.96));

    final light = ChallengeCtaChrome.resolve(BrandColors.cream);
    expect(light.tone, NavFillTone.light);
    expect(light.heading, BrandColors.forest);
    expect(light.medalFill, BrandColors.forest);
    expect(light.diplomaSide.color, BrandColors.forest);
    expect(
      contrastRatio(light.heading, light.fill),
      greaterThanOrEqualTo(3),
    );

    final dark = ChallengeCtaChrome.resolve(BrandColors.forest);
    expect(dark.tone, NavFillTone.dark);
    expect(dark.heading, BrandColors.cream);
    expect(dark.medalFill, BrandColors.cream);
    expect(dark.medalLabel, BrandColors.forest);
    expect(dark.diplomaLabel, BrandColors.cream);
    expect(
      contrastRatio(dark.diplomaLabel, dark.fill),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('the open bar is one olive surface with a single upward shadow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await pumpSurface(tester, size: const Size(390, 844));

    expect(find.byType(BackdropFilter), findsNothing);
    final shell = tester.widget<Material>(
      find.byKey(const Key('app-bottom-nav-shell')),
    );
    expect(shell.color, BrandColors.shellFill);
    expect(shell.color, const Color(0xFF7D8B6A));
    expect(shell.elevation, 0);
    final shape = shell.shape! as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(ChallengeCtaPanel.topRadius),
        topRight: Radius.circular(ChallengeCtaPanel.topRadius),
        bottomLeft: Radius.circular(AppShell.barRadius),
        bottomRight: Radius.circular(AppShell.barRadius),
      ),
    );
    final shadow = tester.widget<DecoratedBox>(
      find.byKey(const Key('shell-bottom-shadow')),
    );
    final decoration = shadow.decoration as BoxDecoration;
    expect(decoration.boxShadow, hasLength(1));
    expect(decoration.boxShadow!.single, ChallengeCtaPanel.mergedShadow);
    expect(decoration.boxShadow!.single.color, const Color(0x1F35483C));
    expect(decoration.boxShadow!.single.offset, const Offset(0, -4));
    expect(decoration.boxShadow!.single.blurRadius, 24);

    expect(
      tester
          .widget<Padding>(find.byKey(const Key('challenge-cta-padding')))
          .padding,
      const EdgeInsets.fromLTRB(
        kNavSideInset,
        ChallengeCtaPanel.padTop,
        kNavSideInset,
        ChallengeCtaPanel.padAboveHairline,
      ),
    );

    final heading = tester.widget<Text>(
      find.byKey(const Key('challenge-paybar-heading')),
    );
    expect(heading.data, 'Přijmi výzvu');
    expect(heading.textAlign, TextAlign.center);
    expect(heading.style?.fontFamily, AppTheme.displayFont);
    expect(heading.style?.fontWeight, FontWeight.w700);
    expect(heading.style?.fontSize, 20);
    expect(heading.style?.height, 26 / 20);
    expect(heading.style?.color, BrandColors.cream);
    expect(
      tester.getSize(find.byKey(const Key('challenge-paybar-heading'))).height,
      closeTo(26, 0.5),
    );

    final diploma = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const Key('challenge-floating-pay-diploma')),
        matching: find.byType(OutlinedButton),
      ),
    );
    final medal = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('challenge-floating-pay-medal')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(diploma.style?.backgroundColor?.resolve(const {}), BrandColors.cream);
    expect(
      diploma.style?.foregroundColor?.resolve(const {}),
      BrandColors.forest,
    );
    expect(
      diploma.style?.side?.resolve(const {}),
      const BorderSide(color: BrandColors.forest, width: 1.5),
    );
    expect(medal.style?.backgroundColor?.resolve(const {}), BrandColors.forest);
    expect(medal.style?.foregroundColor?.resolve(const {}), BrandColors.cream);
    expect(
      medal.style?.side?.resolve(const {}),
      BorderSide(color: BrandColors.cream.withValues(alpha: 0.30), width: 1),
    );
    expect(find.text('Digitální diplom'), findsOneWidget);
    expect(find.text('Medaile + diplom'), findsOneWidget);
    expect(find.textContaining('Kč'), findsNothing);
    expect(find.textContaining('€'), findsNothing);

    final panel = tester.getRect(find.byKey(const Key('challenge-cta-panel')));
    final nav = tester.getRect(find.byKey(const Key('app-bottom-nav')));
    expect(panel.left, closeTo(kNavSideInset, 1));
    expect(panel.right, closeTo(390 - kNavSideInset, 1));
    expect(nav.left, closeTo(panel.left, 0.5));
    expect(nav.right, closeTo(panel.right, 0.5));
    expect(nav.top - panel.bottom, closeTo(0, 0.5));
    final hairline = tester.getRect(
      find.byKey(const Key('challenge-cta-hairline')),
    );
    expect(hairline.height, closeTo(1, 0.1));
    expect(hairline.left - panel.left, closeTo(ChallengeCtaPanel.hairlineInset, 0.5));
    expect(panel.right - hairline.right, closeTo(ChallengeCtaPanel.hairlineInset, 0.5));
    expect(panel.bottom - hairline.bottom, closeTo(0, 0.5));
  });

  testWidgets('a closed bar keeps today\'s pill: radius 28 and elevation 3', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await pumpSurface(tester, size: const Size(390, 844), shown: false);

    final closedShadow = tester.widget<DecoratedBox>(
      find.byKey(const Key('shell-bottom-shadow')),
    );
    expect((closedShadow.decoration as BoxDecoration).boxShadow, isEmpty);
    final shell = tester.widget<Material>(
      find.byKey(const Key('app-bottom-nav-shell')),
    );
    expect(shell.elevation, 3);
    expect(shell.color, BrandColors.shellFill);
    expect(shell.shadowColor, BrandColors.shellShadow);
    expect(
      (shell.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppShell.barRadius),
    );
    expect(extent(tester), 0);
    expect(
      tester.widget<IgnorePointer>(find.byKey(const Key('challenge-cta-motion'))).ignoring,
      isTrue,
    );
  });

  testWidgets('buttons share a row from 340 and stack below it', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await pumpSurface(tester, size: const Size(340, 700), locale: 'de');
    expect(
      tester.widget(find.byKey(const Key('challenge-floating-pay-ctas'))),
      isA<Row>(),
    );
    final rowDiploma = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-diploma')),
    );
    final rowMedal = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-medal')),
    );
    expect(rowMedal.left - rowDiploma.right, ChallengeCtaPanel.rowGap);
    expect(rowDiploma.width, closeTo(rowMedal.width, 0.5));
    expect(find.text('Nimm die Herausforderung an'), findsOneWidget);
    expect(find.text('Digitales Diplom'), findsOneWidget);
    expect(find.text('Medaille + Diplom'), findsOneWidget);

    await pumpSurface(tester, size: const Size(700, 800), locale: 'en');
    final panel = tester.getRect(find.byKey(const Key('challenge-cta-panel')));
    final nav = tester.getRect(find.byKey(const Key('app-bottom-nav')));
    expect(panel.width, closeTo(nav.width, 0.5));
    final content = tester.getSize(
      find.byKey(const Key('challenge-cta-content')),
    );
    expect(content.width, closeTo(ChallengeCtaPanel.contentMaxWidth, 1));
    expect(
      tester.getCenter(find.byKey(const Key('challenge-cta-content'))).dx,
      closeTo(panel.center.dx, 1),
    );

    await pumpSurface(tester, size: const Size(339, 700), locale: 'de');
    expect(
      tester.widget(find.byKey(const Key('challenge-floating-pay-ctas'))),
      isA<Column>(),
    );
    final stackedDiploma = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-diploma')),
    );
    final stackedMedal = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-medal')),
    );
    expect(stackedDiploma.bottom, lessThan(stackedMedal.top));
    expect(
      stackedMedal.top - stackedDiploma.bottom,
      closeTo(ChallengeCtaPanel.stackGap, 0.5),
    );
    expect(stackedDiploma.width, closeTo(stackedMedal.width, 0.5));
  });

  testWidgets('German labels at text scale 1.3 sit above a 34 dp inset', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await pumpSurface(
      tester,
      size: const Size(390, 844),
      locale: 'de',
      textScale: 1.3,
      safeBottom: 34,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Nimm die Herausforderung an'), findsOneWidget);
    expect(find.text('Digitales Diplom'), findsOneWidget);
    expect(find.text('Medaille + Diplom'), findsOneWidget);
    final nav = tester.getRect(find.byKey(const Key('app-bottom-nav')));
    final panel = tester.getRect(find.byKey(const Key('challenge-cta-panel')));
    expect(nav.top - panel.bottom, closeTo(0, 0.5));
    expect(844 - nav.bottom, closeTo(34 + AppShell.bottomInset, 1));
    expect(panel.bottom, greaterThan(nav.top - 1));
  });

  testWidgets('offset hysteresis shows once and does not flicker on a fling', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 400);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const _OffsetPayBar(),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final state = tester.state<_OffsetPayBarState>(find.byType(_OffsetPayBar));
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;

    double viewport() => position.viewportDimension;

    position.jumpTo(viewport() * 0.45);
    await tester.pump();
    expect(state.visible, isFalse);
    expect(extent(tester), 0);

    position.jumpTo(viewport() * 0.5);
    await tester.pump();
    expect(state.visible, isTrue);
    expect(extent(tester), 1);

    position.jumpTo(viewport() * 0.45);
    await tester.pump();
    expect(state.visible, isTrue, reason: 'still inside the 0.4–0.5 band');
    expect(extent(tester), 1);

    position.jumpTo(viewport() * 0.39);
    await tester.pump();
    expect(state.visible, isFalse);
    expect(extent(tester), 0);
    expect(state.changes, [true, false]);

    state.changes.clear();
    await tester.fling(find.byType(ListView), const Offset(0, -4000), 6000);
    await tester.pumpAndSettle();
    expect(state.changes, [true]);
    expect(state.visible, isTrue);

    await tester.fling(find.byType(ListView), const Offset(0, 4000), 6000);
    await tester.pumpAndSettle();
    expect(state.changes, [true, false]);
    expect(state.visible, isFalse);
  });

  testWidgets('show eases out in 240 ms and hide eases in in 180 ms', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const MaterialApp(home: _ToggleSurface()));
    await tester.pump();
    expect(extent(tester), 0);

    tester.state<_ToggleSurfaceState>(find.byType(_ToggleSurface)).show(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = extent(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(extent(tester), 1);

    tester.state<_ToggleSurfaceState>(find.byType(_ToggleSurface)).show(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final hiding = extent(tester);
    expect(hiding, greaterThan(0));
    expect(hiding, lessThan(1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(extent(tester), 0);
  });

  testWidgets('reduced motion snaps the panel without waiting', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: const _ToggleSurface(),
      ),
    );
    await tester.pump();
    expect(extent(tester), 0);
    tester.state<_ToggleSurfaceState>(find.byType(_ToggleSurface)).show(true);
    await tester.pump();
    expect(extent(tester), 1);
    tester.state<_ToggleSurfaceState>(find.byType(_ToggleSurface)).show(false);
    await tester.pump();
    expect(extent(tester), 0);
  });

  testWidgets('a paid challenge keeps the panel hidden after scrolling', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    useView(tester, width: 390, height: 844);
    final story = sampleStoryChallenge();
    final purchases = MemoryPurchases()..pay(story.challenge.id);
    await tester.pumpWidget(
      wrapScreen(
        buildServices(detail: story, purchases: purchases),
        locale: 'cs',
        challengeId: story.challenge.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenge-cta-panel')), findsNothing);
    expect(find.byKey(const Key('challenge-floating-pay-diploma')), findsNothing);
    expect(find.text('Digitální diplom'), findsNothing);
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
    expect(find.byKey(const Key('challenge-cta-panel')), findsNothing);
    expect(find.byKey(const Key('challenge-sticky-cta')), findsNothing);
  });

  testWidgets('a fast fling on the detail feed does not flicker the bar', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    useView(tester, width: 390, height: 700);
    final story = sampleStoryChallenge();
    await tester.pumpWidget(
      _liveScreen(
        buildServices(detail: story),
        locale: 'de',
        challengeId: story.challenge.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(extent(tester), 0);

    final samples = <double>[];
    await tester.fling(
      find.byKey(const Key('challenge-feed-scroll')),
      const Offset(0, -3000),
      5000,
    );
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      samples.add(extent(tester));
    }
    await tester.pumpAndSettle();
    expect(samples.last, 1);
    expect(_flickerCount(samples), 0);

    final back = <double>[];
    await tester.fling(
      find.byKey(const Key('challenge-feed-scroll')),
      const Offset(0, 3000),
      5000,
    );
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      back.add(extent(tester));
    }
    await tester.pumpAndSettle();
    expect(extent(tester), 0);
    expect(_flickerCount(back), 0);
    expect(tester.takeException(), isNull);
  });
}

/// Counts times the factor reverses direction after it has left zero.
int _flickerCount(List<double> samples) {
  var reversals = 0;
  double? previous;
  var direction = 0;
  for (final value in samples) {
    if (previous == null) {
      previous = value;
      continue;
    }
    final delta = value - previous;
    previous = value;
    if (delta.abs() < 0.001) continue;
    final next = delta > 0 ? 1 : -1;
    if (direction != 0 && next != direction) reversals++;
    direction = next;
  }
  return reversals;
}

Widget _liveScreen(
  AppServices services, {
  required String locale,
  required String challengeId,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LocaleController(initial: locale),
      ),
      ChangeNotifierProvider(
        create: (_) => LastOpenedChallengeStore(initialId: challengeId),
      ),
      Provider<AppServices>.value(value: services),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: ChallengeScreen(challengeId: challengeId),
    ),
  );
}

class _ToggleSurface extends StatefulWidget {
  const _ToggleSurface();

  @override
  State<_ToggleSurface> createState() => _ToggleSurfaceState();
}

class _ToggleSurfaceState extends State<_ToggleSurface> {
  var _shown = false;

  void show(bool value) => setState(() => _shown = value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: ShellBottomSurface(
        shown: _shown,
        panel: ChallengeCtaPanel(
          heading: 'Přijmi výzvu',
          diplomaLabel: 'Digitální diplom',
          medalLabel: 'Medaile + diplom',
          onDiploma: () {},
          onMedal: () {},
        ),
        nav: const SizedBox(key: Key('app-bottom-nav'), height: 64),
      ),
    );
  }
}

/// Scroll offset drives the panel through [paymentBarShouldShow].
class _OffsetPayBar extends StatefulWidget {
  const _OffsetPayBar();

  @override
  State<_OffsetPayBar> createState() => _OffsetPayBarState();
}

class _OffsetPayBarState extends State<_OffsetPayBar> {
  final _scroll = ScrollController();
  final changes = <bool>[];
  var visible = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasViewportDimension) return;
    final next = paymentBarShouldShow(
      currentlyVisible: visible,
      offset: position.pixels,
      viewport: position.viewportDimension,
    );
    if (next == visible) return;
    visible = next;
    changes.add(next);
    setState(() {});
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        controller: _scroll,
        itemCount: 80,
        itemExtent: 80,
        itemBuilder: (context, index) => Text('row $index'),
      ),
      bottomNavigationBar: ShellBottomSurface(
        shown: visible,
        panel: ChallengeCtaPanel(
          heading: 'Přijmi výzvu',
          diplomaLabel: 'Digitální diplom',
          medalLabel: 'Medaile + diplom',
          onDiploma: () {},
          onMedal: () {},
        ),
        nav: const SizedBox(key: Key('app-bottom-nav'), height: 64),
      ),
    );
  }
}
