import 'package:flutter/foundation.dart';

/// OAuth, magic-link, and password-reset redirects for the single Supabase client.
///
/// Mobile uses a custom scheme. `supabase_flutter` (PKCE, the default)
/// watches that URL via its deep-link observer and exchanges the `code`
/// for a session. Web uses the page the app is already on, with the query
/// and fragment stripped so the allow-list entry is stable.
///
/// Verified against Supabase Flutter deep-link docs and `signInWithOAuth`
/// for supabase_flutter 2.17: redirect form is `scheme://host`, and the
/// provider callback registered at Google and Apple is Supabase's HTTPS
/// `/auth/v1/callback`, not this app URL.
abstract final class AuthRedirect {
  static const scheme = 'com.viateria.viateria';
  static const host = 'login-callback';

  /// Exact string sent as `redirectTo` on iOS and Android.
  static const mobile = '$scheme://$host';

  /// Production web origin (`base-href` `/`).
  static const webProduction = 'https://viateria.limitlessdreams.cz/';

  /// Authorized redirect URI for the Google web client and the Apple
  /// Services ID. Paste this into those consoles, not [mobile].
  static const supabaseProviderCallback =
      'https://yzmbxxgesnbsqygzgdky.supabase.co/auth/v1/callback';

  static String forCurrentPlatform() {
    if (kIsWeb) return webRedirectFrom(Uri.base);
    return mobile;
  }

  /// Public so tests can lock the web shape without a browser.
  static String webRedirectFrom(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return webProduction;
    // Uri.replace(query: '', fragment: '') keeps a stray `?` and `#`.
    // Rebuild so the allow-list entry is only scheme, host, port, and path.
    final port = uri.hasPort ? uri.port : null;
    var path = uri.path;
    if (path.isEmpty) path = '/';
    if (!path.endsWith('/')) path = '$path/';
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: port,
      path: path,
    ).toString();
  }
}
