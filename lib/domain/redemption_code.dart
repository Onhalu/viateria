import '../models/enums.dart';

/// Why a redemption did not unlock the challenge.
///
/// [invalidCode], [alreadyRedeemed], and [challengeMismatch] share one
/// friendly sentence in the dialog so the client does not reveal whether
/// a code exists for another challenge.
enum RedeemCodeError {
  invalidCode,
  expired,
  emailMismatch,
  alreadyRedeemed,
  alreadyUnlocked,
  rateLimited,
  challengeMismatch,
  network,
}

/// Outcome of [PurchaseRepository.redeemChallengeCode].
class RedeemCodeResult {
  const RedeemCodeResult.unlocked() : alreadyUnlocked = false, error = null;

  const RedeemCodeResult.alreadyUnlocked()
    : alreadyUnlocked = true,
      error = null;

  const RedeemCodeResult.failure(this.error) : alreadyUnlocked = false;

  /// The challenge was already paid. The code was not consumed.
  final bool alreadyUnlocked;

  final RedeemCodeError? error;

  bool get unlocked => error == null && !alreadyUnlocked;
}

final RegExp _redemptionCodePattern = RegExp(r'^[A-Z0-9]{8,16}$');

/// `upper(trim)`, then strip spaces and dashes. Null when the result is not
/// 8–16 characters of A–Z and 0–9 (OQ-R4).
String? normalizeRedemptionCode(String raw) {
  if (raw.length > 64) return null;
  final stripped = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '');
  if (!_redemptionCodePattern.hasMatch(stripped)) return null;
  return stripped;
}

/// Open + paid + not yet paid. Story challenges keep the medal checkout.
bool showsHaveCodeCta({
  required AccessMode accessMode,
  required PricingType pricingType,
  required bool hasPaidUnlock,
}) {
  return accessMode == AccessMode.open &&
      pricingType == PricingType.paid &&
      !hasPaidUnlock;
}

RedeemCodeError? redeemCodeErrorFromWire(String? code) => switch (code) {
  'invalid_code' => RedeemCodeError.invalidCode,
  'expired' => RedeemCodeError.expired,
  'email_mismatch' => RedeemCodeError.emailMismatch,
  'already_redeemed' => RedeemCodeError.alreadyRedeemed,
  'already_unlocked' => RedeemCodeError.alreadyUnlocked,
  'rate_limited' => RedeemCodeError.rateLimited,
  'challenge_mismatch' => RedeemCodeError.challengeMismatch,
  _ => null,
};
