import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/widgets/challenge_cta_panel.dart';
import 'package:viateria/ui/widgets/redeem_code_dialog.dart';

import 'helpers/fakes.dart';

/// Pixel frames for the „Mám kód“ CTA and redeem dialog.
///
/// `CAPTURE_REDEEM=1 flutter test test/redemption_code_shots_test.dart`
///
/// Writes six Czech frames: CTA and success at 390 and 1280, plus the
/// idle and focused dialog at 390.
void main() {
  if (Platform.environment['CAPTURE_REDEEM'] != '1') return;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => debugDisableShadows = false);
  tearDown(() => debugDisableShadows = true);

  testWidgets('cs frames at 390 and 1280, plus en and de spots', (
    tester,
  ) async {
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      final dir = Directory('/opt/cursor/artifacts');
      if (dir.existsSync()) {
        for (final entity in dir.listSync()) {
          if (entity is File &&
              entity.uri.pathSegments.last.startsWith('redeem-pixel-')) {
            entity.deleteSync();
          }
        }
      }
      await _captureCzech(tester, 390);
      await _captureCzech(tester, 1280);
    } finally {
      debugDisableShadows = true;
    }
  });
}

Future<void> _captureCzech(WidgetTester tester, double width) async {
  final wide = width >= 840;
  final purchases = MemoryPurchases(completeOnRefresh: false);
  await _pumpHost(tester, width: width, locale: 'cs', purchases: purchases);
  final tag = 'cs-${width.toInt()}';
  await _save(tester, 'redeem-pixel-cta-$tag.png');
  if (width != 390) {
    await _finishSuccess(tester, wide: wide, purchases: purchases, tag: tag);
    return;
  }

  await _openDialog(tester, wide: wide);
  await _save(tester, 'redeem-pixel-dialog-idle-$tag.png');
  await tester.tap(find.byKey(const Key('redeem-code-field')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await _save(tester, 'redeem-pixel-dialog-focus-$tag.png');
  await _closeDialog(tester);
  await _finishSuccess(tester, wide: wide, purchases: purchases, tag: tag);
}

Future<void> _finishSuccess(
  WidgetTester tester, {
  required bool wide,
  required MemoryPurchases purchases,
  required String tag,
}) async {
  await _openDialog(tester, wide: wide);
  await tester.enterText(
    find.byKey(const Key('redeem-code-field')),
    'AB12CD34',
  );
  await tester.tap(find.byKey(const Key('redeem-code-submit')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text(AppStrings('cs').redeemCodeSuccess), findsOneWidget);
  await _save(tester, 'redeem-pixel-success-$tag.png');
  await tester.pump(const Duration(milliseconds: 2600));
  await tester.pumpAndSettle();
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required double width,
  required String locale,
  required MemoryPurchases purchases,
}) async {
  final height = width < 600 ? 844.0 : 900.0;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  await tester.pumpWidget(const SizedBox.shrink());
  final theme = AppTheme.light();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: RedeemPixelHost(
        strings: AppStrings(locale),
        purchases: purchases,
        wide: width >= 840,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openDialog(WidgetTester tester, {required bool wide}) async {
  final key = wide
      ? const Key('challenge-sticky-pay-code')
      : const Key('challenge-floating-pay-code');
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _closeDialog(WidgetTester tester) async {
  final cancel = find.byKey(const Key('redeem-code-cancel'));
  if (cancel.evaluate().isEmpty) return;
  await tester.tap(cancel);
  await tester.pumpAndSettle();
}

Future<void> _loadFonts() async {
  Future<void> family(
    String name,
    List<String> paths, {
    bool fromBundle = false,
  }) async {
    final loader = FontLoader(name);
    for (final path in paths) {
      final Future<ByteData> data = fromBundle
          ? rootBundle.load(path)
          : File(path).readAsBytes().then(
              (bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
            );
      loader.addFont(data);
    }
    await loader.load();
  }

  await family('Roboto', const [
    '/usr/share/fonts/truetype/macos/Inter-Regular.ttf',
    '/usr/share/fonts/truetype/macos/Inter-Medium.ttf',
    '/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf',
    '/usr/share/fonts/truetype/macos/Inter-Bold.ttf',
  ]);
  await family('Onest', const [BrandTypography.fontAsset], fromBundle: true);
  await family('MaterialIcons', const [
    '/tmp/flutter-home/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _save(WidgetTester tester, String name) async {
  await tester.pump();
  goldenFileComparator = _ArtifactGolden();
  await expectLater(find.byType(MaterialApp).first, matchesGoldenFile(name));
}

class _ArtifactGolden extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final name = golden.pathSegments.isEmpty
        ? golden.toString()
        : golden.pathSegments.last;
    final file = File('/opt/cursor/artifacts/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes, flush: true);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}

/// Cream page with the real code CTA, dialog, and success snackbar.
class RedeemPixelHost extends StatefulWidget {
  const RedeemPixelHost({
    super.key,
    required this.strings,
    required this.purchases,
    required this.wide,
  });

  final AppStrings strings;
  final MemoryPurchases purchases;
  final bool wide;

  @override
  State<RedeemPixelHost> createState() => _RedeemPixelHostState();
}

class _RedeemPixelHostState extends State<RedeemPixelHost> {
  var _unlocked = false;

  Future<void> _open() async {
    final result = await showRedeemCodeDialog(
      context: context,
      strings: widget.strings,
      purchases: widget.purchases,
      challengeId: 'open-1',
    );
    if (!mounted || result != RedeemCodeDialogResult.unlocked) return;
    setState(() => _unlocked = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.strings.redeemCodeSuccess,
            style: const TextStyle(
              color: BrandColors.cream,
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: BrandColors.forest,
          duration: const Duration(milliseconds: 2500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final narrow = ChallengeCtaPanel(
      heading: strings.joinChallenge,
      diplomaLabel: strings.payDigitalDiploma,
      medalLabel: strings.haveCode,
      haveCode: true,
      loadingLabel: strings.buttonLoading,
      onDiploma: () {},
      onMedal: _open,
    );
    final wideCard = ChallengeStickyCta(
      heading: strings.joinChallenge,
      diplomaLabel: strings.payDigitalDiploma,
      medalLabel: strings.haveCode,
      haveCode: true,
      loadingLabel: strings.buttonLoading,
      onDiploma: () {},
      onMedal: _open,
    );
    return Scaffold(
      backgroundColor: BrandColors.cream,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Text(
                strings.redeemCodeHelper,
                style: const TextStyle(color: BrandColors.bark, fontSize: 16),
              ),
            ),
            if (!_unlocked && widget.wide)
              Positioned(
                top: 24,
                right: 24,
                width: ChallengeStickyCta.width,
                child: wideCard,
              ),
            if (!_unlocked && !widget.wide)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(color: BrandColors.shellFill, child: narrow),
              ),
            if (_unlocked && !widget.wide)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: BrandColors.shellFill,
                  child: SizedBox(height: 72, width: double.infinity),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
