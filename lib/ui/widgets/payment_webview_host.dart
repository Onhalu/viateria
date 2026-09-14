import 'package:flutter/material.dart';

/// Callbacks the FAPI checkout embed (or a test fake) uses to drive checkout.
class PaymentWebViewHost {
  const PaymentWebViewHost({
    required this.checkoutUrl,
    required this.onLoaded,
    required this.onUrlChanged,
    required this.onSubmitted,
    required this.onJsMessage,
    this.onNeedPaidWatch,
  });

  final String checkoutUrl;
  final VoidCallback onLoaded;
  final ValueChanged<Uri> onUrlChanged;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onJsMessage;

  /// Flutter web iframes often cannot read cross-origin navigation or inject
  /// JS channels. The embed calls this after the first load so the controller
  /// can poll for `purchases.status = paid` without covering the form.
  final VoidCallback? onNeedPaidWatch;
}

typedef PaymentWebViewBuilder = Widget Function(PaymentWebViewHost host);

/// Override in widget tests so the platform WebView / iframe is never built.
PaymentWebViewBuilder? debugPaymentWebViewBuilder;

/// Capture-phase submit + thank-you body-text observer. Re-injected on every
/// mobile `onPageFinished` because FAPI / PSP navigations replace the document.
///
/// Flutter web uses [kFapiCheckoutWebHookScript] (`parent.postMessage`) instead
/// of a `webview_flutter` JavaScript channel.
const kFapiCheckoutJsChannel = 'ViateriaCheckout';

const kFapiCheckoutHookScript =
    '''
(function() {
  function post(msg) {
    try { $kFapiCheckoutJsChannel.postMessage(msg); } catch (e) {}
  }
  if (!window.__viateriaSubmitHooked) {
    window.__viateriaSubmitHooked = true;
    document.addEventListener('submit', function() { post('submit'); }, true);
  }
  var t = (document.body && document.body.innerText || '').toLowerCase();
  if (
    t.indexOf('děkujeme') !== -1 ||
    t.indexOf('dekujeme') !== -1 ||
    t.indexOf('thank you') !== -1 ||
    t.indexOf('danke') !== -1 ||
    t.indexOf('platba byla') !== -1 ||
    t.indexOf('zahlung erfolgreich') !== -1 ||
    t.indexOf('payment successful') !== -1
  ) {
    post('thankyou-dom');
  }
})();
''';

/// Same-origin iframe hook. Cross-origin FAPI frames cannot be scripted; the
/// parent still listens for `message` and quietly polls for paid.
const kFapiCheckoutWebHookScript =
    '''
(function() {
  function post(msg) {
    try { parent.postMessage(msg, '*'); } catch (e) {}
  }
  if (!window.__viateriaSubmitHooked) {
    window.__viateriaSubmitHooked = true;
    document.addEventListener('submit', function() { post('submit'); }, true);
  }
  var t = (document.body && document.body.innerText || '').toLowerCase();
  if (
    t.indexOf('děkujeme') !== -1 ||
    t.indexOf('dekujeme') !== -1 ||
    t.indexOf('thank you') !== -1 ||
    t.indexOf('danke') !== -1 ||
    t.indexOf('platba byla') !== -1 ||
    t.indexOf('zahlung erfolgreich') !== -1 ||
    t.indexOf('payment successful') !== -1
  ) {
    post('thankyou-dom');
  }
})();
''';

/// Interprets iframe load events for Flutter web checkout.
///
/// [url] is omitted when the iframe is cross-origin (typical for FAPI). The
/// first load still dismisses the loading overlay; later loads only start
/// processing when a readable thank-you URL is available. Pending is never
/// treated as paid.
void handleFapiWebIFrameLoad({
  required PaymentWebViewHost host,
  required bool isFirstLoad,
  Uri? url,
}) {
  if (isFirstLoad) {
    host.onLoaded();
    host.onNeedPaidWatch?.call();
  }
  if (url != null) host.onUrlChanged(url);
}

/// Parses `window.postMessage` payloads into the same strings the mobile JS
/// channel sends (`submit`, `thankyou-dom`, …).
String? fapiCheckoutPostMessageText(Object? data) {
  if (data is String) {
    final text = data.trim();
    return text.isEmpty ? null : text;
  }
  return null;
}
