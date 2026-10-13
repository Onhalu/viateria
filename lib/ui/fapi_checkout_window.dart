import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/fapi_frame_probe.dart';
import '../domain/fapi_frame_policy.dart';
import '../l10n/locale_controller.dart';
import '../theme/brand_colors.dart';
import 'fapi_checkout_popup_io.dart'
    if (dart.library.html) 'fapi_checkout_popup_web.dart'
    if (dart.library.js_interop) 'fapi_checkout_popup_web.dart'
    as popup;
import 'screens/payment_checkout_screen.dart';
import 'widgets/fapi_checkout_webview.dart';

typedef FapiPopupOpener = bool Function(String url, String features);

/// Opens a FAPI checkout inside the app.
///
/// Web: a centered dialog with an iframe when framing headers allow it,
/// otherwise a centered `window.open` popup (width/height/left/top) plus a
/// status dialog that still polls for a paid purchase. Mobile: the same
/// dialog around `webview_flutter`, never an external browser.
///
/// Pops `true` after a confirmed payment. Callers reload so the reward
/// unlocks.
Future<bool?> showInAppFapiCheckout(
  BuildContext context, {
  required String challengeId,
  required String checkoutUrl,
  FapiCheckoutPresentation? presentation,
  Future<FapiFrameDecision> Function(Uri url)? probe,
  FapiPopupOpener? openPopup,
  ({double width, double height})? screenSize,
}) async {
  final mode = presentation ?? await _presentationFor(checkoutUrl, probe);
  if (!context.mounted) return null;

  var popupOpened = false;
  String? features;
  if (mode == FapiCheckoutPresentation.centeredPopup) {
    final screen = screenSize ?? popup.readFapiScreenSize();
    features = fapiCenteredPopupFeatures(
      screenWidth: screen.width,
      screenHeight: screen.height,
    );
    popupOpened = (openPopup ?? popup.openCenteredFapiPopup)(
      checkoutUrl,
      features,
    );
  }

  final strings = context.read<LocaleController>().strings;
  final reopen = features == null
      ? null
      : () =>
            (openPopup ?? popup.openCenteredFapiPopup)(checkoutUrl, features!);

  return showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: strings.paymentTitle,
    barrierColor: const Color(0x99000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, _) {
      return _FapiCheckoutDialog(
        challengeId: challengeId,
        checkoutUrl: checkoutUrl,
        presentation: mode,
        popupOpened: popupOpened,
        onReopenPopup: reopen,
      );
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

Future<FapiCheckoutPresentation> _presentationFor(
  String checkoutUrl,
  Future<FapiFrameDecision> Function(Uri url)? probe,
) async {
  if (kFapiCheckoutEmbedKind != 'iframe') {
    return FapiCheckoutPresentation.embeddedDialog;
  }
  FapiFrameDecision decision;
  try {
    decision = await (probe ?? probeFapiCheckoutFraming)(
      Uri.parse(checkoutUrl),
    );
  } catch (_) {
    decision = const FapiFrameDecision.blocked('headers_unavailable');
  }
  return fapiCheckoutPresentation(
    embedKind: kFapiCheckoutEmbedKind,
    decision: decision,
  );
}

class _FapiCheckoutDialog extends StatefulWidget {
  const _FapiCheckoutDialog({
    required this.challengeId,
    required this.checkoutUrl,
    required this.presentation,
    required this.popupOpened,
    required this.onReopenPopup,
  });

  final String challengeId;
  final String checkoutUrl;
  final FapiCheckoutPresentation presentation;
  final bool popupOpened;
  final bool Function()? onReopenPopup;

  @override
  State<_FapiCheckoutDialog> createState() => _FapiCheckoutDialogState();
}

class _FapiCheckoutDialogState extends State<_FapiCheckoutDialog> {
  late bool _popupOpened;

  @override
  void initState() {
    super.initState();
    _popupOpened = widget.popupOpened;
  }

  @override
  void dispose() {
    if (widget.presentation == FapiCheckoutPresentation.centeredPopup) {
      popup.closeFapiPopup();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final media = MediaQuery.of(context);
    final window = fapiCheckoutWindowSize(
      viewportWidth: media.size.width,
      viewportHeight: media.size.height,
      safeHorizontal: media.padding.horizontal,
      safeVertical: media.padding.vertical,
    );
    return Center(
      child: SizedBox(
        key: const Key('payment-checkout-dialog'),
        width: window.width,
        height: window.height,
        child: Material(
          color: BrandColors.cream,
          elevation: 12,
          shadowColor: const Color(0x66000000),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        strings.paymentTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BrandColors.forest,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('payment-checkout-close'),
                      tooltip: strings.paymentClose,
                      color: BrandColors.forest,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bodyHeight = mathMax(
                      constraints.maxHeight,
                      kFapiCheckoutFormMinHeight,
                    );
                    return SingleChildScrollView(
                      key: const Key('payment-checkout-scroll'),
                      child: SizedBox(
                        height: bodyHeight,
                        width: constraints.maxWidth,
                        child: PaymentCheckoutScreen(
                          challengeId: widget.challengeId,
                          checkoutUrl: widget.checkoutUrl,
                          showAppBar: false,
                          webViewBuilder:
                              widget.presentation ==
                                  FapiCheckoutPresentation.centeredPopup
                              ? _popupBuilder
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popupBuilder(PaymentWebViewHost host) {
    return _FapiPopupNotice(
      host: host,
      opened: _popupOpened,
      onRetry: widget.onReopenPopup == null
          ? null
          : () {
              final opened = widget.onReopenPopup!();
              if (mounted) setState(() => _popupOpened = opened);
              return opened;
            },
    );
  }
}

double mathMax(double a, double b) => a > b ? a : b;

/// Status body used when the sales form cannot be framed.
///
/// Starts the same quiet paid-watch as the iframe so a webhook still
/// unlocks the reward. The form itself is in the centered popup.
class _FapiPopupNotice extends StatefulWidget {
  const _FapiPopupNotice({
    required this.host,
    required this.opened,
    required this.onRetry,
  });

  final PaymentWebViewHost host;
  final bool opened;
  final bool Function()? onRetry;

  @override
  State<_FapiPopupNotice> createState() => _FapiPopupNoticeState();
}

class _FapiPopupNoticeState extends State<_FapiPopupNotice> {
  var _startedWatch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void didUpdateWidget(covariant _FapiPopupNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.opened && !oldWidget.opened) _arm();
  }

  void _arm() {
    if (!mounted) return;
    widget.host.onLoaded();
    if (!widget.opened || _startedWatch) return;
    _startedWatch = true;
    widget.host.onNeedPaidWatch?.call();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return ColoredBox(
      key: const Key('payment-checkout-popup-fallback'),
      color: BrandColors.cream,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.open_in_new,
                size: 48,
                color: BrandColors.forest,
              ),
              const SizedBox(height: 16),
              Text(
                strings.paymentPopupTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BrandColors.forest,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.opened
                    ? strings.paymentPopupBody
                    : strings.paymentPopupBlocked,
                textAlign: TextAlign.center,
                style: const TextStyle(color: BrandColors.bark),
              ),
              if (!widget.opened && widget.onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('payment-popup-retry'),
                  onPressed: () {
                    final opened = widget.onRetry!();
                    if (opened) _arm();
                  },
                  child: Text(strings.paymentPopupRetry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
