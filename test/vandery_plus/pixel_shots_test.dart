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
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/screens/profile_screen.dart';
import 'package:viateria/ui/widgets/vandery_plus_map_lock.dart';
import 'package:viateria/ui/widgets/vandery_plus_paywall.dart';

import '../helpers/fakes.dart';

/// Six review frames: profile CTA, paywall sheet, paywall dialog, map lock.
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
  });
}

Widget _profile() {
  final session = VanderyPlusSession(repository: MemoryMembershipRepository());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
      Provider.value(
        value: AppServices(
          config: const AppConfig(
            supabaseUrl: 'https://example.supabase.co',
            supabaseAnonKey: 'anon',
            stripePublishableKey: 'pk',
          ),
          auth: MemoryAuth(
            user: const Profile(id: 'user-1', locale: 'cs', displayName: 'Tereza'),
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
      theme: AppTheme.light(),
      home: Scaffold(body: ProfileScreen(places: MemoryPlaceCatalog(const []))),
    ),
  );
}

Widget _paywall({
  required double width,
  required double height,
  required bool handle,
}) {
  final session = VanderyPlusSession(
    repository: MemoryMembershipRepository(),
    priceLabel: '—',
  );
  final strings = AppStrings('cs');
  return MaterialApp(
    theme: AppTheme.light(),
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
              onClose: () {},
              openUrl: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _lock() {
  return MaterialApp(
    theme: AppTheme.light(),
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
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    final bytes = await File('$fontDir/$name').readAsBytes();
    roboto.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  final iconBytes = await File('$fontDir/MaterialIcons-Regular.otf').readAsBytes();
  icons.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(iconBytes))));
  await icons.load();
  final onest = FontLoader('Onest');
  onest.addFont(rootBundle.load('assets/fonts/Onest[wght].ttf'));
  await onest.load();
}

Future<void> _shot(
  WidgetTester tester,
  Size size,
  String name,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(RepaintBoundary(key: const Key('shot'), child: child));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
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
