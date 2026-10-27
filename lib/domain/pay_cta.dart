import '../models/models.dart';

/// How long [start-fapi-checkout] may run before the pay button times out.
///
/// A timeout is ambiguous: the row may already exist. The retry keeps the
/// same idempotency key so the server can replay that attempt.
const kPayCheckoutStartTimeout = Duration(seconds: 20);

/// Locked pay-button phases. One tap moves idle → loading. The button stays
/// locked through [success] (checkout is open). [error] and [timeout] unlock
/// onto the retry label and reuse the attempt key.
enum PayCtaPhase { idle, loading, success, error, timeout }

bool payCtaShowRetry(PayCtaPhase phase) =>
    phase == PayCtaPhase.error || phase == PayCtaPhase.timeout;

/// Cents for the pay label and the idempotency cart.
///
/// Null while the offer is in flight, or when that variant has no price, so
/// the button keeps its product name. `0` is a real free enroll.
int? payCtaPriceCents({required bool offerReady, required int? offerCents}) {
  if (!offerReady) return null;
  if (offerCents == null || offerCents < 0) return null;
  return offerCents;
}

/// Paid: „Zaplatit X Kč“ via [amountLabel]. Free: [freeLabel]. Unknown price:
/// the existing product label. A failed attempt uses [retryLabel].
String payCtaLabel({
  required String productLabel,
  required int? priceCents,
  required String? amountLabel,
  required String freeLabel,
  required bool showRetry,
  required String retryLabel,
}) {
  if (showRetry) return retryLabel;
  if (priceCents == 0) return freeLabel;
  if (priceCents != null && priceCents > 0 && amountLabel != null) {
    return amountLabel;
  }
  return productLabel;
}

/// One checkout attempt. The uuid is minted once per cart.
///
/// The same variant and price reuse [idempotencyKey], including a retry
/// after [PayCtaPhase.error] or [PayCtaPhase.timeout] and a 0 Kč enroll.
/// A different variant or a different price mints a new key.
class PayCheckoutAttempt {
  PayCheckoutAttempt({String Function()? mint}) : _mint = mint ?? _unminted;

  final String Function() _mint;

  PayCtaPhase phase = PayCtaPhase.idle;
  RewardVariant? variant;
  int? priceCents;
  String? idempotencyKey;

  /// Loading, and the moment the form is open after the server accepted.
  bool get controlsLocked =>
      phase == PayCtaPhase.loading || phase == PayCtaPhase.success;

  /// Key for this cart. Call before the request, including retries.
  ///
  /// An error or timeout retry of the same variant keeps the key even if the
  /// displayed price arrived late. A different variant, or a later tap after
  /// the price actually changed, mints a new key.
  String begin({required RewardVariant variant, required int? priceCents}) {
    final retrying =
        phase == PayCtaPhase.error || phase == PayCtaPhase.timeout;
    final sameVariantRetry =
        retrying && this.variant == variant && idempotencyKey != null;
    final sameCart = idempotencyKey != null &&
        this.variant == variant &&
        this.priceCents == priceCents;
    if (!sameCart && !sameVariantRetry) {
      idempotencyKey = _mint();
      this.variant = variant;
      this.priceCents = priceCents;
    }
    phase = PayCtaPhase.loading;
    final key = idempotencyKey;
    if (key == null || key.isEmpty) {
      throw StateError('checkout idempotency key was not minted');
    }
    return key;
  }

  void reset() {
    phase = PayCtaPhase.idle;
    variant = null;
    priceCents = null;
    idempotencyKey = null;
  }
}

String _unminted() =>
    throw StateError('PayCheckoutAttempt needs a uuid mint function');
