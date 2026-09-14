import 'package:flutter/material.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/widgets/fapi_checkout_webview.dart';

/// In-widget-test stand-in for [FapiCheckoutWebView] (no platform WebView / iframe).
class FakePaymentWebView extends StatefulWidget {
  const FakePaymentWebView({
    super.key,
    required this.host,
    this.autoLoad = true,
  });

  final PaymentWebViewHost host;
  final bool autoLoad;

  @override
  State<FakePaymentWebView> createState() => FakePaymentWebViewState();
}

class FakePaymentWebViewState extends State<FakePaymentWebView> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.host.onLoaded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('payment-fake-webview'),
      color: BrandColors.cream,
      child: Column(
        children: [
          Text(widget.host.checkoutUrl, key: const Key('payment-webview-url')),
          TextButton(
            key: const Key('payment-fake-submit'),
            onPressed: widget.host.onSubmitted,
            child: const Text('submit'),
          ),
          TextButton(
            key: const Key('payment-fake-thank-you'),
            onPressed: () {
              widget.host.onUrlChanged(
                Uri.parse('https://form.fapi.cz/dekujeme'),
              );
            },
            child: const Text('thank-you'),
          ),
        ],
      ),
    );
  }
}

PaymentWebViewBuilder fakePaymentWebViewBuilder({bool autoLoad = true}) {
  return (host) => FakePaymentWebView(host: host, autoLoad: autoLoad);
}
