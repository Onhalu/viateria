import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/core/l10n/map_strings.dart';
import 'package:viateria/features/map/application/map_providers.dart';
import 'package:viateria/features/map/data/poi_repository.dart';
import 'package:viateria/features/map/presentation/map_screen.dart';
import 'package:viateria/l10n/locale_controller.dart';

import 'helpers/map_harness.dart';

Widget _mapApp({
  MemoryPoiRepository? repo,
}) {
  return ProviderScope(
    overrides: [
      poiRepositoryProvider.overrideWithValue(
        repo ?? MemoryPoiRepository(samplePois()),
      ),
    ],
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
      ],
      child: const MaterialApp(home: Scaffold(body: MapScreen())),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    configureMapWidgetTests();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('filter changes the visible POI count chip', (tester) async {
    final strings = MapStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-poi-count')), findsOneWidget);
    expect(find.text(strings.poiCount(3)), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-filter-castle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.poiCount(2)), findsOneWidget);
    expect(find.text(strings.poiCount(3)), findsNothing);
  });

  testWidgets('selecting a list POI opens the place sheet', (tester) async {
    final strings = MapStrings('cs');
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
    expect(find.text(strings.categoryLabel('catCastle')), findsWidgets);
    expect(find.text(strings.detailCta), findsOneWidget);
    expect(find.text(strings.closeCta), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-poi-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-poi-sheet')), findsNothing);
  });

  testWidgets('map and list share the same filtered catalog', (tester) async {
    final strings = MapStrings('cs');
    await tester.pumpWidget(_mapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('map-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-filter-castle')));
    await tester.tap(find.byKey(const Key('map-filter-ruin')));
    await tester.tap(find.byKey(const Key('map-filter-church')));
    await tester.tap(find.byKey(const Key('map-filter-other')));
    await tester.tap(find.byKey(const Key('map-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text(strings.poiCount(1)), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Lednice'), findsOneWidget);
    expect(find.text('Karlštejn'), findsNothing);
  });

  testWidgets('Czech search copy and empty catalog error banner', (
    tester,
  ) async {
    final strings = MapStrings('cs');
    await tester.pumpWidget(
      _mapApp(repo: const MemoryPoiRepository([], error: 'offline')),
    );
    await tester.pumpAndSettle();

    expect(find.text(strings.searchHint), findsOneWidget);
    expect(find.text(strings.viewList), findsOneWidget);
    expect(find.text(strings.catalogLoadError), findsOneWidget);
    expect(find.text(strings.retry), findsOneWidget);
  });
}
