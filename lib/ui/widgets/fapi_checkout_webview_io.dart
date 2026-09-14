import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/brand_colors.dart';
import 'payment_webview_host.dart';

/// iOS / Android embed. See [kFapiCheckoutEmbedKind].
const kFapiCheckoutEmbedKind = 'webview_flutter';

/// Platform [WebViewWidget] wrapping the FAPI sales-form URL.
class FapiCheckoutEmbed extends StatefulWidget {
  const FapiCheckoutEmbed({super.key, required this.host});

  final PaymentWebViewHost host;

  @override
  State<FapiCheckoutEmbed> createState() => _FapiCheckoutEmbedState();
}

class _FapiCheckoutEmbedState extends State<FapiCheckoutEmbed> {
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
        kFapiCheckoutJsChannel,
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
              await _controller.runJavaScript(kFapiCheckoutHookScript);
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
