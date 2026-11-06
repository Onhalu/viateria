/// VANDERY+ membership read model. The client never writes `status`.
library;

/// Wire statuses plus `none` when the user has no row.
class VanderyPlusMembership {
  const VanderyPlusMembership({
    required this.status,
    this.expiresAt,
    this.cancelAtPeriodEnd = false,
  });

  final String status;
  final DateTime? expiresAt;

  /// Soft cancel. Access lasts until [expiresAt].
  final bool cancelAtPeriodEnd;

  static const none = VanderyPlusMembership(status: 'none');

  bool isActiveAt(DateTime now) {
    final expires = expiresAt;
    return status == 'active' && expires != null && expires.isAfter(now);
  }
}

/// P3 is still a placeholder. Empty config renders this, never a made-up price.
const vanderyPlusPricePlaceholder = '—';

String vanderyPlusDisplayPrice(String? configured) {
  final trimmed = configured?.trim() ?? '';
  if (trimmed.isEmpty) return vanderyPlusPricePlaceholder;
  return trimmed;
}

VanderyPlusMembership membershipFromRow(Map<String, dynamic>? row) {
  if (row == null) return VanderyPlusMembership.none;
  final status = row['status'];
  final rawExpires = row['expires_at'];
  DateTime? expires;
  if (rawExpires is String && rawExpires.isNotEmpty) {
    expires = DateTime.tryParse(rawExpires);
  } else if (rawExpires is DateTime) {
    expires = rawExpires;
  }
  return VanderyPlusMembership(
    status: status is String ? status : 'none',
    expiresAt: expires?.toUtc(),
    cancelAtPeriodEnd: row['cancel_at_period_end'] == true,
  );
}

enum VanderyPlusPhase { idle, submitting, verifying, active, error }

enum VanderyPlusMessage { none, payFailed, cancelled, stillInactive, active }

enum VanderyPlusReturnKind { none, success, cancel }

/// FAPI return / deep link. Only `vandery_plus` is read.
/// Other query parameters are ignored. A custom-scheme link with any host
/// other than `vandery-plus` is ignored. HTTPS page URLs still parse.
VanderyPlusReturnKind parseVanderyPlusReturn(Uri uri) {
  if (uri.scheme == 'com.viateria.viateria' && uri.host != 'vandery-plus') {
    return VanderyPlusReturnKind.none;
  }
  switch (uri.queryParameters['vandery_plus']) {
    case 'return':
    case 'success':
      return VanderyPlusReturnKind.success;
    case 'cancel':
      return VanderyPlusReturnKind.cancel;
    default:
      return VanderyPlusReturnKind.none;
  }
}

/// Mobile app link. Login-callback uses the same scheme and a different host.
bool isVanderyPlusAppLink(Uri uri) {
  return uri.scheme == 'com.viateria.viateria' && uri.host == 'vandery-plus';
}

/// Draft VOP links (vyslapni-obchodni-podminky-draft). Not a published legal gate.
abstract final class VanderyPlusLegal {
  static final terms = Uri.parse('https://vyslapni.cz/obchodni-podminky/');
  static final privacy = Uri.parse(
    'https://vyslapni.cz/ochrana-osobnich-udaju/',
  );

  /// FAPI form checkboxes. Legal PASS draft, VOP publish Ask first.
  /// Not a lawyer sign-off and not published. VOP is čl. X (X.5) and
  /// Příloha 2 checkbox 3. The form itself is configured in FAPI sandbox,
  /// not rendered by the app.
  static const fapiConsentChecklist = <String>[
    'Souhlasím s Obchodními podmínkami a Zásadami ochrany osobních údajů.',
    'Žádám o okamžité zahájení poskytování digitální služby VANDERY+ a beru na vědomí, že tím ztrácím právo odstoupit od smlouvy podle § 1837 občanského zákoníku.',
    'Souhlasím s opakovaným strháváním měsíční platby, dokud předplatné nezruším e-mailem na ahoj@vyslapni.cz. Po zrušení zůstává členství aktivní do konce zaplaceného období a další platba se už nestrhne.',
  ];

  /// LG-06. Ask first. This build does not implement IAP.
  static const iosIapNote =
      'iOS App Review 3.1.x: paying for VANDERY+ with FAPI outside In-App Purchase is Ask first. Do not submit a production membership flag until Ondřej decides IAP vs FAPI.';
}
