import 'dart:math' as math;

/// How an in-app FAPI checkout is shown.
///
/// Mobile and VM tests always use [embeddedDialog] (`webview_flutter`).
/// Flutter web uses [embeddedDialog] when the checkout response allows
/// framing, and [centeredPopup] when `X-Frame-Options` or CSP
/// `frame-ancestors` forbids it.
enum FapiCheckoutPresentation { embeddedDialog, centeredPopup }

/// Result of reading framing headers for a FAPI checkout URL.
class FapiFrameDecision {
  const FapiFrameDecision.allowed() : allowsFraming = true, reason = null;

  const FapiFrameDecision.blocked(this.reason) : allowsFraming = false;

  final bool allowsFraming;

  /// Stable reason when [allowsFraming] is false (`x_frame_options_deny`, …).
  final String? reason;
}

/// Outer size of the in-app checkout window.
///
/// `min(560, 92vw)` by `min(860, 92vh)`, then shrunk by [safeHorizontal] /
/// [safeVertical] so the window stays inside the safe area.
const double kFapiCheckoutDialogMaxWidth = 560;

const double kFapiCheckoutDialogMaxHeight = 860;

const double kFapiCheckoutDialogViewportFraction = 0.92;

/// Minimum height of the form body. Shorter windows scroll inside.
const double kFapiCheckoutFormMinHeight = 720;

class FapiCheckoutWindowSize {
  const FapiCheckoutWindowSize(this.width, this.height);

  final double width;
  final double height;
}

FapiCheckoutWindowSize fapiCheckoutWindowSize({
  required double viewportWidth,
  required double viewportHeight,
  double safeHorizontal = 0,
  double safeVertical = 0,
}) {
  final maxWidth = math.min(
    kFapiCheckoutDialogMaxWidth,
    viewportWidth * kFapiCheckoutDialogViewportFraction,
  );
  final maxHeight = math.min(
    kFapiCheckoutDialogMaxHeight,
    viewportHeight * kFapiCheckoutDialogViewportFraction,
  );
  final width = math.max(
    0.0,
    math.min(maxWidth, viewportWidth - safeHorizontal),
  );
  final height = math.max(
    0.0,
    math.min(maxHeight, viewportHeight - safeVertical),
  );
  return FapiCheckoutWindowSize(width, height);
}

/// `window.open` feature string for a centered popup (not a browser tab).
///
/// Includes `width`, `height`, `left`, and `top`. The target name must not
/// be `_blank`.
String fapiCenteredPopupFeatures({
  required double screenWidth,
  required double screenHeight,
}) {
  final window = fapiCheckoutWindowSize(
    viewportWidth: screenWidth,
    viewportHeight: screenHeight,
  );
  final width = window.width.round();
  final height = window.height.round();
  final left = math.max(0, ((screenWidth - window.width) / 2).round());
  final top = math.max(0, ((screenHeight - window.height) / 2).round());
  return 'popup=yes,width=$width,height=$height,left=$left,top=$top,'
      'resizable=yes,scrollbars=yes';
}

/// `iframe` plus a blocking decision selects the popup. Every other embed
/// (the in-app WebView) stays a dialog — `X-Frame-Options` does not apply
/// to a top-level WebView navigation.
FapiCheckoutPresentation fapiCheckoutPresentation({
  required String embedKind,
  required FapiFrameDecision decision,
}) {
  if (embedKind != 'iframe') return FapiCheckoutPresentation.embeddedDialog;
  if (decision.allowsFraming) return FapiCheckoutPresentation.embeddedDialog;
  return FapiCheckoutPresentation.centeredPopup;
}

/// Whether a checkout response may be shown in an iframe.
///
/// When CSP `frame-ancestors` is present it replaces `X-Frame-Options`,
/// matching browsers. Missing framing headers allow the frame (this is what
/// `form.fapi.cz` checkout URLs return).
FapiFrameDecision decideFapiFraming({
  String? xFrameOptions,
  String? contentSecurityPolicy,
}) {
  final ancestors = _frameAncestors(contentSecurityPolicy);
  if (ancestors != null) {
    if (ancestors.isEmpty || ancestors.any(_isNoneSource)) {
      return const FapiFrameDecision.blocked('csp_frame_ancestors_none');
    }
    if (ancestors.any(_sourceAllowsForeignParent)) {
      return const FapiFrameDecision.allowed();
    }
    return const FapiFrameDecision.blocked('csp_frame_ancestors');
  }

  final xfo = xFrameOptions?.trim();
  if (xfo == null || xfo.isEmpty) {
    return const FapiFrameDecision.allowed();
  }
  final token = xfo.split(RegExp(r'[\s,;]+')).first.toUpperCase();
  return switch (token) {
    'DENY' => const FapiFrameDecision.blocked('x_frame_options_deny'),
    'SAMEORIGIN' => const FapiFrameDecision.blocked(
      'x_frame_options_sameorigin',
    ),
    'ALLOW-FROM' => const FapiFrameDecision.blocked(
      'x_frame_options_allow_from',
    ),
    _ => const FapiFrameDecision.allowed(),
  };
}

List<String>? _frameAncestors(String? csp) {
  if (csp == null || csp.trim().isEmpty) return null;
  List<String>? sources;
  for (final part in csp.split(';')) {
    final tokens = part
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) continue;
    if (tokens.first.toLowerCase() != 'frame-ancestors') continue;
    sources = tokens.skip(1).map((token) => token.toLowerCase()).toList();
  }
  return sources;
}

bool _isNoneSource(String source) => source == "'none'" || source == 'none';

bool _sourceAllowsForeignParent(String source) {
  return source == '*' ||
      source == 'https:' ||
      source == 'http:' ||
      source == 'https://*' ||
      source == 'http://*';
}
