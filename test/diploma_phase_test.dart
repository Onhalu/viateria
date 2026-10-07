import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/diploma_client.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/domain/diploma_phase.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/ui/diploma_share.dart';
import 'package:viateria/ui/screens/diploma_screen.dart';

import 'helpers/fakes.dart';

void main() {
  test('entitlement is paid, a zero price, or a free challenge', () {
    expect(
      ChallengeReward.isDiplomaEntitled(
        challengeCompleted: true,
        purchasePaid: true,
        diplomaPriceCents: 499,
      ),
      isTrue,
    );
    expect(
      ChallengeReward.isDiplomaEntitled(
        challengeCompleted: false,
        purchasePaid: true,
        diplomaPriceCents: 0,
      ),
      isFalse,
    );
    expect(
      ChallengeReward.isDiplomaEntitled(
        challengeCompleted: true,
        purchasePaid: false,
        diplomaPriceCents: 499,
      ),
      isFalse,
    );
    expect(
      ChallengeReward.isDiplomaEntitled(
        challengeCompleted: true,
        purchasePaid: false,
        diplomaPriceCents: 0,
        requiresPurchase: true,
      ),
      isTrue,
    );
    expect(
      ChallengeReward.isDiplomaEntitled(
        challengeCompleted: true,
        purchasePaid: false,
        diplomaPriceCents: null,
        requiresPurchase: false,
      ),
      isTrue,
    );
  });

  test('remote diploma_status wins over the local guess', () {
    expect(
      resolveDiplomaPhase(
        completed: true,
        entitled: true,
        hasDisplayName: true,
        remoteState: 'buy',
      ),
      DiplomaPhase.blurred,
    );
    expect(
      shouldRequestDiplomaFile(
        resolveDiplomaPhase(
          completed: true,
          entitled: false,
          hasDisplayName: false,
          remoteState: 'ready',
        ),
      ),
      isTrue,
    );
    expect(shouldRequestDiplomaFile(DiplomaPhase.blurred), isFalse);
    expect(
      resolveDiplomaPhase(
        completed: true,
        entitled: true,
        hasDisplayName: false,
        remoteState: null,
      ),
      DiplomaPhase.needName,
    );
    expect(hasDiplomaDisplayName('  '), isFalse);
    expect(hasDiplomaDisplayName('Ada'), isTrue);
  });

  test('completion line uses Europe/Prague and never a day count', () {
    expect(
      formatDiplomaCompletedOn(DateTime.utc(2026, 1, 15, 23, 30)),
      'dokončeno dne 16.01.2026',
    );
    expect(
      formatDiplomaCompletedOn(DateTime.utc(2026, 7, 15, 22, 30)),
      'dokončeno dne 16.07.2026',
    );
    expect(
      diplomaCompletionLine(remoteLabel: 'dokončeno dne 01.02.2026'),
      'dokončeno dne 01.02.2026',
    );
    expect(diplomaFileName('Pálava 2026'), 'vyslapni-diplom-p-lava-2026.png');
  });

  testWidgets('diploma screen shows the signed image and shares the png', (
    tester,
  ) async {
    final diplomas = MemoryDiplomaClient(
      accessState: 'ready',
      completionLabel: 'dokončeno dne 07.09.2026',
      imageUrl: 'https://example.test/diploma.png',
    );
    final shared = <String>[];
    final previousProvider = diplomaImageProvider;
    final previousLoader = diplomaBytesLoader;
    final previousSharer = diplomaSharer;
    diplomaImageProvider = (_) => MemoryImage(Uint8List.fromList(_tinyPng));
    diplomaBytesLoader = (_) async => Uint8List.fromList(_tinyPng);
    diplomaSharer = (bytes, filename) async {
      shared.add(filename);
    };
    addTearDown(() {
      diplomaImageProvider = previousProvider;
      diplomaBytesLoader = previousLoader;
      diplomaSharer = previousSharer;
    });

    final open = sampleOpenChallenge();
    final services = AppServices(
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
      diplomas: diplomas,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'cs'),
          ),
          Provider.value(value: services),
        ],
        child: const MaterialApp(home: DiplomaScreen(challengeId: 'open-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diploma-image')), findsOneWidget);
    expect(find.text('dokončeno dne 07.09.2026'), findsOneWidget);
    expect(find.byKey(const Key('diploma-blur')), findsNothing);
    expect(diplomas.imageRequests, ['open-1']);

    await tester.tap(find.byKey(const Key('diploma-download')));
    await tester.pumpAndSettle();
    expect(shared, ['vyslapni-diplom-open-trail.png']);
  });
}

const _tinyPng = <int>[
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
  137,
  164,
  126,
  142,
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
