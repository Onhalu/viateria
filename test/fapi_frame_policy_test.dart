import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/data/fapi_frame_probe.dart';
import 'package:viateria/domain/fapi_frame_policy.dart';

void main() {
  test('missing framing headers allow an iframe', () {
    // Live form.fapi.cz checkout (2026-10-13), after the ?id= → ?path=
    // redirect, returns 200 with no X-Frame-Options and no CSP.
    final decision = decideFapiFraming(
      xFrameOptions: null,
      contentSecurityPolicy: null,
    );
    expect(decision.allowsFraming, isTrue);
    expect(
      fapiCheckoutPresentation(embedKind: 'iframe', decision: decision),
      FapiCheckoutPresentation.embeddedDialog,
    );
  });

  test('X-Frame-Options and frame-ancestors that block foreign parents', () {
    expect(
      decideFapiFraming(xFrameOptions: 'DENY').reason,
      'x_frame_options_deny',
    );
    expect(
      decideFapiFraming(xFrameOptions: 'deny').reason,
      'x_frame_options_deny',
    );
    expect(
      decideFapiFraming(xFrameOptions: 'SAMEORIGIN').reason,
      'x_frame_options_sameorigin',
    );
    expect(
      decideFapiFraming(xFrameOptions: 'ALLOW-FROM https://shop.example')
          .reason,
      'x_frame_options_allow_from',
    );
    expect(
      decideFapiFraming(contentSecurityPolicy: "frame-ancestors 'none'").reason,
      'csp_frame_ancestors_none',
    );
    expect(
      decideFapiFraming(
        contentSecurityPolicy: "default-src 'self'; frame-ancestors 'self'",
      ).reason,
      'csp_frame_ancestors',
    );
    expect(
      decideFapiFraming(
        contentSecurityPolicy: 'frame-ancestors https://shop.example',
      ).reason,
      'csp_frame_ancestors',
    );
  });

  test('CSP frame-ancestors overrides a blocking X-Frame-Options', () {
    final allowed = decideFapiFraming(
      xFrameOptions: 'DENY',
      contentSecurityPolicy: "frame-ancestors *",
    );
    expect(allowed.allowsFraming, isTrue);

    final scheme = decideFapiFraming(
      contentSecurityPolicy: "frame-ancestors 'self' https:",
    );
    expect(scheme.allowsFraming, isTrue);

    final otherDirectives = decideFapiFraming(
      contentSecurityPolicy: "default-src 'none'; script-src 'self'",
    );
    expect(otherDirectives.allowsFraming, isTrue);
  });

  test('webview embed stays a dialog even when framing is denied', () {
    final denied = decideFapiFraming(xFrameOptions: 'DENY');
    expect(
      fapiCheckoutPresentation(embedKind: 'webview_flutter', decision: denied),
      FapiCheckoutPresentation.embeddedDialog,
    );
    expect(
      fapiCheckoutPresentation(embedKind: 'iframe', decision: denied),
      FapiCheckoutPresentation.centeredPopup,
    );
  });

  test('window size is min(560, 92vw) by min(860, 92vh)', () {
    final desktop = fapiCheckoutWindowSize(
      viewportWidth: 1200,
      viewportHeight: 1000,
    );
    expect(desktop.width, 560);
    expect(desktop.height, 860);

    final narrow = fapiCheckoutWindowSize(
      viewportWidth: 400,
      viewportHeight: 500,
    );
    expect(narrow.width, closeTo(368, 0.001));
    expect(narrow.height, closeTo(460, 0.001));

    final notched = fapiCheckoutWindowSize(
      viewportWidth: 400,
      viewportHeight: 800,
      safeHorizontal: 0,
      safeVertical: 120,
    );
    expect(notched.height, closeTo(680, 0.001));
  });

  test('popup features center a window and are not a tab target', () {
    final features = fapiCenteredPopupFeatures(
      screenWidth: 1200,
      screenHeight: 900,
    );
    expect(features, contains('popup=yes'));
    expect(features, contains('width=560'));
    expect(features, contains('height=828'));
    expect(features, contains('left=320'));
    expect(features, contains('top=36'));
    expect(features, contains('scrollbars=yes'));
    expect(features.contains('_blank'), isFalse);
  });

  test('probe maps fetched headers without calling the network', () async {
    final decision = await probeFapiCheckoutFraming(
      Uri.parse('https://form.fapi.cz/diploma-test'),
      lookup: (url) async {
        expect(url.host, 'form.fapi.cz');
        return const FapiCheckoutHeaders(
          statusCode: 200,
          xFrameOptions: 'SAMEORIGIN',
        );
      },
    );
    expect(decision.allowsFraming, isFalse);
    expect(decision.reason, 'x_frame_options_sameorigin');
  });
}
