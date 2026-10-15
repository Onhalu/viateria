import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/diploma_client.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/diploma_share.dart';
import 'package:viateria/ui/screens/diploma_screen.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    diplomaImageProvider = (_) => MemoryImage(Uint8List.fromList(_png));
  });

  testWidgets('a wide window opens the diploma in a dialog', (tester) async {
    await _open(tester, const Size(800, 900));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('diploma-window-close')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
    final window = tester.getSize(find.byKey(const Key('diploma-window')));
    expect(window.width, lessThanOrEqualTo(520));
    expect(window.width, greaterThan(400));
    expect(find.byKey(const Key('diploma-image')), findsOneWidget);

    await tester.tap(find.byKey(const Key('diploma-window-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diploma-window')), findsNothing);
  });

  testWidgets('a narrow window opens the diploma in a sheet', (tester) async {
    const size = Size(390, 844);
    await _open(tester, size);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('diploma-window-close')), findsOneWidget);
    final window = tester.getSize(find.byKey(const Key('diploma-window')));
    expect(window.height, closeTo(size.height * 0.92, 1));
    expect(window.width, size.width);
  });
}

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final open = sampleOpenChallenge();
  final services = AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: MemoryAuth(
      user: Profile(id: 'user-1', locale: 'cs', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(challenges: [open.challenge], details: [open]),
    progress: MemoryProgress(details: [open]),
    purchases: MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    diplomas: MemoryDiplomaClient(
      accessState: 'ready',
      imageUrl: 'https://example.test/diploma.png',
    ),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
        Provider.value(value: services),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDiplomaWindow(context, 'open-1'),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

const _png = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  15,
  162,
  131,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
