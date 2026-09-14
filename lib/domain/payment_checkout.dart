import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// In-app FAPI checkout phases. Success is only [success] when the backend
/// purchase row is `paid` — pending never counts.
enum PaymentCheckoutPhase { loading, form, processing, timeout, success }

/// Default poll cadence while waiting for `fapi-webhook` to mark the row paid.
const kPaymentPollInterval = Duration(milliseconds: 2500);

/// Give the webhook up to two minutes before showing the timeout panel.
const kPaymentPollTimeout = Duration(seconds: 120);

/// Optional auto-pop after the confirmed-paid success panel.
const kPaymentSuccessAutoPop = Duration(seconds: 2);

/// Detection heuristic for FAPI form completion (NOT payment confirmation).
///
/// We treat the embed as "submitted / finished" when:
/// 1. The navigated URL path, query, or fragment looks like a thank-you,
///    order-status, or payment-success page (cs / en / de tokens, including
///    dekujeme / děkujeme / danke), and the host is not a known card-gateway
///    or 3-D Secure ACS; or
/// 2. Injected JavaScript posts `submit` (capture-phase `submit` listener) or
///    `thankyou-dom` (body text contains a thank-you phrase). On Flutter web
///    that arrives via `window.postMessage` when the iframe is same-origin.
///
/// Either signal starts purchase polling. The processing overlay is hidden
/// while [isPaymentGatewayUrl] is true so a 3-D Secure redirect stays
/// interactive. On Flutter web, [startQuietPaidWatch] also polls without an
/// overlay because cross-origin iframes often hide navigation. Success is
/// ONLY `purchases.status == paid` from the backend.
bool looksLikeFapiFormCompletion(Uri uri) {
  if (isPaymentGatewayUrl(uri)) return false;
  final haystack = '${uri.path} ${uri.query} ${uri.fragment}'.toLowerCase();
  const tokens = [
    'thank-you',
    'thank_you',
    'thankyou',
    'thanks',
    'dekujeme',
    'dekuji',
    'děkujeme',
    'děkuji',
    'diky',
    'díky',
    'danke',
    'order-status',
    'order_status',
    'orderstatus',
    'payment-success',
    'payment_success',
    'paymentsuccess',
    'zahlung-erfolgreich',
    'zahlung_erfolgreich',
    'zahlungerfolgreich',
    'potvrzeni',
    'potvrzení',
    'potvrzeno',
  ];
  return tokens.any(haystack.contains);
}

/// Hosts where the user must still interact (card ACS / PSP), so the cream
/// processing overlay must not cover the WebView.
bool isPaymentGatewayUrl(Uri uri) {
  final host = uri.host.toLowerCase();
  const needles = [
    '3dsecure',
    '3ds',
    'acs.',
    'comgate',
    'gopay',
    'gpwebpay',
    'thepay',
    'paypal',
    'stripe.com',
    'csob.cz',
    'kb.cz',
    'moneta',
    'securecode',
    'visa.com',
    'mastercard',
    'cardcomplete',
  ];
  return needles.any(host.contains);
}

bool _jsMessageLooksLikeSubmit(String message) {
  final value = message.toLowerCase().trim();
  return value == 'submit' || value == 'submit-click';
}

bool _jsMessageLooksLikeThankYou(String message) {
  final value = message.toLowerCase().trim();
  return value == 'thankyou-dom' || value == 'thankyou' || value == 'complete';
}

/// True when a JavaScript channel payload should start polling / overlay.
bool isFapiCheckoutJsSignal(String message) =>
    _jsMessageLooksLikeSubmit(message) || _jsMessageLooksLikeThankYou(message);

/// Polls [refreshPurchase] until the row is paid or [pollTimeout] elapses.
///
/// Does not invent a paid state. [PurchaseStatus.pending] keeps [processing].
class PaymentCheckoutController extends ChangeNotifier {
  PaymentCheckoutController({
    required this.refreshPurchase,
    this.pollInterval = kPaymentPollInterval,
    this.pollTimeout = kPaymentPollTimeout,
    Future<void> Function(Duration duration)? delay,
    DateTime Function()? clock,
  }) : delay = delay ?? _defaultDelay,
       clock = clock ?? DateTime.now;

  final Future<Purchase?> Function() refreshPurchase;
  final Duration pollInterval;
  final Duration pollTimeout;
  final Future<void> Function(Duration duration) delay;
  final DateTime Function() clock;

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);

  PaymentCheckoutPhase phase = PaymentCheckoutPhase.loading;
  Uri? currentUrl;
  var pollCount = 0;

  var _disposed = false;
  var _pollGeneration = 0;
  var _quietGeneration = 0;
  Future<void>? _inFlight;

  bool get isProcessing => phase == PaymentCheckoutPhase.processing;

  bool get isSuccess => phase == PaymentCheckoutPhase.success;

  /// Cream processing panel. Hidden on PSP / 3DS hosts so the user can finish.
  bool get showProcessingOverlay {
    if (phase != PaymentCheckoutPhase.processing) return false;
    final url = currentUrl;
    if (url == null) return true;
    return !isPaymentGatewayUrl(url);
  }

  void onWebViewLoaded() {
    if (_disposed) return;
    if (phase != PaymentCheckoutPhase.loading) return;
    phase = PaymentCheckoutPhase.form;
    notifyListeners();
  }

  void onUrlChanged(Uri url) {
    if (_disposed) return;
    currentUrl = url;
    if (looksLikeFapiFormCompletion(url)) {
      beginProcessing();
      return;
    }
    notifyListeners();
  }

  Future<void> onFormSubmitted() => beginProcessing();

  Future<void> onJsMessage(String message) {
    if (!isFapiCheckoutJsSignal(message)) return Future.value();
    return beginProcessing();
  }

  Future<void> beginProcessing() {
    if (_disposed) return Future.value();
    if (phase == PaymentCheckoutPhase.success) return Future.value();
    if (phase == PaymentCheckoutPhase.processing && _inFlight != null) {
      return _inFlight!;
    }
    phase = PaymentCheckoutPhase.processing;
    notifyListeners();
    _inFlight = _poll();
    return _inFlight!;
  }

  Future<void> retry() {
    if (_disposed) return Future.value();
    if (phase != PaymentCheckoutPhase.timeout) return Future.value();
    phase = PaymentCheckoutPhase.processing;
    notifyListeners();
    _inFlight = _poll();
    return _inFlight!;
  }

  /// Polls for `paid` without covering the form or applying [pollTimeout].
  ///
  /// Flutter web iframes often cannot observe FAPI navigation or inject a JS
  /// channel (cross-origin). This watch is the fallback so success still
  /// appears when the webhook marks the row paid. Pending never counts as paid.
  Future<void> startQuietPaidWatch() {
    if (_disposed) return Future.value();
    if (phase == PaymentCheckoutPhase.success) return Future.value();
    final generation = ++_quietGeneration;
    return _quietPoll(generation);
  }

  Future<void> _poll() async {
    final generation = ++_pollGeneration;
    final started = clock();
    while (!_disposed &&
        generation == _pollGeneration &&
        phase == PaymentCheckoutPhase.processing) {
      pollCount++;
      final purchase = await refreshPurchase();
      if (_disposed || generation != _pollGeneration) return;
      if (purchase?.status == PurchaseStatus.paid) {
        phase = PaymentCheckoutPhase.success;
        notifyListeners();
        return;
      }
      if (clock().difference(started) >= pollTimeout) {
        phase = PaymentCheckoutPhase.timeout;
        notifyListeners();
        return;
      }
      await delay(pollInterval);
    }
  }

  Future<void> _quietPoll(int generation) async {
    while (!_disposed &&
        generation == _quietGeneration &&
        phase != PaymentCheckoutPhase.success) {
      pollCount++;
      final purchase = await refreshPurchase();
      if (_disposed || generation != _quietGeneration) return;
      if (purchase?.status == PurchaseStatus.paid) {
        phase = PaymentCheckoutPhase.success;
        notifyListeners();
        return;
      }
      await delay(pollInterval);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pollGeneration++;
    _quietGeneration++;
    super.dispose();
  }
}
