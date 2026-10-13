import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/diploma_client.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/domain/diploma_phase.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_colors.dart';
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

  test('reward panel uses the payment rule without requiring completion', () {
    expect(
      ChallengeReward.isRewardAccessible(
        purchasePaid: false,
        diplomaPriceCents: 499,
        requiresPurchase: true,
      ),
      isFalse,
    );
    expect(
      ChallengeReward.isRewardAccessible(
        purchasePaid: true,
        diplomaPriceCents: 499,
      ),
      isTrue,
    );
    expect(
      ChallengeReward.isRewardAccessible(
        purchasePaid: false,
        diplomaPriceCents: 0,
        requiresPurchase: true,
      ),
      isTrue,
    );
    expect(
      ChallengeReward.isRewardAccessible(
        purchasePaid: false,
        diplomaPriceCents: null,
        requiresPurchase: false,
      ),
      isTrue,
    );
    expect(
      ChallengeReward.isDiplomaEntitled(
        challengeCompleted: false,
        purchasePaid: true,
        diplomaPriceCents: 499,
      ),
      isFalse,
    );
    expect(
      ChallengeReward.isRewardAccessible(
        purchasePaid: true,
        diplomaPriceCents: 499,
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

  testWidgets('retry after a failed diploma load does not return a Future', (
    tester,
  ) async {
    final diplomas = MemoryDiplomaClient(
      accessState: 'ready',
      completionLabel: 'dokončeno dne 07.10.2026',
      imageError: 'error',
    );
    final previousProvider = diplomaImageProvider;
    diplomaImageProvider = (_) => MemoryImage(Uint8List.fromList(_tinyPng));
    addTearDown(() => diplomaImageProvider = previousProvider);

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
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'en'),
          ),
          Provider.value(value: services),
        ],
        child: const MaterialApp(home: DiplomaScreen(challengeId: 'open-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('dokončeno dne 07.10.2026'), findsOneWidget);
    expect(find.byKey(const Key('diploma-error')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('diploma-retry')));
    expect(find.byKey(const Key('diploma-retry')), findsOneWidget);

    diplomas.imageError = null;
    diplomas.imageUrl = 'https://example.test/diploma.png';
    await tester.tap(find.byKey(const Key('diploma-retry')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('diploma-image')), findsOneWidget);
    expect(find.byKey(const Key('diploma-error')), findsNothing);
    expect(diplomas.imageRequests, ['open-1', 'open-1']);
  });

  test('edited diploma names are trimmed and reject controls', () {
    expect(
      normalizeDiplomaEditedName('  Janu Svobodovou  '),
      'Janu Svobodovou',
    );
    expect(normalizeDiplomaEditedName('A' * 40), 'A' * 40);
    expect(normalizeDiplomaEditedName(''), isNull);
    expect(normalizeDiplomaEditedName('   '), isNull);
    expect(normalizeDiplomaEditedName('A' * 41), isNull);
    expect(normalizeDiplomaEditedName('Jan\nNovák'), isNull);
    expect(normalizeDiplomaEditedName('A\u0001B'), isNull);
    expect(
      AppStrings('cs').diplomaNameFromProfile,
      'Jméno se načítá z tvého zobrazovaného jména v profilu. Na diplomu ho můžeš jednou upravit.',
    );
    expect(AppStrings('cs').diplomaEditName, 'Upravit jméno');
    expect(AppStrings('cs').diplomaNameEdited, 'Jméno bylo upraveno');
    expect(AppStrings('en').diplomaNameFromProfile, contains('once'));
    expect(AppStrings('de').diplomaNameFromProfile, contains('einmal'));
  });

  testWidgets('diploma name can be edited once from the printed form', (
    tester,
  ) async {
    final diplomas = MemoryDiplomaClient(
      accessState: 'ready',
      completionLabel: 'dokončeno dne 07.09.2026',
      imageUrl: 'https://example.test/diploma.png',
      diplomaId: 'diploma-1',
      recipientNameDisplay: 'Pavla Novák',
      nameEditable: true,
    );
    await _pumpDiploma(tester, diplomas: diplomas, displayName: 'Ada');

    expect(
      find.text(
        'Jméno se načítá z tvého zobrazovaného jména v profilu. Na diplomu ho můžeš jednou upravit.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('diploma-edit-name')), findsOneWidget);
    expect(find.byKey(const Key('diploma-name-edited')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('diploma-edit-name')));
    await tester.tap(find.byKey(const Key('diploma-edit-name')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('diploma-name-field')),
    );
    expect(field.controller?.text, 'Pavla Novák');
    expect(find.text('Ada'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('diploma-name-field')),
      '  Janu Svobodovou  ',
    );
    await tester.tap(find.byKey(const Key('diploma-name-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diploma-name-confirm')), findsOneWidget);
    expect(diplomas.nameEdits, isEmpty);
    await tester.tap(find.byKey(const Key('diploma-name-confirm-save')));
    await tester.pumpAndSettle();

    expect(diplomas.nameEdits, ['Janu Svobodovou']);
    expect(find.byKey(const Key('diploma-edit-name')), findsNothing);
    expect(find.byKey(const Key('diploma-name-info')), findsNothing);
    expect(find.text('Jméno bylo upraveno'), findsOneWidget);
    expect(diplomas.imageRequests, ['open-1', 'open-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an invalid diploma name is not saved', (tester) async {
    final diplomas = MemoryDiplomaClient(
      accessState: 'ready',
      imageUrl: 'https://example.test/diploma.png',
      diplomaId: 'diploma-1',
      recipientNameDisplay: 'Pavla Novák',
      nameEditable: true,
    );
    await _pumpDiploma(tester, diplomas: diplomas);

    await tester.ensureVisible(find.byKey(const Key('diploma-edit-name')));
    await tester.tap(find.byKey(const Key('diploma-edit-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('diploma-name-field')), '   ');
    await tester.tap(find.byKey(const Key('diploma-name-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diploma-name-invalid')), findsOneWidget);
    expect(find.byKey(const Key('diploma-name-confirm')), findsNothing);
    expect(diplomas.nameEdits, isEmpty);

    await tester.enterText(
      find.byKey(const Key('diploma-name-field')),
      'A' * 41,
    );
    await tester.tap(find.byKey(const Key('diploma-name-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diploma-name-invalid')), findsOneWidget);
    expect(diplomas.nameEdits, isEmpty);

    await tester.tap(find.byKey(const Key('diploma-name-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diploma-edit-name')), findsOneWidget);
  });

  testWidgets('a diploma that was already edited hides the action', (
    tester,
  ) async {
    final diplomas = MemoryDiplomaClient(
      accessState: 'ready',
      imageUrl: 'https://example.test/diploma.png',
      diplomaId: 'diploma-1',
      recipientNameDisplay: 'Janu Svobodovou',
      nameEditable: false,
      nameSource: 'edited',
    );
    await _pumpDiploma(tester, diplomas: diplomas);

    expect(find.byKey(const Key('diploma-edit-name')), findsNothing);
    expect(find.byKey(const Key('diploma-name-info')), findsNothing);
    expect(find.text('Jméno bylo upraveno'), findsOneWidget);
    expect(diplomas.imageRequests, ['open-1']);
  });

  test('share caption names the challenge in cs, en, and de', () {
    expect(
      AppStrings('cs').diplomaShareCaption('Pálava'),
      'Zdolal(a) jsem výzvu Pálava s VANDERY',
    );
    expect(
      AppStrings('en').diplomaShareCaption('Pálava'),
      'I completed the Pálava challenge with VANDERY',
    );
    expect(
      AppStrings('de').diplomaShareCaption('Pálava'),
      'Ich habe die Challenge Pálava mit VANDERY geschafft',
    );
    expect(
      AppStrings('cs').diplomaShareDownloadedHint,
      'Obrázek je stažený, nahraj ho na Instagram / Facebook',
    );
  });

  test('instagram uses stories only when an app id is configured', () async {
    final events = <String>[];
    final previous = diplomaShareEffects;
    addTearDown(() => diplomaShareEffects = previous);

    diplomaShareEffects = _shareEffects(
      events,
      canShare: true,
      appId: '12345',
      storiesSupported: true,
    );
    final story = await runDiplomaShare(
      target: DiplomaShareTarget.instagram,
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'diplom.png',
      caption: 'Zdolal(a) jsem výzvu Pálava s VANDERY',
    );
    expect(story.route, DiplomaShareRoute.stories);
    expect(story.showUploadHint, isFalse);
    expect(events, ['stories:12345:3']);

    events.clear();
    diplomaShareEffects = _shareEffects(
      events,
      canShare: true,
      appId: '12345',
      storiesSupported: true,
      storiesOk: false,
    );
    final sheet = await runDiplomaShare(
      target: DiplomaShareTarget.instagram,
      bytes: Uint8List.fromList([1]),
      filename: 'diplom.png',
      caption: 'caption',
    );
    expect(sheet.route, DiplomaShareRoute.sheet);
    expect(events, ['stories:12345:1', 'sheet:diplom.png:caption']);

    events.clear();
    diplomaShareEffects = _shareEffects(
      events,
      canShare: true,
      storiesSupported: true,
    );
    final missingId = await runDiplomaShare(
      target: DiplomaShareTarget.instagram,
      bytes: Uint8List.fromList([1]),
      filename: 'diplom.png',
      caption: 'caption',
    );
    expect(missingId.route, DiplomaShareRoute.sheet);
    expect(events, ['sheet:diplom.png:caption']);
  });

  test('desktop web downloads the png and opens the social site', () async {
    final events = <String>[];
    final previous = diplomaShareEffects;
    addTearDown(() => diplomaShareEffects = previous);
    diplomaShareEffects = _shareEffects(events, canShare: false);

    final instagram = await runDiplomaShare(
      target: DiplomaShareTarget.instagram,
      bytes: Uint8List.fromList([9]),
      filename: 'diplom.png',
      caption: 'caption',
    );
    expect(instagram.route, DiplomaShareRoute.download);
    expect(instagram.showUploadHint, isTrue);
    expect(events, ['download:diplom.png:1', 'url:https://www.instagram.com/']);

    events.clear();
    final facebook = await runDiplomaShare(
      target: DiplomaShareTarget.facebook,
      bytes: Uint8List.fromList([9]),
      filename: 'diplom.png',
      caption: 'caption',
    );
    expect(facebook.showUploadHint, isTrue);
    expect(events, ['download:diplom.png:1', 'url:https://www.facebook.com/']);

    events.clear();
    final generic = await runDiplomaShare(
      target: DiplomaShareTarget.generic,
      bytes: Uint8List.fromList([9]),
      filename: 'diplom.png',
      caption: 'caption',
    );
    expect(generic.showUploadHint, isFalse);
    expect(events, ['download:diplom.png:1']);
  });

  testWidgets('diploma share offers Instagram and Facebook', (tester) async {
    final diplomas = MemoryDiplomaClient(
      accessState: 'ready',
      imageUrl: 'https://example.test/diploma.png',
    );
    await _pumpDiploma(tester, diplomas: diplomas);

    for (final key in const [
      'diploma-share',
      'diploma-share-instagram',
      'diploma-share-facebook',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.width, greaterThanOrEqualTo(44), reason: key);
      expect(size.height, greaterThanOrEqualTo(44), reason: key);
    }
    expect(find.text('Sdílet'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);

    final camera = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('diploma-share-instagram')),
        matching: find.byIcon(Icons.photo_camera_outlined),
      ),
    );
    final facebook = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('diploma-share-facebook')),
        matching: find.byIcon(Icons.facebook_outlined),
      ),
    );
    expect(camera.color, BrandColors.forest);
    expect(facebook.color, BrandColors.forest);
  });

  testWidgets('instagram falls back to the share sheet without an app id', (
    tester,
  ) async {
    final events = <String>[];
    final previous = diplomaShareEffects;
    diplomaShareEffects = _shareEffects(events, canShare: true);
    addTearDown(() => diplomaShareEffects = previous);
    final diplomas = MemoryDiplomaClient(
      accessState: 'ready',
      imageUrl: 'https://example.test/diploma.png',
    );
    await _pumpDiploma(tester, diplomas: diplomas);

    await tester.ensureVisible(
      find.byKey(const Key('diploma-share-instagram')),
    );
    await tester.tap(find.byKey(const Key('diploma-share-instagram')));
    await tester.pumpAndSettle();

    expect(events, [
      'sheet:vyslapni-diplom-open-trail.png:'
          'Zdolal(a) jsem výzvu Otevřená stezka s VANDERY',
    ]);
    expect(find.byKey(const Key('diploma-share-hint')), findsNothing);
  });

  testWidgets('desktop instagram downloads the png and shows the hint', (
    tester,
  ) async {
    final events = <String>[];
    final previous = diplomaShareEffects;
    diplomaShareEffects = _shareEffects(events, canShare: false);
    addTearDown(() => diplomaShareEffects = previous);
    final diplomas = MemoryDiplomaClient(
      accessState: 'ready',
      imageUrl: 'https://example.test/diploma.png',
    );
    await _pumpDiploma(tester, diplomas: diplomas);

    await tester.ensureVisible(find.byKey(const Key('diploma-share-facebook')));
    await tester.tap(find.byKey(const Key('diploma-share-facebook')));
    await tester.pumpAndSettle();

    expect(events, [
      'download:vyslapni-diplom-open-trail.png:${_tinyPng.length}',
      'url:https://www.facebook.com/',
    ]);
    expect(
      find.text('Obrázek je stažený, nahraj ho na Instagram / Facebook'),
      findsOneWidget,
    );

    events.clear();
    await tester.tap(find.byKey(const Key('diploma-share')));
    await tester.pumpAndSettle();
    expect(events, [
      'download:vyslapni-diplom-open-trail.png:${_tinyPng.length}',
    ]);
  });
}

Future<void> _pumpDiploma(
  WidgetTester tester, {
  required MemoryDiplomaClient diplomas,
  String displayName = 'Ada',
}) async {
  final previousProvider = diplomaImageProvider;
  final previousLoader = diplomaBytesLoader;
  diplomaImageProvider = (_) => MemoryImage(Uint8List.fromList(_tinyPng));
  diplomaBytesLoader = (_) async => Uint8List.fromList(_tinyPng);
  addTearDown(() {
    diplomaImageProvider = previousProvider;
    diplomaBytesLoader = previousLoader;
  });
  tester.view.physicalSize = const Size(800, 2400);
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
      user: Profile(id: 'user-1', locale: 'cs', displayName: displayName),
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
        ChangeNotifierProvider(create: (_) => LocaleController(initial: 'cs')),
        Provider.value(value: services),
      ],
      child: const MaterialApp(home: DiplomaScreen(challengeId: 'open-1')),
    ),
  );
  await tester.pumpAndSettle();
}

DiplomaShareEffects _shareEffects(
  List<String> events, {
  required bool canShare,
  String appId = '',
  bool storiesSupported = false,
  bool storiesOk = true,
}) {
  return DiplomaShareEffects(
    canShareFiles: () async => canShare,
    facebookAppId: () => appId,
    storiesSupported: () => storiesSupported,
    stories: (bytes, id) async {
      events.add('stories:$id:${bytes.length}');
      return storiesOk;
    },
    sheet: (bytes, filename, caption) async {
      events.add('sheet:$filename:$caption');
    },
    download: (bytes, filename) async {
      events.add('download:$filename:${bytes.length}');
    },
    openUrl: (uri) async {
      events.add('url:$uri');
    },
  );
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
