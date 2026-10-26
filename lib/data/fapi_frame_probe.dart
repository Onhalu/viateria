import 'package:http/http.dart' as http;

import '../domain/fapi_frame_policy.dart';

/// Headers that decide whether a FAPI checkout URL may be iframed.
class FapiCheckoutHeaders {
  const FapiCheckoutHeaders({
    required this.statusCode,
    this.xFrameOptions,
    this.contentSecurityPolicy,
  });

  final int statusCode;
  final String? xFrameOptions;
  final String? contentSecurityPolicy;
}

typedef FapiCheckoutHeaderLookup = Future<FapiCheckoutHeaders> Function(
  Uri url,
);

/// Session cache keyed by origin. Tests pass [lookup] and skip the cache.
final Map<String, FapiFrameDecision> _frameDecisionCache = {};

/// Reads `X-Frame-Options` and `Content-Security-Policy` for [url].
///
/// Live `form.fapi.cz` checkout pages (checked 2026-10-13,
/// `https://form.fapi.cz/?id=10df6f32-5c5d-4ca3-9151-a1c6f28da166`) answer
/// 200 with neither header, so [decideFapiFraming] allows an iframe.
/// Browser fetches only expose headers listed in
/// `Access-Control-Expose-Headers`; that response exposes neither framing
/// header because it does not send them.
Future<FapiFrameDecision> probeFapiCheckoutFraming(
  Uri url, {
  FapiCheckoutHeaderLookup? lookup,
}) async {
  if (lookup == null) {
    final cached = _frameDecisionCache[url.origin];
    if (cached != null) return cached;
  }
  final headers = await (lookup ?? fetchFapiCheckoutHeaders)(url);
  final decision = decideFapiFraming(
    xFrameOptions: headers.xFrameOptions,
    contentSecurityPolicy: headers.contentSecurityPolicy,
  );
  if (lookup == null) _frameDecisionCache[url.origin] = decision;
  return decision;
}

/// HEAD the checkout URL, following redirects. Falls back to GET when HEAD
/// is rejected. Visible header names are already lower-case.
Future<FapiCheckoutHeaders> fetchFapiCheckoutHeaders(
  Uri url, {
  http.Client? client,
}) async {
  final owned = client == null;
  final http.Client httpClient = client ?? http.Client();
  try {
    var response = await httpClient
        .head(url)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 405 || response.statusCode == 501) {
      response = await httpClient.get(url).timeout(const Duration(seconds: 8));
    }
    return FapiCheckoutHeaders(
      statusCode: response.statusCode,
      xFrameOptions: _header(response, 'x-frame-options'),
      contentSecurityPolicy: _header(response, 'content-security-policy'),
    );
  } finally {
    if (owned) httpClient.close();
  }
}

String? _header(http.Response response, String name) {
  final value = response.headers[name];
  if (value == null || value.trim().isEmpty) return null;
  return value;
}
