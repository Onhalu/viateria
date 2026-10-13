import 'package:web/web.dart' as web;

/// Browsing-context name for the FAPI popup. Not `_blank`, so combined with
/// a feature string it opens a window rather than a tab.
const kFapiCheckoutPopupTarget = 'viateriaFapiCheckout';

web.Window? _popup;

({double width, double height}) readFapiScreenSize() {
  final screen = web.window.screen;
  final width = screen.availWidth.toDouble();
  final height = screen.availHeight.toDouble();
  if (width > 0 && height > 0) {
    return (width: width, height: height);
  }
  return (
    width: web.window.innerWidth.toDouble(),
    height: web.window.innerHeight.toDouble(),
  );
}

/// Opens [url] with [features] (`width` / `height` / `left` / `top`).
///
/// Returns false when the browser blocks the window.
bool openCenteredFapiPopup(String url, String features) {
  closeFapiPopup();
  final opened = web.window.open(url, kFapiCheckoutPopupTarget, features);
  if (opened == null || opened.closed) {
    _popup = null;
    return false;
  }
  _popup = opened;
  return true;
}

void closeFapiPopup() {
  final popup = _popup;
  _popup = null;
  if (popup == null) return;
  try {
    popup.close();
  } catch (_) {}
}
