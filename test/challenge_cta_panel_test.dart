import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/challenge_cta_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPanel(
    WidgetTester tester, {
    required Size size,
    String locale = 'cs',
    bool shown = true,
    bool disableAnimations = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final strings = AppStrings(locale);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            final media = disableAnimations
                ? MediaQuery.of(context).copyWith(disableAnimations: true)
                : MediaQuery.of(context);
            return MediaQuery(
              data: media,
              child: Scaffold(
                body: Stack(
                  children: [
                    const ColoredBox(
                      color: BrandColors.neutral,
                      child: SizedBox.expand(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ChallengeCtaPanelMotion(
                        shown: shown,
                        child: ChallengeCtaPanelBar(
                          heading: strings.joinChallenge,
                          diplomaLabel: strings.payDigitalDiploma,
                          medalLabel: strings.payMedalAndDiploma,
                          loadingLabel: strings.buttonLoading,
                          onDiploma: () {},
                          onMedal: () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the panel is sage glass with one forest shadow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPanel(tester, size: const Size(390, 844));

    final shadow = tester.widget<DecoratedBox>(
      find.byKey(const Key('challenge-cta-shadow')),
    );
    final shadowDecoration = shadow.decoration as BoxDecoration;
    expect(shadowDecoration.boxShadow, hasLength(1));
    expect(shadowDecoration.boxShadow!.single.color, const Color(0x2E35483C));
    expect(shadowDecoration.boxShadow!.single.blurRadius, 24);
    expect(shadowDecoration.boxShadow!.single.offset, const Offset(0, 8));
    expect(shadowDecoration.boxShadow!.single.color, isNot(Colors.black));
    expect(
      shadowDecoration.borderRadius,
      const BorderRadius.all(Radius.circular(24)),
    );

    final clip = tester.widget<ClipRRect>(
      find.byKey(const Key('challenge-cta-clip')),
    );
    expect(clip.borderRadius, const BorderRadius.all(Radius.circular(24)));

    final blur = tester.widget<BackdropFilter>(
      find.byKey(const Key('challenge-cta-blur')),
    );
    expect('${blur.filter}', contains('20.0'));

    final fill = tester.widget<DecoratedBox>(
      find.byKey(const Key('challenge-cta-fill')),
    );
    final fillDecoration = fill.decoration as BoxDecoration;
    expect(fillDecoration.color, ChallengeCtaPanel.fill);
    expect(fillDecoration.color, const Color(0xE69C9A7B));
    expect(
      fillDecoration.borderRadius,
      const BorderRadius.all(Radius.circular(24)),
    );
    final side = (fillDecoration.border! as Border).top;
    expect(side.width, 1);
    expect(side.color, BrandColors.cream.withValues(alpha: 0.40));

    expect(
      tester
          .widget<Padding>(find.byKey(const Key('challenge-cta-padding')))
          .padding,
      const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
    expect(heading.style?.color, BrandColors.forest);
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
    expect(
      diploma.style?.backgroundColor?.resolve(const {}),
      BrandColors.cream,
    );
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
    expect(find.text('Digitální diplom'), findsOneWidget);
    expect(find.text('Medaile + diplom'), findsOneWidget);
    expect(find.textContaining('Kč'), findsNothing);
    expect(find.textContaining('€'), findsNothing);

    final panel = tester.getRect(find.byKey(const Key('challenge-cta-panel')));
    expect(panel.left, closeTo(16, 1));
    expect(panel.right, closeTo(390 - 16, 1));
    expect(panel.bottom, closeTo(844 - ChallengeCtaPanel.aboveNav, 1));
  });

  testWidgets('buttons share a row from 360 and stack below it', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPanel(tester, size: const Size(360, 700), locale: 'de');
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

    await pumpPanel(tester, size: const Size(500, 800), locale: 'en');
    final wideDiploma = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-diploma')),
    );
    final wideMedal = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-medal')),
    );
    expect(wideDiploma.width, closeTo(wideMedal.width, 0.5));
    expect(wideDiploma.width, greaterThan(168));
    expect(wideMedal.left - wideDiploma.right, ChallengeCtaPanel.rowGap);

    await pumpPanel(tester, size: const Size(359, 700), locale: 'de');
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
    expect(
      tester.getSize(find.byKey(const Key('challenge-paybar-heading'))).height,
      closeTo(ChallengeCtaPanel.headingLineHeight * 2, 1),
    );
  });

  testWidgets('from 600 dp the panel is 560 wide and 16 dp off the bottom', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPanel(tester, size: const Size(1280, 800), locale: 'de');
    final panel = tester.getRect(find.byKey(const Key('challenge-cta-panel')));
    expect(panel.width, closeTo(ChallengeCtaPanel.maxWidth, 1));
    expect(panel.center.dx, closeTo(640, 1));
    expect(panel.bottom, closeTo(800 - ChallengeCtaPanel.restingBottom, 1));
    expect(
      tester.widget(find.byKey(const Key('challenge-floating-pay-ctas'))),
      isA<Row>(),
    );
  });

  testWidgets('the panel stays hidden while the inline block is 30% visible', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    Future<void> show(bool shown) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ChallengeCtaPanelMotion(
                    shown: shown,
                    child: ChallengeCtaPanelBar(
                      heading: 'Přijmi výzvu',
                      diplomaLabel: 'Digitální diplom',
                      medalLabel: 'Medaile + diplom',
                      onDiploma: () => taps++,
                      onMedal: () => taps++,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hidden = floatingPayBarShouldShow(
      scrolledEnough: true,
      inlineVisibleFraction: inlinePayHideFraction,
      suppressed: false,
      paid: false,
    );
    expect(hidden, isFalse);
    expect(inlinePayHideFraction, 0.30);
    await show(hidden);
    await tester.pump();
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 1),
    );
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).curve,
      Curves.easeOutCubic,
    );
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
      ChallengeCtaPanel.motionDuration,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const Key('challenge-cta-motion')))
          .ignoring,
      isTrue,
    );
    await tester.tap(
      find.byKey(const Key('challenge-floating-pay-medal')),
      warnIfMissed: false,
    );
    expect(taps, 0);

    final visible = floatingPayBarShouldShow(
      scrolledEnough: true,
      inlineVisibleFraction: inlinePayHideFraction - 0.01,
      suppressed: false,
      paid: false,
    );
    expect(visible, isTrue);
    await show(visible);
    await tester.pump(ChallengeCtaPanel.motionDuration);
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const Key('challenge-cta-motion')))
          .ignoring,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('challenge-floating-pay-diploma')));
    expect(taps, 1);

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
        suppressed: false,
        paid: true,
      ),
      isFalse,
    );
  });

  testWidgets('reduced motion snaps the panel without waiting', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPanel(
      tester,
      size: const Size(390, 844),
      shown: false,
      disableAnimations: true,
    );
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
      Duration.zero,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
      Duration.zero,
    );
  });
}
