import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/memory_membership.dart';
import 'package:viateria/data/vandery_plus_session.dart';
import 'package:viateria/domain/vandery_plus.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/profile_screen.dart';
import 'package:viateria/ui/widgets/padlock_unlock.dart';
import 'package:viateria/ui/widgets/vandery_plus_map_lock.dart';
import 'package:viateria/ui/widgets/vandery_plus_paywall.dart';

import '../helpers/fakes.dart';

/// Review frames: profile CTA, member badge, paywall, map lock sequence, slides 2–4.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('export 390 and 1280 frames', (tester) async {
    await tester.runAsync(_loadFonts);
    await _shot(
      tester,
      const Size(390, 844),
      'vandery-plus-profile-cta-390',
      _profile(),
    );
    await _shot(
      tester,
      const Size(1280, 800),
      'vandery-plus-profile-cta-1280',
      _profile(),
    );
    await _shot(
      tester,
      const Size(390, 844),
      'vandery-plus-profile-cta-390-en',
      _profile(locale: 'en'),
    );
    await _shot(
      tester,
      const Size(1280, 800),
      'vandery-plus-profile-cta-1280-en',
      _profile(locale: 'en'),
    );
    expect(find.text('Join VANDERY+'), findsOneWidget);
    await _shot(
      tester,
      const Size(390, 844),
      'vandery-plus-paywall-sheet-390',
      _paywall(width: 390, height: 844 * 0.82, handle: true),
    );
    await _shot(
      tester,
      const Size(1280, 800),
      'vandery-plus-paywall-dialog-1280',
      _paywall(width: 480, height: 640, handle: false),
    );
    await _shot(
      tester,
      const Size(390, 844),
      'vandery-plus-paywall-sheet-390-en',
      _paywall(width: 390, height: 844 * 0.82, handle: true, locale: 'en'),
    );
    expect(find.text('Unlock place checks right on the map'), findsOneWidget);
    await _shot(
      tester,
      const Size(1280, 800),
      'vandery-plus-paywall-dialog-1280-en',
      _paywall(width: 480, height: 640, handle: false, locale: 'en'),
    );
    await _shot(
      tester,
      const Size(390, 200),
      'vandery-plus-map-lock-390',
      _lock(),
    );
    await _shot(
      tester,
      const Size(1280, 200),
      'vandery-plus-map-lock-1280',
      _lock(),
    );
    await _shot(
      tester,
      const Size(390, 844),
      'vandery-plus-member-390',
      _profile(member: true),
    );
    await _shot(
      tester,
      const Size(1280, 800),
      'vandery-plus-member-1280',
      _profile(member: true),
    );
    expect(find.byKey(const Key('vandery-plus-badge')), findsOneWidget);
    expect(find.text('Členství aktivní.'), findsOneWidget);
    expect(find.text('Přidej se VANDERY+'), findsNothing);
    await _shot(
      tester,
      const Size(390, 240),
      'vandery-plus-map-sequence-390',
      _lockSequence(),
      advance: const Duration(milliseconds: 500),
    );
    await _shot(
      tester,
      const Size(1280, 240),
      'vandery-plus-map-sequence-1280',
      _lockSequence(),
      advance: const Duration(milliseconds: 500),
    );
  });

  testWidgets('carousel slides 2-4 are distinct frames', (tester) async {
    await tester.runAsync(_loadFonts);
    const slides = <int, String>{
      1: 'Odměny za ověřená místa',
      2: 'Víc bodů v žebříčku',
      3: 'Podpoříš projekt napřímo',
    };
    final captured = <int, List<int>>{};
    for (final entry in slides.entries) {
      final bytes = await _shotSlide(
        tester,
        page: entry.key,
        name: 'vandery-plus-slide-${entry.key + 1}-390',
        title: entry.value,
      );
      captured[entry.key] = bytes;
    }
    expect(captured[1], isNot(equals(captured[2])));
    expect(captured[2], isNot(equals(captured[3])));
    expect(captured[1], isNot(equals(captured[3])));
  });
}

ThemeData _shotTheme() {
  final theme = AppTheme.light();
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Roboto'],
    ),
  );
}

Widget _profile({bool member = false, String locale = 'cs'}) {
  final active = VanderyPlusMembership(
    status: 'active',
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 20)),
  );
  final session = VanderyPlusSession(
    repository: MemoryMembershipRepository(initial: member ? active : null),
  );
  // The profile loads membership once. A later pump reuses that state, so the
  // active row has to already be on the session or the wide frame keeps the CTA.
  if (member) {
    session.membership = active;
    session.resolved = true;
  }
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        key: ValueKey('locale-$locale'),
        create: (_) => LocaleController(initial: locale),
      ),
      Provider.value(
        value: AppServices(
          config: const AppConfig(
            supabaseUrl: 'https://example.supabase.co',
            supabaseAnonKey: 'anon',
            stripePublishableKey: 'pk',
          ),
          auth: MemoryAuth(
            user: Profile(id: 'user-1', locale: locale, displayName: 'Tereza'),
          ),
          catalog: MemoryCatalog(),
          progress: MemoryProgress(),
          purchases: MemoryPurchases(),
          photos: MemoryPhotos(),
          photoCapture: MemoryCapture(),
          vanderyPlus: session,
        ),
      ),
    ],
    child: MaterialApp(
      key: ValueKey('profile-$member-$locale'),
      debugShowCheckedModeBanner: false,
      theme: _shotTheme(),
      home: Scaffold(body: ProfileScreen(places: MemoryPlaceCatalog(const []))),
    ),
  );
}

Widget _paywall({
  required double width,
  required double height,
  required bool handle,
  int initialSlide = 0,
  String locale = 'cs',
}) {
  final session = VanderyPlusSession(
    repository: MemoryMembershipRepository(),
    priceLabel: '—',
  );
  final strings = AppStrings(locale);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _shotTheme(),
    home: Scaffold(
      backgroundColor: const Color(0x99000000),
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF3EFE5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: VanderyPlusPaywallContent(
              session: session,
              strings: strings,
              showHandle: handle,
              initialSlide: initialSlide,
              onClose: () {},
              openUrl: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _lockSequence() {
  final strings = AppStrings('cs');
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _shotTheme(),
    home: Scaffold(
      backgroundColor: BrandColors.cream,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _sequenceFrame(
                'Zamčeno',
                MapPlaceVerifyGate(
                  session: VanderyPlusSession(
                    repository: MemoryMembershipRepository(),
                  ),
                  placeId: 'place-1',
                  strings: strings,
                  onVerify: () {},
                  onLockedTap: () {},
                ),
              ),
            ),
            Expanded(
              child: _sequenceFrame(
                'Odemčeno',
                Center(
                  child: PadlockUnlock(
                    play: true,
                    glyph: 40,
                    lockedLabel: strings.vanderyPlusLocked,
                    unlockedLabel: strings.vanderyPlusUnlocked,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _sequenceFrame(
                'Ověřit',
                AppButton(
                  label: strings.verify,
                  size: AppButtonSize.m,
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _sequenceFrame(String label, Widget child) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: BrandColors.bark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

Widget _lock() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _shotTheme(),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: MapPlaceVerifyGate(
          session: VanderyPlusSession(repository: MemoryMembershipRepository()),
          placeId: 'place-1',
          strings: AppStrings('cs'),
          onVerify: () {},
          onLockedTap: () {},
        ),
      ),
    ),
  );
}

Future<void> _loadFonts() async {
  const fontDir = '/tmp/flutter-sdk/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final bytes = await File('$fontDir/$name').readAsBytes();
    roboto.addFont(
      Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  final iconBytes = await File('$fontDir/MaterialIcons-Regular.otf')
      .readAsBytes();
  icons.addFont(
    Future.value(ByteData.sublistView(Uint8List.fromList(iconBytes))),
  );
  await icons.load();
  final onest = FontLoader('Onest');
  onest.addFont(rootBundle.load('assets/fonts/Onest[wght].ttf'));
  await onest.load();
}

Future<void> _shot(
  WidgetTester tester,
  Size size,
  String name,
  Widget child, {
  Duration advance = const Duration(milliseconds: 50),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    RepaintBoundary(key: const Key('shot'), child: child),
  );
  await tester.pump();
  await tester.pump(advance);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/opt/cursor/artifacts/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  });
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

/// Builds the paywall, then moves the live [PageController] before capture.
/// [PageController.initialPage] is not enough: the carousel state survives
/// the next pump and the viewport stays on the page it already showed.
Future<List<int>> _shotSlide(
  WidgetTester tester, {
  required int page,
  required String name,
  required String title,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('shot'),
      child: _paywall(width: 390, height: 844 * 0.82, handle: true),
    ),
  );
  await tester.pumpAndSettle();
  final controller = tester
      .widget<PageView>(find.byKey(const Key('vandery-plus-pages')))
      .controller!;
  controller.jumpToPage(page);
  await tester.pumpAndSettle();
  expect(controller.page, page.toDouble());
  expect(find.text(title), findsWidgets);
  expect(find.byKey(Key('vandery-plus-slide-$page')), findsWidgets);
  final viewport = tester.getRect(find.byKey(const Key('vandery-plus-pages')));
  final slide = tester.getRect(find.byKey(Key('vandery-plus-slide-$page')));
  expect(viewport.overlaps(slide), isTrue);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  late List<int> bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List().toList();
    final file = File('/opt/cursor/artifacts/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  });
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  return bytes;
}
