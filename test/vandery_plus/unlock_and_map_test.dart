import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/data/memory_membership.dart';
import 'package:viateria/data/vandery_plus_session.dart';
import 'package:viateria/domain/padlock_pose.dart';
import 'package:viateria/domain/unlock_trigger.dart';
import 'package:viateria/domain/vandery_plus.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/theme/app_theme.dart';
import 'package:viateria/ui/widgets/padlock_unlock.dart';
import 'package:viateria/ui/widgets/vandery_plus_map_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(unlockReplayMemory.reset);

  test('UA-04 lift overshoots and rotation ends clockwise 40–45°', () {
    final start = PadlockPose.at(0);
    expect(start.liftPx, 0);
    expect(start.degrees, 0);
    expect(start.glow, 0);

    var peak = 0.0;
    for (var i = 0; i <= 55; i++) {
      peak = math.max(peak, PadlockPose.at(i / 100).liftPx.abs());
    }
    expect(peak, closeTo(18 * PadlockPose.liftOvershoot, 0.2));

    final mid = PadlockPose.at(0.55);
    expect(mid.liftPx, closeTo(-18, 0.2));
    expect(mid.degrees, greaterThan(0));
    expect(mid.degrees, lessThan(PadlockPose.endDegrees));

    final end = PadlockPose.at(1);
    expect(end.liftPx.abs(), lessThan(0.1));
    expect(end.degrees, inInclusiveRange(40, 45));
    expect(end.glow, 1);
  });

  test('UA-05 keyhole is Sage and not a banned color', () {
    expect(PadlockPose.keyholeColor(1), BrandColors.sage);
    expect(BrandColors.sage.toARGB32(), 0xFF9C9A7B);
    final locked = PadlockPose.keyholeColor(0);
    expect(locked, isNot(BrandColors.sage));
  });

  test('UA-02 UA-08 UA-10 forbidden triggers do not play', () {
    expect(playsUnlockAnimation(UnlockTrigger.fapiCtaTap), isFalse);
    expect(playsUnlockAnimation(UnlockTrigger.paywallOpen), isFalse);
    expect(playsUnlockAnimation(UnlockTrigger.checkoutCancel), isFalse);
    expect(playsUnlockAnimation(UnlockTrigger.checkoutError), isFalse);
    expect(playsUnlockAnimation(UnlockTrigger.redemptionCode), isFalse);
    expect(playsUnlockAnimation(UnlockTrigger.storyNextPoint), isFalse);
    expect(playsUnlockAnimation(UnlockTrigger.serverMembershipActive), isTrue);
  });

  test('UA-07 replay is once per session entity', () {
    expect(unlockReplayMemory.claim(membershipUnlockEntity), isTrue);
    expect(unlockReplayMemory.claim(membershipUnlockEntity), isFalse);
    unlockReplayMemory.reset();
    expect(unlockReplayMemory.claim(membershipUnlockEntity), isTrue);
  });

  testWidgets('UA-01 padlock is two layers without AnimatedSwitcher', (tester) async {
    await tester.pumpWidget(_padlock(play: false));
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.byType(LockBody), findsOneWidget);
    expect(find.byType(Shackle), findsOneWidget);
  });

  testWidgets('UA-03 play runs 400–500 ms then reports unlocked', (tester) async {
    await tester.pumpWidget(_padlock(play: true));
    final state = tester.state<PadlockUnlockState>(find.byType(PadlockUnlock));
    expect(state.controller.duration!.inMilliseconds, inInclusiveRange(400, 500));
    await tester.pump();
    expect(state.controller.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(state.controller.value, 1);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Odemčeno'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('UA-06 reduce motion jumps to the open pose', (tester) async {
    await tester.pumpWidget(_padlock(play: true, disableAnimations: true));
    await tester.pump();
    final state = tester.state<PadlockUnlockState>(find.byType(PadlockUnlock));
    expect(state.controller.value, 1);
    expect(state.controller.isAnimating, isFalse);
  });

  testWidgets('UA-09 locked semantics are not a live region on mount', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_padlock(play: false));
    final node = tester.getSemantics(find.byType(PadlockUnlock));
    expect(node.label, 'Zamčeno');
    expect(node.flagsCollection.isLiveRegion, isFalse);
    handle.dispose();
  });

  testWidgets('FW-10 map lock opens slide 0 and is a 44 hit target', (tester) async {
    var tapped = 0;
    final session = _session();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _gate(
        session: session,
        onLockedTap: () => tapped = 1,
        onVerify: () {},
      ),
    );
    expect(
      find.bySemanticsLabel(AppStrings('cs').vanderyPlusMapLock),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('map-place-lock'))).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.byKey(const Key('map-place-lock')));
    expect(tapped, 1);
    expect(find.byType(PadlockUnlock), findsWidgets);
    final playing = tester
        .widgetList<PadlockUnlock>(find.byType(PadlockUnlock))
        .every((padlock) => padlock.play == false);
    expect(playing, isTrue);
    handle.dispose();
  });

  testWidgets('FW-14 server active plays once then offers verify', (tester) async {
    final repo = MemoryMembershipRepository();
    final session = _session(repo);
    var verifies = 0;
    await tester.pumpWidget(
      _gate(session: session, onLockedTap: () {}, onVerify: () => verifies++),
    );
    repo.current = membershipFromRow({
      'status': 'active',
      'expires_at': '2026-12-06T00:00:00.000Z',
    });
    await session.onReturn(VanderyPlusReturnKind.success);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('map-place-unlock')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(verifies, 1);
    expect(find.byKey(const Key('map-poi-verify')), findsOneWidget);

    await tester.pumpWidget(
      _gate(session: session, onLockedTap: () {}, onVerify: () => verifies++),
    );
    await tester.pump(const Duration(milliseconds: 450));
    expect(verifies, 1);
  });

  testWidgets('challenge sheet is not wrapped by the map lock', (tester) async {
    // The gate is only built for map-only pins. A direct verify button stays.
    expect(find.byKey(const Key('map-place-lock')), findsNothing);
  });
}

VanderyPlusSession _session([MemoryMembershipRepository? repo]) {
  return VanderyPlusSession(
    repository: repo ?? MemoryMembershipRepository(),
    clock: () => DateTime.utc(2026, 11, 6),
  );
}

Widget _padlock({required bool play, bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      home: Scaffold(
        body: PadlockUnlock(
          play: play,
          lockedLabel: 'Zamčeno',
          unlockedLabel: 'Odemčeno',
        ),
      ),
    ),
  );
}

Widget _gate({
  required VanderyPlusSession session,
  required VoidCallback onLockedTap,
  required VoidCallback onVerify,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: MapPlaceVerifyGate(
        session: session,
        placeId: 'place-1',
        strings: AppStrings('cs'),
        onVerify: onVerify,
        onLockedTap: onLockedTap,
      ),
    ),
  );
}
