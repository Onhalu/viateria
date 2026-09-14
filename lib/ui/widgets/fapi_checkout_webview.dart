import 'package:flutter/material.dart';

import 'fapi_checkout_webview_io.dart'
    if (dart.library.html) 'fapi_checkout_webview_web.dart'
    as embed;
import 'payment_webview_host.dart';

export 'payment_webview_host.dart';

/// How [FapiCheckoutWebView] embeds the sales form on this platform.
///
/// * `webview_flutter` — iOS / Android (and VM widget tests)
/// * `iframe` — Flutter web (`HtmlElementView` + `package:web`)
///
/// `webview_flutter_web` is intentionally not used: it only implements
/// `loadRequest` / `loadHtmlString`, so `WebViewController` JS channels and
/// `NavigationDelegate` throw [UnimplementedError] and `onPageFinished` never
/// clears the loading overlay.
String get kFapiCheckoutEmbedKind => embed.kFapiCheckoutEmbedKind;

/// Sales-form embed: `webview_flutter` on iOS/Android, iframe on Flutter web.
class FapiCheckoutWebView extends StatelessWidget {
  const FapiCheckoutWebView({super.key, required this.host});

  final PaymentWebViewHost host;

  @override
  Widget build(BuildContext context) {
    return embed.FapiCheckoutEmbed(host: host);
  }
}
