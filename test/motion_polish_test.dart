import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/repositories.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/theme/motion_tokens.dart';
import 'package:viateria/ui/motion/brand_spring_switch.dart';
import 'package:viateria/ui/motion/like_save_button.dart';
import 'package:viateria/ui/motion/motion_shake.dart';
import 'package:viateria/ui/motion/spatial_menu.dart';
import 'package:viateria/ui/widgets/app_shell.dart';
import 'package:viateria/ui/widgets/places_map_panels.dart';

import 'auth_register_form_test.dart';
import 'bottom_nav_test.dart';
import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  test('motion tokens stay inside the brand-lock bands', () {
    expect(MotionTokens.fast.inMilliseconds, inInclusiveRange(150, 220));
    expect(
      MotionTokens.switchMotion.inMilliseconds,
      inInclusiveRange(200, 280),
    );
    expect(MotionTokens.tab.inMilliseconds, inInclusiveRange(250, 300));
    expect(MotionTokens.shake.inMilliseconds, closeTo(400, 20));
    expect(MotionTokens.list.inMilliseconds, inInclusiveRange(200, 280));
    expect(MotionTokens.menu.inMilliseconds, inInclusiveRange(180, 220));
    expect(MotionTokens.tabCurve, Curves.easeInOutCubic);
    expect(MotionTokens.shakeAmplitude, inInclusiveRange(6, 8));
    expect(MotionTokens.shakeOscillations, inInclusiveRange(3, 4));
    expect(MotionTokens.likeScaleDown, 0.92);
    expect(MotionTokens.likeScaleUp, 1.08);
    expect(MotionTokens.burstDots, inInclusiveRange(6, 8));
    expect(MotionTokens.burstRadiusFactor, inInclusiveRange(1.2, 1.5));
    expect(MotionTokens.switchOvershoot, inInclusiveRange(0.10, 0.15));
    expect(MotionTokens.menuScaleFrom, 0.96);
    expect(BrandColors.shellFill, const Color(0xFF7D8B6A));
    expect(BrandColors.error, const Color(0xFFBA1A1A));
    expect(BrandColors.sage, const Color(0xFF9C9A7B));
    expect(BrandColors.forest, const Color(0xFF35483C));
    expect(BrandColors.cream, const Color(0xFFF3EFE5));
    expect(BrandColors.neutral, const Color(0xFFFAF8F2));
  });

  testWidgets('bottom nav pill slides on shellFill without recoloring icons', (
    tester,
  ) async {
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    final motion = tester.widget<AnimatedPositioned>(
      find.byKey(const Key('nav-pill-motion')),
    );
    expect(motion.duration, MotionTokens.tab);
    expect(motion.curve, Curves.easeInOutCubic);

    final shell = tester.widget<Material>(
      find.byKey(const Key('app-bottom-nav-shell')),
    );
    expect(shell.color, BrandColors.shellFill);

    final start = tester
        .getTopLeft(find.byKey(const Key('sage-nav-indicator')))
        .dx;
    final pill = tester.widget<Container>(
      find.byKey(const Key('sage-nav-indicator')),
    );
    expect((pill.decoration! as BoxDecoration).color, AppShell.selectedPill);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-bottom-nav')),
        matching: find.text(AppStrings('en').navLastChallenge),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final mid = tester
        .getTopLeft(find.byKey(const Key('sage-nav-indicator')))
        .dx;
    await tester.pumpAndSettle();
    final end = tester
        .getTopLeft(find.byKey(const Key('sage-nav-indicator')))
        .dx;

    expect(end, greaterThan(start + 20));
    expect(mid, greaterThan(start + 4));
    expect(mid, lessThan(end - 4));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.flag)).color,
      BrandColors.cream,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.explore_outlined)).color,
      AppShell.unselectedForeground,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('app-bottom-nav')),
              matching: find.text(AppStrings('en').navLastChallenge),
            ),
          )
          .style
          ?.color,
      BrandColors.cream,
    );
  });

  testWidgets('reduced motion jumps the nav pill', (tester) async {
    _reduce(tester);
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    final motion = tester.widget<AnimatedPositioned>(
      find.byKey(const Key('nav-pill-motion')),
    );
    expect(motion.duration, Duration.zero);

    final start = tester
        .getTopLeft(find.byKey(const Key('sage-nav-indicator')))
        .dx;
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-bottom-nav')),
        matching: find.text(AppStrings('en').navMap),
      ),
    );
    await tester.pump();
    final jumped = tester
        .getTopLeft(find.byKey(const Key('sage-nav-indicator')))
        .dx;
    await tester.pump(const Duration(milliseconds: 280));
    final later = tester
        .getTopLeft(find.byKey(const Key('sage-nav-indicator')))
        .dx;
    expect(jumped, greaterThan(start + 20));
    expect(later, jumped);
  });

  testWidgets('auth bad password shakes and paints the error color', (
    tester,
  ) async {
    final auth = MemoryAuth()
      ..signInError = const AuthFailure('Nesprávné heslo.');
    await pumpAuth(tester, auth: auth);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'nope');
    await tester.tap(find.byKey(const Key('auth-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(_shakeDx(tester, const Key('auth-email')).abs(), greaterThan(4));
    expect(_shakeDx(tester, const Key('auth-password')).abs(), greaterThan(4));
    _expectErrorBorder(tester, const Key('auth-email'));
    _expectErrorBorder(tester, const Key('auth-password'));

    await tester.pumpAndSettle();
    expect(_shakeDx(tester, const Key('auth-email')).abs(), lessThan(0.5));
    final helper = tester.widget<Text>(find.byKey(const Key('auth-error')));
    expect(helper.data, 'Nesprávné heslo.');
    expect(helper.style?.color, BrandColors.error);
    expect(auth.currentUser, isNull);
  });

  testWidgets('reduced motion keeps the auth error still', (tester) async {
    _reduce(tester);
    final auth = MemoryAuth()
      ..signInError = const AuthFailure('Nesprávné heslo.');
    await pumpAuth(tester, auth: auth);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'ada@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'nope');
    await tester.tap(find.byKey(const Key('auth-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(_shakeDx(tester, const Key('auth-email')), 0);
    expect(_shakeDx(tester, const Key('auth-password')), 0);
    _expectErrorBorder(tester, const Key('auth-password'));
    expect(
      tester.widget<Text>(find.byKey(const Key('auth-error'))).style?.color,
      BrandColors.error,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('accessible navigation also skips the shake', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    await tester.pumpWidget(
      wrap(
        reduce: false,
        child: const MotionShake(
          active: true,
          child: SizedBox(key: Key('shaken'), width: 20, height: 20),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    final transform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const Key('shaken')),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.getTranslation().x, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('like save scales through 0.92 and 1.08 with a sage burst', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      wrap(
        child: StatefulBuilder(
          builder: (context, setState) {
            return LikeSaveButton(
              key: const Key('like'),
              saved: saved,
              saveLabel: 'Uložit místo',
              savedLabel: 'Místo je uložené',
              onChanged: (value) => setState(() => saved = value),
            );
          },
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('like'))).shortestSide, 44);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.favorite_border)).color,
      BrandColors.forest,
    );

    await tester.tap(find.byKey(const Key('like')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_iconScale(tester, const Key('like')), closeTo(0.92, 0.03));
    expect(find.byKey(const Key('like-burst')), findsOneWidget);
    expect(find.byKey(const Key('like-burst-dot-6')), findsOneWidget);
    expect(find.byKey(const Key('like-burst-dot-7')), findsNothing);
    final dot = tester.widget<Container>(
      find.byKey(const Key('like-burst-dot-0')),
    );
    expect((dot.decoration! as BoxDecoration).color, BrandColors.sage);

    await tester.pump(const Duration(milliseconds: 70));
    expect(_iconScale(tester, const Key('like')), greaterThan(1.02));

    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
      BrandColors.forest,
    );
    expect(_iconScale(tester, const Key('like')), 1);
    expect(find.byKey(const Key('like-burst')), findsNothing);
  });

  testWidgets('reduced motion fills the heart without a burst', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      wrap(
        reduce: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            return LikeSaveButton(
              key: const Key('like'),
              saved: saved,
              saveLabel: 'Uložit místo',
              savedLabel: 'Místo je uložené',
              onChanged: (value) => setState(() => saved = value),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('like')));
    await tester.pump();
    expect(saved, isTrue);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byKey(const Key('like-burst')), findsNothing);
    expect(_iconScale(tester, const Key('like')), 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('like-burst')), findsNothing);
  });

  testWidgets('place save is not the verify action', (tester) async {
    final place = samplePlaces().first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailSheet(
            place: place,
            strings: AppStrings('cs'),
            userLocation: null,
            onClose: () {},
            onVerify: () {},
          ),
        ),
      ),
    );
    expect(find.byType(LikeSaveButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('map-poi-verify')),
        matching: find.byType(LikeSaveButton),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('spring switch stretches, overshoots, then rests forest/cream', (
    tester,
  ) async {
    var on = false;
    await tester.pumpWidget(
      wrap(
        child: StatefulBuilder(
          builder: (context, setState) {
            return BrandSpringSwitch(
              value: on,
              onChanged: (value) => setState(() => on = value),
            );
          },
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('brand-switch'))).height, 44);
    expect(_trackColor(tester), BrandColors.neutral);
    expect(_thumbColor(tester), BrandColors.cream);

    await tester.tap(find.byKey(const Key('brand-switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(_stretch(tester), MotionTokens.stretchScale);

    final xs = <double>[];
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      xs.add(tester.getCenter(find.byKey(const Key('brand-switch-thumb'))).dx);
    }
    await tester.pumpAndSettle();
    final settled = tester
        .getCenter(find.byKey(const Key('brand-switch-thumb')))
        .dx;
    expect(xs.reduce((a, b) => a > b ? a : b), greaterThan(settled + 1));
    expect(on, isTrue);
    expect(_trackColor(tester), BrandColors.forest);
    expect(_thumbColor(tester), BrandColors.cream);
    expect(_stretch(tester), 1);
  });

  testWidgets('reduced motion snaps the switch without stretch', (
    tester,
  ) async {
    var on = false;
    await tester.pumpWidget(
      wrap(
        reduce: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            return BrandSpringSwitch(
              value: on,
              onChanged: (value) => setState(() => on = value),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('brand-switch')));
    await tester.pump();
    expect(on, isTrue);
    expect(_trackColor(tester), BrandColors.forest);
    expect(_thumbColor(tester), BrandColors.cream);
    expect(_stretch(tester), 1);
    final align = tester.widget<Align>(
      find.descendant(
        of: find.byKey(const Key('brand-switch')),
        matching: find.byType(Align),
      ),
    );
    expect(align.alignment, const Alignment(1, 0));
    await tester.pump(const Duration(milliseconds: 240));
    expect(_stretch(tester), 1);
  });

  testWidgets('overflow menu scales from the trigger on a cream surface', (
    tester,
  ) async {
    var selected = '';
    await tester.pumpWidget(
      wrap(
        child: Center(
          child: BrandOverflowMenu(
            actions: [
              BrandMenuAction(
                label: 'Sdílet',
                onSelected: () => selected = 'share',
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('brand-overflow-trigger')))
          .shortestSide,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(const Key('brand-overflow-trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final motion = tester.widget<Transform>(
      find.byKey(const Key('brand-overflow-motion')),
    );
    expect(motion.transform.storage[0], greaterThan(0.95));
    expect(motion.transform.storage[0], lessThan(1));
    expect(motion.alignment, const Alignment(1, -1));

    final surface = tester.widget<Material>(
      find.byKey(const Key('brand-overflow-surface')),
    );
    expect(surface.color, BrandColors.cream);
    expect(
      (surface.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(12),
    );
    expect(
      tester.widget<Text>(find.text('Sdílet')).style?.color,
      BrandColors.forest,
    );

    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(find.byKey(const Key('brand-overflow-motion')))
          .transform
          .storage[0],
      1,
    );
    await tester.tap(find.text('Sdílet'));
    await tester.pumpAndSettle();
    expect(selected, 'share');
  });

  testWidgets('reduced motion shows the overflow menu at full scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        reduce: true,
        child: const BrandOverflowMenu(
          actions: [BrandMenuAction(label: 'Sdílet', onSelected: _noop)],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('brand-overflow-trigger')));
    await tester.pump();
    expect(
      tester
          .widget<Transform>(find.byKey(const Key('brand-overflow-motion')))
          .transform
          .storage[0],
      1,
    );
    expect(
      tester
          .widget<Material>(find.byKey(const Key('brand-overflow-surface')))
          .color,
      BrandColors.cream,
    );
    await tester.pumpAndSettle();
  });
}

void _noop() {}

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
}

Widget wrap({required Widget child, bool reduce = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, routed) {
      final data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(
          disableAnimations: reduce || data.disableAnimations,
          accessibleNavigation: data.accessibleNavigation,
        ),
        child: routed!,
      );
    },
    home: Scaffold(body: Center(child: child)),
  );
}

double _shakeDx(WidgetTester tester, Key field) {
  final transform = tester.widget<Transform>(
    find
        .ancestor(of: find.byKey(field), matching: find.byType(Transform))
        .first,
  );
  return transform.transform.getTranslation().x;
}

void _expectErrorBorder(WidgetTester tester, Key field) {
  final border =
      tester.widget<TextField>(find.byKey(field)).decoration!.enabledBorder!
          as OutlineInputBorder;
  expect(border.borderSide.color, BrandColors.error);
}

double _iconScale(WidgetTester tester, Key button) {
  final transform = tester.widget<Transform>(
    find.descendant(of: find.byKey(button), matching: find.byType(Transform)),
  );
  return transform.transform.storage[0];
}

Color _trackColor(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.byKey(const Key('brand-switch-track')),
  );
  return (box.decoration! as BoxDecoration).color!;
}

Color _thumbColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(const Key('brand-switch-thumb')),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color!;
}

double _stretch(WidgetTester tester) {
  return tester
      .widget<Transform>(find.byKey(const Key('brand-switch-stretch')))
      .transform
      .storage[0];
}
