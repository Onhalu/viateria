import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../theme/brand_colors.dart';
import 'payment_webview_host.dart';

/// Flutter web embed. See [kFapiCheckoutEmbedKind].
const kFapiCheckoutEmbedKind = 'iframe';

/// IFrame of the FAPI sales-form URL via [HtmlElementView].
///
/// `webview_flutter` has no endorsed web implementation; constructing
/// [WebViewController] on web asserts `WebViewPlatform.instance != null`.
/// This path never creates a [WebViewController].
class FapiCheckoutEmbed extends StatefulWidget {
  const FapiCheckoutEmbed({super.key, required this.host});

  final PaymentWebViewHost host;

  @override
  State<FapiCheckoutEmbed> createState() => _FapiCheckoutEmbedState();
}

class _FapiCheckoutEmbedState extends State<FapiCheckoutEmbed> {
  web.HTMLIFrameElement? _iframe;
  web.EventListener? _loadListener;
  web.EventListener? _messageListener;
  var _firstLoadDone = false;

  @override
  void initState() {
    super.initState();
    _messageListener = ((web.Event event) {
      _onWindowMessage(event);
    }).toJS;
    web.window.addEventListener('message', _messageListener);
  }

  @override
  void dispose() {
    final iframe = _iframe;
    final loadListener = _loadListener;
    if (iframe != null && loadListener != null) {
      iframe.removeEventListener('load', loadListener);
    }
    final messageListener = _messageListener;
    if (messageListener != null) {
      web.window.removeEventListener('message', messageListener);
    }
    super.dispose();
  }

  void _onElementCreated(Object element) {
    final iframe = element as web.HTMLIFrameElement;
    _iframe = iframe;
    iframe
      ..src = widget.host.checkoutUrl
      ..title = 'FAPI checkout'
      ..allow = 'payment *; publickey-credentials-get *'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..style.backgroundColor = BrandColors.creamHex;
    _loadListener = ((web.Event event) {
      _onIFrameLoad(event);
    }).toJS;
    iframe.addEventListener('load', _loadListener);
  }

  void _onIFrameLoad(web.Event _) {
    final iframe = _iframe;
    final url = iframe == null ? null : _tryReadIFrameUrl(iframe);
    final isFirstLoad = !_firstLoadDone;
    _firstLoadDone = true;
    handleFapiWebIFrameLoad(
      host: widget.host,
      isFirstLoad: isFirstLoad,
      url: url,
    );
    if (iframe != null) _tryInjectHook(iframe);
  }

  void _onWindowMessage(web.Event event) {
    final message = event as web.MessageEvent;
    final text = fapiCheckoutPostMessageText(_jsStringData(message.data));
    if (text != null) widget.host.onJsMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: const Key('payment-webview'),
      tagName: 'iframe',
      onElementCreated: _onElementCreated,
    );
  }
}

Uri? _tryReadIFrameUrl(web.HTMLIFrameElement iframe) {
  try {
    final href = iframe.contentWindow?.location.href;
    if (href == null || href.isEmpty || href == 'about:blank') return null;
    return Uri.tryParse(href);
  } catch (_) {
    return null;
  }
}

void _tryInjectHook(web.HTMLIFrameElement iframe) {
  try {
    final doc = iframe.contentDocument;
    if (doc == null) return;
    final script = web.HTMLScriptElement()
      ..type = 'text/javascript'
      ..text = kFapiCheckoutWebHookScript;
    doc.documentElement?.append(script);
  } catch (_) {}
}

Object? _jsStringData(JSAny? data) {
  if (data == null) return null;
  if (data.isA<JSString>()) return (data as JSString).toDart;
  return null;
}
