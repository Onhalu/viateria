import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/brand_colors.dart';

/// Callbacks the FAPI [WebViewWidget] (or a test fake) uses to drive checkout.
class PaymentWebViewHost {
  const PaymentWebViewHost({
    required this.checkoutUrl,
    required this.onLoaded,
    required this.onUrlChanged,
    required this.onSubmitted,
    required this.onJsMessage,
  });

  final String checkoutUrl;
  final VoidCallback onLoaded;
  final ValueChanged<Uri> onUrlChanged;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onJsMessage;
}

typedef PaymentWebViewBuilder = Widget Function(PaymentWebViewHost host);

/// Override in widget tests so [WebViewWidget] is never constructed.
PaymentWebViewBuilder? debugPaymentWebViewBuilder;

/// WebView of the FAPI sales-form URL. See [looksLikeFapiFormCompletion] for
/// how navigation and the JS channel decide that the form finished.
class FapiCheckoutWebView extends StatefulWidget {
  const FapiCheckoutWebView({super.key, required this.host});

  final PaymentWebViewHost host;

  @override
  State<FapiCheckoutWebView> createState() => _FapiCheckoutWebViewState();
}

class _FapiCheckoutWebViewState extends State<FapiCheckoutWebView> {
  static const _channel = 'ViateriaCheckout';

  /// Capture-phase submit + thank-you body-text observer. Re-injected on every
  /// `onPageFinished` because FAPI / PSP navigations replace the document.
  static const _hookScript =
      '''
(function() {
  function post(msg) {
    try { $_channel.postMessage(msg); } catch (e) {}
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

  late final WebViewController _controller;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    final host = widget.host;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(BrandColors.cream)
      ..addJavaScriptChannel(
        _channel,
        onMessageReceived: (message) {
          host.onJsMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _emitUrl,
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _emitUrl(url);
          },
          onNavigationRequest: (request) {
            _emitUrl(request.url);
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) async {
            _emitUrl(url);
            try {
              await _controller.runJavaScript(_hookScript);
            } catch (_) {}
            _markLoaded();
          },
          onWebResourceError: (_) => _markLoaded(),
        ),
      )
      ..loadRequest(Uri.parse(host.checkoutUrl));
  }

  void _emitUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) widget.host.onUrlChanged(uri);
  }

  void _markLoaded() {
    if (_loaded) return;
    _loaded = true;
    widget.host.onLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      key: const Key('payment-webview'),
      controller: _controller,
    );
  }
}
