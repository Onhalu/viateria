import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../domain/payment_checkout.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';
import '../widgets/fapi_checkout_webview.dart';

/// Full-screen in-app FAPI checkout. Body is the sales-form WebView; cream
/// overlays cover loading, processing, timeout, and confirmed-paid success.
class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({
    super.key,
    required this.challengeId,
    required this.checkoutUrl,
    this.controller,
    this.webViewBuilder,
    this.autoPopAfterSuccess = kPaymentSuccessAutoPop,
  });

  final String challengeId;
  final String checkoutUrl;
  final PaymentCheckoutController? controller;
  final PaymentWebViewBuilder? webViewBuilder;
  final Duration? autoPopAfterSuccess;

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  late final PaymentCheckoutController _controller;
  var _ownsController = false;
  var _autoPopScheduled = false;
  Timer? _autoPopTimer;

  @override
  void initState() {
    super.initState();
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
    } else {
      _ownsController = true;
      _controller = PaymentCheckoutController(refreshPurchase: _refresh);
    }
    _controller.addListener(_onControllerTick);
  }

  Future<Purchase?> _refresh() {
    return context.read<AppServices>().purchases.refreshPurchase(
      widget.challengeId,
    );
  }

  void _onControllerTick() {
    if (!mounted) return;
    setState(() {});
    final autoPop = widget.autoPopAfterSuccess;
    if (autoPop == null || _autoPopScheduled) return;
    if (_controller.phase != PaymentCheckoutPhase.success) return;
    _autoPopScheduled = true;
    _autoPopTimer = Timer(autoPop, () {
      if (!mounted) return;
      if (_controller.phase != PaymentCheckoutPhase.success) return;
      Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _autoPopTimer?.cancel();
    _controller.removeListener(_onControllerTick);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final strings = ctx.read<LocaleController>().strings;
        return AlertDialog(
          key: const Key('payment-leave-dialog'),
          backgroundColor: BrandColors.cream,
          title: Text(strings.paymentLeaveConfirm),
          actions: [
            TextButton(
              key: const Key('payment-stay'),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.paymentStay),
            ),
            FilledButton(
              key: const Key('payment-leave'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.paymentLeave),
            ),
          ],
        );
      },
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  void _popToChallenge() {
    Navigator.of(context).pop(_controller.isSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final builder =
        widget.webViewBuilder ??
        debugPaymentWebViewBuilder ??
        (host) => FapiCheckoutWebView(host: host);
    final host = PaymentWebViewHost(
      checkoutUrl: widget.checkoutUrl,
      onLoaded: _controller.onWebViewLoaded,
      onUrlChanged: _controller.onUrlChanged,
      onSubmitted: () {
        _controller.onFormSubmitted();
      },
      onJsMessage: (message) {
        _controller.onJsMessage(message);
      },
    );
    return PopScope(
      canPop: !_controller.isProcessing,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        key: const Key('payment-checkout-screen'),
        backgroundColor: BrandColors.cream,
        appBar: AppBar(
          backgroundColor: BrandColors.cream,
          foregroundColor: BrandColors.forest,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(strings.paymentTitle),
          leading: BackButton(
            color: BrandColors.forest,
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(child: builder(host)),
            if (_controller.phase == PaymentCheckoutPhase.loading)
              const _PaymentLoadingPanel(),
            if (_controller.showProcessingOverlay)
              const _PaymentProcessingPanel(),
            if (_controller.phase == PaymentCheckoutPhase.timeout)
              _PaymentTimeoutPanel(
                strings: strings,
                onBack: _popToChallenge,
                onRetry: () {
                  _controller.retry();
                },
              ),
            if (_controller.phase == PaymentCheckoutPhase.success)
              _PaymentSuccessPanel(strings: strings, onBack: _popToChallenge),
          ],
        ),
      ),
    );
  }
}

class _PaymentLoadingPanel extends StatelessWidget {
  const _PaymentLoadingPanel();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return ColoredBox(
      key: const Key('payment-loading'),
      color: BrandColors.cream,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: BrandColors.forest),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                strings.paymentLoadingForm,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BrandColors.forest,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentProcessingPanel extends StatelessWidget {
  const _PaymentProcessingPanel();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return ColoredBox(
      key: const Key('payment-processing'),
      color: BrandColors.cream,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_top,
                key: Key('payment-processing-icon'),
                size: 56,
                color: BrandColors.forest,
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: BrandColors.forest),
              const SizedBox(height: 20),
              Text(
                strings.paymentProcessingTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BrandColors.forest,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.paymentProcessingBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: BrandColors.bark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTimeoutPanel extends StatelessWidget {
  const _PaymentTimeoutPanel({
    required this.strings,
    required this.onBack,
    required this.onRetry,
  });

  final AppStrings strings;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('payment-timeout'),
      color: BrandColors.cream,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_empty,
                size: 56,
                color: BrandColors.forest,
              ),
              const SizedBox(height: 16),
              Text(
                strings.paymentTimeoutBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BrandColors.bark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('payment-back-to-challenge'),
                onPressed: onBack,
                child: Text(strings.paymentBackToChallenge),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('payment-retry'),
                onPressed: onRetry,
                child: Text(strings.paymentRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSuccessPanel extends StatelessWidget {
  const _PaymentSuccessPanel({required this.strings, required this.onBack});

  final AppStrings strings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('payment-success'),
      color: BrandColors.cream,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: BrandColors.cream,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    key: Key('payment-success-icon'),
                    size: 72,
                    color: BrandColors.forest,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.paymentSuccessTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: BrandColors.forest,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.paymentSuccessBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: BrandColors.bark),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('payment-back-to-challenge'),
                    onPressed: onBack,
                    child: Text(strings.paymentBackToChallenge),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
