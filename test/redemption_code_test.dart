import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/domain/redemption_code.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/widgets/challenge_cta_panel.dart';
import 'package:viateria/ui/widgets/redeem_code_dialog.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('normalize', () {
    test('uppercases and strips spaces and dashes', () {
      expect(normalizeRedemptionCode('  ab12-cd34 '), 'AB12CD34');
      expect(normalizeRedemptionCode('ab12 cd34'), 'AB12CD34');
      expect(normalizeRedemptionCode('ABCD2345'), 'ABCD2345');
      expect(normalizeRedemptionCode('ABCDEFGHIJKLMNOP'), 'ABCDEFGHIJKLMNOP');
      expect(normalizeRedemptionCode('ABC2345'), isNull);
      expect(normalizeRedemptionCode('ABCDEFGHIJKLMNOPQ'), isNull);
      expect(normalizeRedemptionCode('AB12_CD34'), isNull);
      expect(normalizeRedemptionCode(''), isNull);
    });

    test('have-code CTA is only open paid and still locked', () {
      expect(
        showsHaveCodeCta(
          accessMode: AccessMode.open,
          pricingType: PricingType.paid,
          hasPaidUnlock: false,
        ),
        isTrue,
      );
      expect(
        showsHaveCodeCta(
          accessMode: AccessMode.open,
          pricingType: PricingType.paid,
          hasPaidUnlock: true,
        ),
        isFalse,
      );
      expect(
        showsHaveCodeCta(
          accessMode: AccessMode.open,
          pricingType: PricingType.free,
          hasPaidUnlock: false,
        ),
        isFalse,
      );
      expect(
        showsHaveCodeCta(
          accessMode: AccessMode.story,
          pricingType: PricingType.paid,
          hasPaidUnlock: false,
        ),
        isFalse,
      );
    });

    test('copy is locked in cs, en, and de', () {
      expect(AppStrings('cs').haveCode, 'Mám kód');
      expect(AppStrings('en').haveCode, 'I have a code');
      expect(AppStrings('de').haveCode, 'Ich habe einen Code');
      expect(AppStrings('cs').redeemCodeTitle, 'Zadej kód');
      expect(AppStrings('en').redeemCodeTitle, 'Enter your code');
      expect(AppStrings('de').redeemCodeTitle, 'Code eingeben');
      expect(AppStrings('cs').redeemCodeHelper, 'Kód z nákupu na vyšlápni.cz…');
      expect(
        AppStrings('en').redeemCodeHelper,
        'Code from your vyšlápni.cz purchase…',
      );
      expect(AppStrings('de').redeemCodeHelper, 'Code aus deinem Kauf…');
      expect(AppStrings('cs').redeemCodeHint, 'např. AB12CD34');
      expect(AppStrings('en').redeemCodeHint, 'e.g. AB12CD34');
      expect(AppStrings('de').redeemCodeHint, 'z. B. AB12CD34');
      expect(AppStrings('cs').redeemCodeUnlock, 'Odemknout');
      expect(AppStrings('en').redeemCodeUnlock, 'Unlock');
      expect(AppStrings('de').redeemCodeUnlock, 'Freischalten');
      expect(AppStrings('cs').redeemCodeCancel, 'Zrušit');
      expect(AppStrings('en').redeemCodeCancel, 'Cancel');
      expect(AppStrings('de').redeemCodeCancel, 'Abbrechen');
      expect(AppStrings('cs').redeemCodeSuccess, 'Výzva odemčená');
      expect(AppStrings('en').redeemCodeSuccess, 'Challenge unlocked');
      expect(
        AppStrings('de').redeemCodeSuccess,
        'Herausforderung freigeschaltet',
      );
      final en = AppStrings('en');
      expect(
        en.redeemCodeError(RedeemCodeError.invalidCode),
        en.redeemCodeError(RedeemCodeError.alreadyRedeemed),
      );
      expect(
        en.redeemCodeError(RedeemCodeError.challengeMismatch),
        "That code doesn't work…",
      );
      expect(en.redeemCodeError(RedeemCodeError.expired), contains('expired'));
      expect(
        AppStrings('cs').redeemCodeError(RedeemCodeError.emailMismatch),
        contains('jinému'),
      );
      expect(
        AppStrings('cs').redeemCodeError(RedeemCodeError.rateLimited),
        contains('Moc pokusů'),
      );
      expect(
        AppStrings('cs').redeemCodeError(RedeemCodeError.network),
        contains('Nepovedlo se spojit'),
      );
      expect(
        en.redeemCodeError(RedeemCodeError.alreadyUnlocked),
        'This challenge is already unlocked.',
      );
    });
  });

  testWidgets('code button is a 52 dp forest pill and diploma stays', (
    tester,
  ) async {
    _view(tester, 400, 800);
    await tester.pumpWidget(_panel(width: 400));
    final diploma = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-diploma')),
    );
    final code = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-code')),
    );
    expect(find.byKey(const Key('challenge-floating-pay-medal')), findsNothing);
    expect(find.text('Digital diploma'), findsOneWidget);
    expect(code.left - diploma.right, ChallengeCtaPanel.codeRowGap);
    expect(code.height, HaveCodeButton.height);
    expect(code.height, greaterThanOrEqualTo(44));
    expect(
      tester
          .getSize(find.byKey(const Key('challenge-floating-pay-ctas')))
          .height,
      HaveCodeButton.height,
    );
    expect(
      code.bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('challenge-cta-panel'))).bottom,
      ),
    );
    final filled = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('challenge-floating-pay-code')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(filled.style?.backgroundColor?.resolve({}), BrandColors.forest);
    expect(filled.style?.foregroundColor?.resolve({}), BrandColors.cream);
    expect(filled.style?.shape?.resolve({}), isA<StadiumBorder>());

    _view(tester, 320, 800);
    await tester.pumpWidget(_panel(width: 320));
    final stackedDiploma = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-diploma')),
    );
    final stackedCode = tester.getRect(
      find.byKey(const Key('challenge-floating-pay-code')),
    );
    expect(
      stackedCode.top - stackedDiploma.bottom,
      ChallengeCtaPanel.codeStackGap,
    );
    final stackedButtons = tester.getSize(
      find.byKey(const Key('challenge-floating-pay-ctas')),
    );
    expect(stackedCode.height, HaveCodeButton.height);
    expect(
      stackedButtons.height,
      closeTo(
        stackedDiploma.height +
            ChallengeCtaPanel.codeStackGap +
            HaveCodeButton.height,
        0.5,
      ),
    );
    expect(
      stackedCode.bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('challenge-cta-panel'))).bottom,
      ),
    );
  });

  test('have-code bodyHeight reserves 52, not the 48 medal slot', () {
    const row = 400.0;
    const stack = 320.0;
    expect(
      ChallengeCtaPanel.bodyHeight(row, haveCode: true),
      ChallengeCtaPanel.padTop +
          ChallengeCtaPanel.headingLineHeight +
          ChallengeCtaPanel.headingGap +
          HaveCodeButton.height +
          ChallengeCtaPanel.padAboveHairline +
          ChallengeCtaPanel.hairlineThickness,
    );
    expect(
      ChallengeCtaPanel.bodyHeight(stack, haveCode: true),
      ChallengeCtaPanel.padTop +
          ChallengeCtaPanel.headingLineHeight +
          ChallengeCtaPanel.headingGap +
          ChallengeCtaPanel.buttonHeight +
          ChallengeCtaPanel.codeStackGap +
          HaveCodeButton.height +
          ChallengeCtaPanel.padAboveHairline +
          ChallengeCtaPanel.hairlineThickness,
    );
    expect(
      ChallengeCtaPanel.bodyHeight(row, haveCode: true),
      ChallengeCtaPanel.bodyHeight(row) +
          (HaveCodeButton.height - ChallengeCtaPanel.buttonHeight),
    );
    expect(
      ChallengePaymentBarMetrics.bodyHeight(row, haveCode: true),
      ChallengeCtaPanel.bodyHeight(row, haveCode: true),
    );
    expect(
      ChallengeCtaPanel.bodyHeight(row),
      isNot(ChallengeCtaPanel.bodyHeight(row, haveCode: true)),
    );
  });

  testWidgets('free and story challenges keep the medal checkout', (
    tester,
  ) async {
    final strings = AppStrings('en');
    _view(tester, 800, 2400);
    await tester.pumpWidget(_screen(sampleOpenChallenge(), locale: 'en'));
    await tester.pumpAndSettle();
    expect(find.text(strings.haveCode), findsNothing);
    expect(find.text(strings.payMedalAndDiploma), findsWidgets);
    expect(find.text(strings.payDigitalDiploma), findsWidgets);

    await tester.pumpWidget(
      _screen(sampleStoryChallenge(), id: 'story-1', locale: 'en'),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.haveCode), findsNothing);
    expect(find.text(strings.payMedalAndDiploma), findsWidgets);
  });

  testWidgets('open paid replaces only the medal slot and redeems', (
    tester,
  ) async {
    final strings = AppStrings('en');
    final purchases = MemoryPurchases(completeOnRefresh: false);
    _view(tester, 800, 2400);
    await tester.pumpWidget(
      _screen(_paidOpen(), purchases: purchases, locale: 'en'),
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.haveCode), findsNWidgets(2));
    expect(find.text(strings.payMedalAndDiploma), findsNothing);
    expect(find.text(strings.payDigitalDiploma), findsNWidgets(2));
    expect(find.byKey(const Key('challenge-pay-medal')), findsNothing);
    expect(find.byKey(const Key('challenge-pay-code')), findsOneWidget);

    await tester.tap(find.byKey(const Key('challenge-pay-code')));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, BrandColors.cream);
    expect(
      dialog.shape,
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RedeemCodeDialog.radius),
      ),
    );
    expect(find.text(strings.redeemCodeTitle), findsOneWidget);
    expect(find.text(strings.redeemCodeHelper), findsOneWidget);
    expect(find.text(strings.redeemCodeUnlock), findsOneWidget);
    expect(find.text(strings.redeemCodeCancel), findsOneWidget);

    await tester.enterText(find.byKey(const Key('redeem-code-field')), 'abc');
    await tester.tap(find.byKey(const Key('redeem-code-submit')));
    await tester.pumpAndSettle();
    expect(find.text(strings.redeemCodeInvalid), findsOneWidget);
    expect(purchases.redeemCalls, isEmpty);
    expect(find.byKey(const Key('redeem-code-dialog')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('redeem-code-field')),
      'ab12-cd34',
    );
    await tester.tap(find.byKey(const Key('redeem-code-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('redeem-code-dialog')), findsNothing);
    expect(find.text(strings.redeemCodeSuccess), findsOneWidget);
    expect(purchases.redeemCalls.single.normalized, 'AB12CD34');
    expect(purchases.purchases['open-1']!.isPaid, isTrue);
    expect(
      purchases.purchases['open-1']!.rewardVariant,
      RewardVariant.medalAndDiploma,
    );
    expect(find.text(strings.haveCode), findsNothing);
  });

  testWidgets('friendly errors stay in the dialog', (tester) async {
    final strings = AppStrings('cs');
    final purchases = MemoryPurchases(completeOnRefresh: false)
      ..scriptedRedeemError = RedeemCodeError.emailMismatch;
    _view(tester, 800, 2400);
    await tester.pumpWidget(_screen(_paidOpen(), purchases: purchases));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('challenge-pay-code')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('redeem-code-field')),
      'AB12CD34',
    );
    await tester.tap(find.byKey(const Key('redeem-code-submit')));
    await tester.pumpAndSettle();

    expect(find.text(strings.redeemCodeEmailMismatch), findsOneWidget);
    expect(find.byKey(const Key('redeem-code-dialog')), findsOneWidget);
    expect(purchases.purchases.containsKey('open-1'), isFalse);
    expect(find.text(strings.redeemCodeSuccess), findsNothing);
  });

  testWidgets(
    'already unlocked keeps the code and skips the success snackbar',
    (tester) async {
      final strings = AppStrings('en');
      final purchases = MemoryPurchases(completeOnRefresh: false);
      purchases.pay('open-1', rewardVariant: RewardVariant.diploma);
      _view(tester, 800, 2400);
      await tester.pumpWidget(
        _screen(_paidOpen(), purchases: purchases, locale: 'en'),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.haveCode), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showRedeemCodeDialog(
                    context: context,
                    strings: strings,
                    purchases: purchases,
                    challengeId: 'open-1',
                  ),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('redeem-code-field')),
        'AB12-CD34',
      );
      await tester.tap(find.byKey(const Key('redeem-code-submit')));
      await tester.pumpAndSettle();

      expect(find.text(strings.redeemCodeAlreadyUnlocked), findsOneWidget);
      expect(find.byKey(const Key('redeem-code-dialog')), findsOneWidget);
      expect(find.text(strings.redeemCodeSuccess), findsNothing);
      expect(
        purchases.purchases['open-1']!.rewardVariant,
        RewardVariant.diploma,
      );
      expect(purchases.redeemCalls.single.normalized, 'AB12CD34');
    },
  );

  testWidgets('loading hides the spinner in forest and blocks dismiss', (
    tester,
  ) async {
    final gate = Completer<void>();
    final purchases = MemoryPurchases(completeOnRefresh: false)
      ..redeemDelay = gate;
    _view(tester, 800, 2400);
    await tester.pumpWidget(
      _screen(_paidOpen(), purchases: purchases, locale: 'en'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge-pay-code')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('redeem-code-field')),
      'AB12CD34',
    );
    await tester.tap(find.byKey(const Key('redeem-code-submit')));
    await tester.pump();

    expect(find.byKey(const Key('redeem-code-loading')), findsOneWidget);
    final spinner = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(const Key('redeem-code-loading')),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(spinner.color, BrandColors.forest);
    expect(find.byKey(const Key('redeem-code-submit')), findsNothing);

    await tester.tap(find.byKey(const Key('redeem-code-cancel')));
    await tester.pump();
    expect(find.byKey(const Key('redeem-code-dialog')), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Challenge unlocked'), findsOneWidget);
  });
}

void _view(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _panel({required double width}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChallengeCtaPanel(
            heading: 'Join',
            diplomaLabel: 'Digital diploma',
            medalLabel: 'I have a code',
            haveCode: true,
            onDiploma: () {},
            onMedal: () {},
          ),
        ),
      ),
    ),
  );
}

ChallengeDetail _paidOpen() {
  final base = sampleOpenChallenge();
  return ChallengeDetail(
    challenge: Challenge(
      id: base.challenge.id,
      slug: base.challenge.slug,
      accessMode: AccessMode.open,
      pricingType: PricingType.paid,
      priceCents: 499,
      diplomaPriceCents: 499,
      medalPriceCents: 900,
      currency: 'eur',
      status: PublishStatus.published,
      countryCode: 'CZ',
      fapiFormUrlDiploma: 'https://form.fapi.cz/diploma-test',
      fapiFormUrlMedal: 'https://form.fapi.cz/medal-test',
      translations: base.challenge.translations,
    ),
    waypoints: base.waypoints,
  );
}

Widget _screen(
  ChallengeDetail detail, {
  MemoryPurchases? purchases,
  String locale = 'cs',
  String? id,
}) {
  final challengeId = id ?? detail.challenge.id;
  final services = AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: MemoryAuth(
      user: const Profile(id: 'user-1', locale: 'cs', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(challenges: [detail.challenge], details: [detail]),
    progress: MemoryProgress(details: [detail]),
    purchases: purchases ?? MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    openUrl: (_) async {},
  );
  return TickerMode(
    enabled: false,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleController(initial: locale),
        ),
        ChangeNotifierProvider(
          create: (_) => LastOpenedChallengeStore(initialId: challengeId),
        ),
        Provider.value(value: services),
      ],
      child: MaterialApp(
        home: Scaffold(body: ChallengeScreen(challengeId: challengeId)),
      ),
    ),
  );
}
