import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/data/memory_membership.dart';
import 'package:viateria/data/vandery_plus_session.dart';
import 'package:viateria/domain/unlock_trigger.dart';
import 'package:viateria/domain/vandery_plus.dart';

void main() {
  test('membershipFromRow matches active, soft-cancel, expired, revoked, none', () {
    final now = DateTime.utc(2026, 11, 6);
    final active = membershipFromRow({
      'status': 'active',
      'expires_at': '2026-11-26T00:00:00.000Z',
      'cancel_at_period_end': false,
    });
    expect(active.isActiveAt(now), isTrue);

    final soft = membershipFromRow({
      'status': 'active',
      'expires_at': '2026-11-11T00:00:00.000Z',
      'cancel_at_period_end': true,
    });
    expect(soft.cancelAtPeriodEnd, isTrue);
    expect(soft.isActiveAt(now), isTrue);

    final expired = membershipFromRow({
      'status': 'active',
      'expires_at': '2026-11-05T00:00:00.000Z',
    });
    expect(expired.isActiveAt(now), isFalse);
    expect(
      membershipFromRow({
        'status': 'expired',
        'expires_at': '2026-11-01T00:00:00.000Z',
      }).isActiveAt(now),
      isFalse,
    );
    expect(
      membershipFromRow({
        'status': 'revoked',
        'expires_at': '2026-12-01T00:00:00.000Z',
      }).isActiveAt(now),
      isFalse,
    );
    expect(membershipFromRow(null).isActiveAt(now), isFalse);
  });

  test('empty price stays a placeholder until P3', () {
    expect(vanderyPlusDisplayPrice(null), '—');
    expect(vanderyPlusDisplayPrice('  '), '—');
    expect(vanderyPlusDisplayPrice('599 Kč'), '599 Kč');
  });

  test('FAPI return cancel is not success', () {
    expect(
      parseVanderyPlusReturn(Uri.parse('https://app.test/back?vandery_plus=return')),
      VanderyPlusReturnKind.success,
    );
    expect(
      parseVanderyPlusReturn(Uri.parse('https://app.test/back?vandery_plus=cancel')),
      VanderyPlusReturnKind.cancel,
    );
  });

  test('client repository has no service role and no membership update', () {
    final source = File('lib/data/supabase_membership.dart').readAsStringSync();
    expect(source.contains('service_role'), isFalse);
    expect(source.contains('.update('), isFalse);
    expect(source.contains('.insert('), isFalse);
    expect(source.contains('.upsert('), isFalse);
    expect(source.contains("product': 'vandery_plus'"), isTrue);
  });

  test('pay does not activate and a second call is ignored', () async {
    final repo = MemoryMembershipRepository();
    final session = VanderyPlusSession(
      repository: repo,
      priceLabel: '599 Kč',
      clock: () => DateTime.utc(2026, 11, 6),
    );
    final first = session.pay();
    final second = session.pay();
    await Future.wait([first, second]);
    expect(repo.checkoutCalls, 1);
    expect(session.isActive, isFalse);
    expect(session.phase, VanderyPlusPhase.submitting);
  });

  test('return verifies from the server and cancel does not unlock', () async {
    final repo = MemoryMembershipRepository();
    final session = VanderyPlusSession(
      repository: repo,
      clock: () => DateTime.utc(2026, 11, 6),
    );
    await session.onReturn(VanderyPlusReturnKind.success);
    expect(session.phase, VanderyPlusPhase.error);
    expect(session.message, VanderyPlusMessage.stillInactive);
    expect(session.isActive, isFalse);

    repo.current = membershipFromRow({
      'status': 'active',
      'expires_at': '2026-12-06T00:00:00.000Z',
    });
    await session.onReturn(VanderyPlusReturnKind.success);
    expect(session.phase, VanderyPlusPhase.active);
    expect(session.message, VanderyPlusMessage.active);
    expect(session.isActive, isTrue);

    await session.onReturn(VanderyPlusReturnKind.cancel);
    expect(session.message, VanderyPlusMessage.cancelled);
    expect(playsUnlockAnimation(UnlockTrigger.checkoutCancel), isFalse);
  });

  test('legal draft links and FAPI consent checklist are present', () {
    expect(VanderyPlusLegal.terms.toString(), contains('obchodni-podminky'));
    expect(VanderyPlusLegal.privacy.toString(), contains('ochrana-osobnich-udaju'));
    expect(VanderyPlusLegal.fapiConsentChecklist.length, 3);
    expect(VanderyPlusLegal.fapiConsentChecklist[1], contains('1837'));
    expect(VanderyPlusLegal.fapiConsentChecklist[2], contains('opakovan'));
    expect(VanderyPlusLegal.iosIapNote, contains('3.1'));
  });
}
