import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/screens/places_map_screen.dart';
import 'package:viateria/ui/widgets/map_chrome.dart';

import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

AppServices _services() {
  final open = sampleOpenChallenge();
  return AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: MemoryAuth(
      user: const Profile(id: 'user-1', locale: 'cs', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(challenges: [open.challenge], details: [open]),
    progress: MemoryProgress(details: [open]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
  );
}

Widget _mapApp({MemoryPlaceCatalog? catalog}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
      ChangeNotifierProvider(create: (_) => LastOpenedChallengeStore()),
      Provider.value(value: _services()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: PlacesMapScreen(
          catalog: catalog ?? MemoryPlaceCatalog(samplePlaces()),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('filter changes the visible POI count chip', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-poi-count')), findsOneWidget);
    expect(find.text(strings.monumentCount(3)), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-filter-historical')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(2)), findsOneWidget);
    expect(find.text(strings.monumentCount(3)), findsNothing);
  });

  testWidgets('selecting a list place opens the place sheet', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-view-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-poi-list')), findsOneWidget);
    await tester.tap(find.text('Karlštejn'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-poi-sheet')), findsOneWidget);
    expect(find.byKey(const Key('map-poi-sheet-name')), findsOneWidget);
    expect(find.text('Karlštejn'), findsWidgets);
    expect(find.text(strings.t('catHistorical')), findsWidgets);
    expect(find.text(strings.detailCta), findsOneWidget);
    expect(find.text(strings.closeCta), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-poi-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-poi-sheet')), findsNothing);
  });

  testWidgets('map and list share the same filtered catalog', (tester) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-filter-city')));
    await tester.tap(find.byKey(const Key('map-filter-nature')));
    await tester.tap(find.byKey(const Key('map-filter-technical')));
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.monumentCount(1)), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Karlštejn'), findsOneWidget);
    expect(find.text('Staroměstské náměstí'), findsNothing);
  });

  testWidgets('Czech search copy and empty catalog error banner', (
    tester,
  ) async {
    final strings = AppStrings('cs');
    await tester.pumpWidget(
      _mapApp(catalog: const MemoryPlaceCatalog([], error: 'offline')),
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.searchHint), findsOneWidget);
    expect(find.text(strings.viewList), findsOneWidget);
    expect(find.text(strings.catalogLoadError), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
    expect(find.byKey(const Key('map-osm-attribution')), findsOneWidget);
    expect(find.byKey(const Key('map-locate-fab')), findsOneWidget);
  });

  testWidgets('Mapa tab chrome uses Batch A cream/forest sizes', (
    tester,
  ) async {
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    final search = tester.widget<TextField>(
      find.byKey(const Key('map-search-field')),
    );
    expect(search.style?.color, MapPalette.forest);
    expect(search.style?.fontSize, 15);
    expect(search.decoration?.prefixIcon, isA<Icon>());
    expect((search.decoration!.prefixIcon! as Icon).size, 20);
    expect((search.decoration!.prefixIcon! as Icon).color, MapPalette.forest);

    final locate = tester.widget<MapIconButton>(
      find.byKey(const Key('map-locate-fab')),
    );
    expect(locate.size, 44);
    expect(locate.iconSize, 20);
    expect(locate.foreground, MapPalette.forest);

    final filter = tester.widget<MapIconButton>(
      find.byKey(const Key('map-filter-button')),
    );
    expect(filter.size, 44);
    expect(filter.iconSize, 20);

    final count = tester.widget<Text>(find.byKey(const Key('map-poi-count')));
    expect(count.style?.color, MapPalette.bark);
    expect(count.style?.fontSize, 13);
  });
}
