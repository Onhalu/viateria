import 'package:flutter/foundation.dart';

import '../domain/vandery_plus.dart';
import 'membership_repository.dart';

/// Paywall and map gate share this. Webhook remains the source of truth:
/// [pay] never sets the membership active.
class VanderyPlusSession extends ChangeNotifier {
  VanderyPlusSession({
    required this.repository,
    this.priceLabel = '',
    DateTime Function()? clock,
    this.openUrl,
  }) : _clock = clock ?? DateTime.now;

  final MembershipRepository repository;
  final String priceLabel;
  final DateTime Function() _clock;
  final Future<void> Function(Uri url)? openUrl;

  VanderyPlusMembership membership = VanderyPlusMembership.none;
  VanderyPlusPhase phase = VanderyPlusPhase.idle;
  VanderyPlusMessage message = VanderyPlusMessage.none;
  var _busy = false;

  DateTime get now => _clock();

  bool get isActive => membership.isActiveAt(now);

  String get displayPrice => vanderyPlusDisplayPrice(priceLabel);

  bool get lockDismiss =>
      phase == VanderyPlusPhase.submitting ||
      phase == VanderyPlusPhase.verifying;

  Future<void> refresh() async {
    final wasVerifying = phase == VanderyPlusPhase.verifying;
    try {
      membership = await repository.fetchMine();
      if (wasVerifying) {
        if (isActive) {
          phase = VanderyPlusPhase.active;
          message = VanderyPlusMessage.active;
        } else {
          phase = VanderyPlusPhase.error;
          message = VanderyPlusMessage.stillInactive;
        }
      } else if (isActive) {
        phase = VanderyPlusPhase.active;
      }
    } catch (_) {
      membership = VanderyPlusMembership.none;
      if (wasVerifying) {
        phase = VanderyPlusPhase.error;
        message = VanderyPlusMessage.stillInactive;
      }
    }
    notifyListeners();
  }

  /// Opens FAPI. A second call while busy or verifying is ignored.
  Future<void> pay() async {
    if (_busy ||
        phase == VanderyPlusPhase.submitting ||
        phase == VanderyPlusPhase.verifying) {
      return;
    }
    _busy = true;
    phase = VanderyPlusPhase.submitting;
    message = VanderyPlusMessage.none;
    notifyListeners();
    try {
      final url = await repository.startCheckout();
      final opener = openUrl;
      if (opener != null) await opener(url);
    } catch (_) {
      phase = VanderyPlusPhase.error;
      message = VanderyPlusMessage.payFailed;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Deep link or web return URL. `none` does nothing.
  Future<void> consumeReturnUri(Uri uri) {
    return onReturn(parseVanderyPlusReturn(uri));
  }

  /// The app came back from the FAPI form without a new URL.
  /// Only a checkout that is still [VanderyPlusPhase.submitting] is polled.
  Future<void> onAppResumed() {
    if (phase != VanderyPlusPhase.submitting) return Future.value();
    return onReturn(VanderyPlusReturnKind.success);
  }

  Future<void> onReturn(VanderyPlusReturnKind kind) async {
    if (kind == VanderyPlusReturnKind.cancel) {
      phase = VanderyPlusPhase.error;
      message = VanderyPlusMessage.cancelled;
      notifyListeners();
      return;
    }
    if (kind != VanderyPlusReturnKind.success) return;
    phase = VanderyPlusPhase.verifying;
    message = VanderyPlusMessage.none;
    notifyListeners();
    await refresh();
  }
}
