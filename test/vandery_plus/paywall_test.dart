import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/memory_membership.dart';
import 'package:viateria/data/vandery_plus_session.dart';
import 'package:viateria/domain/unlock_trigger.dart';
import 'package:viateria/domain/vandery_plus.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/profile_screen.dart';
import 'package:viateria/ui/widgets/padlock_unlock.dart';
import 'package:viateria/ui/widgets/vandery_plus_paywall.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    unlockReplayMemory.reset();
  });

  testWidgets('FW-01 non-member CTA sits under the leaderboard', (tester) async {
    await tester.pumpWidget(_profile(locale: 'cs'));
    await tester.pumpAndSettle();
    expect(find.text('Přidej se VANDERY+'), findsOneWidget);
    final board = tester.getRect(find.byKey(const Key('profile-leaderboard')));
    final cta = tester.getRect(find.byKey(const Key('vandery-plus-cta')));
    expect(cta.top, greaterThanOrEqualTo(board.bottom - 1));
    expect(cta.height, 52);
  });

  testWidgets('FW-01 en and de copy', (tester) async {
    await tester.pumpWidget(_profile(locale: 'en'));
    await tester.pumpAndSettle();
    expect(find.text('Join VANDERY+'), findsOneWidget);
    await tester.pumpWidget(_profile(locale: 'de'));
    await tester.pumpAndSettle();
    expect(find.text('VANDERY+ beitreten'), findsOneWidget);
  });

  testWidgets('FW-02 member badge replaces the CTA', (tester) async {
    final repo = MemoryMembershipRepository(
      initial: membershipFromRow({
        'status': 'active',
        'expires_at': '2026-12-06T00:00:00.000Z',
      }),
    );
    await tester.pumpWidget(_profile(locale: 'cs', repo: repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vandery-plus-cta')), findsNothing);
    expect(find.text('VANDERY+'), findsWidgets);
    expect(find.text('Členství aktivní.'), findsOneWidget);
  });

  testWidgets('FW-03 mobile sheet is about 82% with handle and close', (tester) async {
    _size(tester, const Size(390, 800));
    final repo = MemoryMembershipRepository();
    await tester.pumpWidget(_paywallApp(repo: repo, locale: 'cs'));
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    final sheet = tester.getSize(find.byKey(const Key('vandery-plus-sheet')));
    expect(sheet.height, closeTo(800 * 0.82, 8));
    expect(find.byKey(const Key('vandery-plus-handle')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('vandery-plus-close'))).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.byKey(const Key('vandery-plus-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vandery-plus-sheet')), findsNothing);
  });

  testWidgets('FW-04 web dialog is at most 480 and Escape closes it', (tester) async {
    const web = Size(1280, 800);
    _size(tester, web);
    await tester.pumpWidget(
      _paywallApp(repo: MemoryMembershipRepository(), locale: 'cs', size: web),
    );
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    final dialog = tester.getSize(find.byKey(const Key('vandery-plus-dialog')));
    expect(dialog.width, lessThanOrEqualTo(480));
    expect(dialog.width, greaterThan(200));
    expect(dialog.width, lessThan(1280));
    await tester.tap(find.byKey(const Key('vandery-plus-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vandery-plus-dialog')), findsNothing);
  });

  testWidgets('FW-05 carousel has four slides, nav, and no autoplay', (tester) async {
    _size(tester, const Size(390, 800));
    await tester.pumpWidget(_paywallApp(repo: MemoryMembershipRepository(), locale: 'cs'));
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    expect(find.text('Ověřuj místa na mapě'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('vandery-plus-pages'))).height, 240);
    final cardPadding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byKey(const Key('vandery-plus-slide-0')),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(cardPadding.padding, const EdgeInsets.all(20));
    expect(find.byKey(const Key('vandery-plus-prev')), findsOneWidget);
    expect(find.byKey(const Key('vandery-plus-next')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('vandery-plus-next'))).shortestSide,
      greaterThanOrEqualTo(44),
    );
    expect(find.byKey(const Key('vandery-plus-dot-3')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('vandery-plus-dot-0'))).shortestSide,
      greaterThanOrEqualTo(44),
    );
    final page = tester.widget<PageView>(find.byKey(const Key('vandery-plus-pages')));
    final before = page.controller!.page;
    await tester.pump(const Duration(seconds: 10));
    expect(page.controller!.page, before);
    await tester.tap(find.byKey(const Key('vandery-plus-next')));
    await tester.pumpAndSettle();
    expect(find.text('Odměny za ověřená místa'), findsOneWidget);
  });

  testWidgets('FW-06 focus order is close, content, nav, dots, then pay', (tester) async {
    _size(tester, const Size(390, 800));
    await tester.pumpWidget(_paywallApp(repo: MemoryMembershipRepository(), locale: 'cs'));
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    final orders = tester
        .widgetList<FocusTraversalOrder>(find.byType(FocusTraversalOrder))
        .map((order) => (order.order as NumericFocusOrder).order)
        .toList();
    // Close 1, carousel 2, prev 3, next 4, dots from 5, pay 20.
    expect(orders, containsAll(const [1, 2, 3, 4, 5, 20]));
    expect(orders.reduce(math.min), 1);
    expect(orders.reduce(math.max), 20);
    expect(find.bySemanticsLabel('Výhoda 1 z 4'), findsWidgets);
  });

  testWidgets('FW-07 reduce motion lists the cards', (tester) async {
    _size(tester, const Size(390, 800));
    await tester.pumpWidget(
      _paywallApp(
        repo: MemoryMembershipRepository(),
        locale: 'cs',
        disableAnimations: true,
      ),
    );
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vandery-plus-benefit-list')), findsOneWidget);
    expect(find.byKey(const Key('vandery-plus-pages')), findsNothing);
    expect(find.text('Podpoříš projekt napřímo'), findsOneWidget);
  });

  testWidgets('FW-08 legal links render before the pay button', (tester) async {
    _size(tester, const Size(390, 800));
    final opened = <Uri>[];
    await tester.pumpWidget(
      _paywallApp(
        repo: MemoryMembershipRepository(),
        locale: 'cs',
        openUrl: (uri) async => opened.add(uri),
      ),
    );
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    final terms = tester.getTopLeft(find.byKey(const Key('vandery-plus-terms')));
    final pay = tester.getTopLeft(find.byKey(const Key('vandery-plus-pay')));
    expect(terms.dy, lessThan(pay.dy));
    expect(find.text('Obchodní podmínky'), findsOneWidget);
    expect(find.text('Ochrana osobních údajů'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('vandery-plus-terms')));
    tester
        .widget<TextButton>(find.byKey(const Key('vandery-plus-terms')))
        .onPressed!
        .call();
    await tester.pump();
    expect(opened, [VanderyPlusLegal.terms]);
  });

  testWidgets('FW-09 locked pay sends one checkout', (tester) async {
    _size(tester, const Size(390, 800));
    final repo = MemoryMembershipRepository();
    await tester.pumpWidget(
      _paywallApp(repo: repo, locale: 'cs', priceLabel: '599 Kč'),
    );
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    expect(find.text('Zaplatit členství · 599 Kč'), findsOneWidget);
    final slot = tester.getSize(find.byKey(const Key('vandery-plus-pay-slot')));
    await tester.ensureVisible(find.byKey(const Key('vandery-plus-pay')));
    await tester.tap(find.byKey(const Key('vandery-plus-pay')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('vandery-plus-pay')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repo.checkoutCalls, 1);
    expect(
      tester.getSize(find.byKey(const Key('vandery-plus-pay-slot'))).width,
      slot.width,
    );
    expect(find.byType(PadlockUnlock), findsNothing);
  });

  testWidgets('FW-11 verifying then server active shows the toast', (tester) async {
    _size(tester, const Size(390, 800));
    final repo = _HoldRead();
    await tester.pumpWidget(_paywallApp(repo: repo, locale: 'cs'));
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    final session = tester
        .element(find.text('open-paywall'))
        .read<AppServices>()
        .vanderyPlus;
    final pending = session.onReturn(VanderyPlusReturnKind.success);
    await tester.pump();
    expect(find.text('Ověřuji členství…'), findsOneWidget);
    repo.release.complete();
    await pending;
    await tester.pump();
    expect(find.text('Zkusit znovu ověřit'), findsOneWidget);
    expect(find.byKey(const Key('vandery-plus-toast')), findsNothing);
    repo.current = membershipFromRow({
      'status': 'active',
      'expires_at': '2026-12-06T00:00:00.000Z',
    });
    await tester.ensureVisible(find.byKey(const Key('vandery-plus-retry')));
    await tester.tap(find.byKey(const Key('vandery-plus-retry')));
    await tester.pumpAndSettle();
    expect(find.text('VANDERY+ aktivní'), findsOneWidget);
  });

  testWidgets('FW-12 and FW-13 inactive return and cancel are not success', (tester) async {
    _size(tester, const Size(390, 800));
    final repo = MemoryMembershipRepository();
    await tester.pumpWidget(_paywallApp(repo: repo, locale: 'cs'));
    await tester.tap(find.text('open-paywall'));
    await tester.pumpAndSettle();
    final session = tester
        .element(find.text('open-paywall'))
        .read<AppServices>()
        .vanderyPlus;
    await session.onReturn(VanderyPlusReturnKind.cancel);
    await tester.pump();
    expect(find.text('Platba byla zrušena.'), findsOneWidget);
    expect(find.text('VANDERY+ aktivní'), findsNothing);
    expect(session.isActive, isFalse);
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _HoldRead extends MemoryMembershipRepository {
  final release = Completer<void>();

  @override
  Future<VanderyPlusMembership> fetchMine() async {
    await release.future;
    return current;
  }
}

Widget _paywallApp({
  required MemoryMembershipRepository repo,
  required String locale,
  Size size = const Size(390, 800),
  String priceLabel = '',
  bool disableAnimations = false,
  Future<void> Function(Uri url)? openUrl,
}) {
  final session = VanderyPlusSession(
    repository: repo,
    priceLabel: priceLabel,
    clock: () => DateTime.utc(2026, 11, 6),
    openUrl: openUrl ?? (_) async {},
  );
  final services = _services(session, openUrl: openUrl);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        key: ValueKey('locale-$locale'),
        create: (_) => LocaleController(initial: locale),
      ),
      Provider.value(value: services),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showVanderyPlusPaywall(context),
              child: const Text('open-paywall'),
            ),
          ),
        ),
      ),
  );
}

Widget _profile({
  required String locale,
  MemoryMembershipRepository? repo,
}) {
  final session = VanderyPlusSession(
    repository: repo ?? MemoryMembershipRepository(),
    clock: () => DateTime.utc(2026, 11, 6),
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        key: ValueKey('locale-$locale'),
        create: (_) => LocaleController(initial: locale),
      ),
      Provider.value(value: _services(session)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: ProfileScreen(places: MemoryPlaceCatalog(const []))),
    ),
  );
}

AppServices _services(
  VanderyPlusSession session, {
  Future<void> Function(Uri url)? openUrl,
}) {
  return AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: MemoryAuth(
      user: const Profile(id: 'user-1', locale: 'cs', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(),
    progress: MemoryProgress(),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    openUrl: openUrl,
    vanderyPlus: session,
  );
}

