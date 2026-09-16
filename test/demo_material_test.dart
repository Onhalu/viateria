import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/app.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/demo_material_screen.dart';
import 'package:viateria/ui/widgets/app_shell.dart';

import 'helpers/fakes.dart';

AppServices buildServices() {
  final open = sampleOpenChallenge();
  final story = sampleStoryChallenge();
  return AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: MemoryAuth(
      user: const Profile(
        id: 'user-1',
        locale: 'en',
        displayName: 'Ada',
        email: 'ada@example.com',
      ),
    ),
    catalog: MemoryCatalog(
      challenges: [open.challenge, story.challenge],
      details: [open, story],
      promos: [samplePromo()],
    ),
    progress: MemoryProgress(details: [open, story]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
  );
}

Widget wrapApp(AppServices services) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: 'en')),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider.value(value: services),
    ],
    child: const ViateriaApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('demo scaffold matches flutter create Material 3 chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: DemoMaterialScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-material-screen')), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Flutter Material Demo'), findsOneWidget);
    expect(find.byKey(const Key('demo-material-banner')), findsOneWidget);
    expect(find.byKey(const Key('demo-material-fab')), findsOneWidget);
    expect(find.byKey(const Key('demo-material-nav-bar')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('demo-material-counter')), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-material-fab')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('wide demo uses NavigationRail instead of NavigationBar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: DemoMaterialScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-material-nav-rail')), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('demo-material-nav-bar')), findsNothing);
  });

  testWidgets('list and colors tabs show cards and seed swatches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: DemoMaterialScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-material-list')), findsOneWidget);
    expect(find.text('Catalog stays the home tab'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
    expect(find.text('Filled'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-material-colors')), findsOneWidget);
    expect(
      find.textContaining('ColorScheme.fromSeed (flutter create default)'),
      findsOneWidget,
    );
    expect(find.text('BrandColors.forest'), findsOneWidget);
    expect(find.text('BrandColors.cream'), findsOneWidget);
    expect(find.textContaining('not replaced'), findsOneWidget);
  });

  testWidgets('app still boots to catalog; demo is opened from Profile', (
    tester,
  ) async {
    await tester.pumpWidget(wrapApp(buildServices()));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Weekend hike'), findsOneWidget);
    expect(find.byKey(const Key('demo-material-screen')), findsNothing);
    expect(find.byType(AppBar), findsNothing);

    final strings = AppStrings('en');
    await tester.tap(find.text(strings.navProfile));
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('demo-material-entry'));
    expect(entry, findsOneWidget);
    await tester.scrollUntilVisible(entry, 200);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo-material-screen')), findsOneWidget);
    expect(find.text('Flutter Material Demo'), findsOneWidget);
    expect(find.textContaining('DEMO tokens'), findsOneWidget);
  });
}
