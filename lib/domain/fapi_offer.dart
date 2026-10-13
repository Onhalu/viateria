import '../models/models.dart';

/// One condition line from a FAPI sales form (purpose text and/or link).
class FapiOfferTerm {
  const FapiOfferTerm({required this.text, this.url});

  final String text;
  final String? url;

  factory FapiOfferTerm.fromJson(Map<String, dynamic> json) {
    return FapiOfferTerm(
      text: (json['text'] as String?)?.trim() ?? '',
      url: httpUrlOrNull(json['url'] as String?),
    );
  }
}

/// Price and terms for one reward variant, as returned by `fapi-offer`.
///
/// [priceCents] is null when that variant's form could not be read.
/// `0` is a real FAPI price and must be shown as free.
class FapiOfferVariant {
  const FapiOfferVariant({
    required this.priceCents,
    required this.currency,
    this.termsUrl,
    this.terms = const [],
  });

  final int? priceCents;
  final String currency;
  final String? termsUrl;
  final List<FapiOfferTerm> terms;

  static const unknown = FapiOfferVariant(priceCents: null, currency: '');

  factory FapiOfferVariant.fromJson(Object? raw) {
    if (raw is! Map) return unknown;
    final json = Map<String, dynamic>.from(raw);
    final cents = json['price_cents'];
    final terms = <FapiOfferTerm>[];
    final rows = json['terms'];
    if (rows is List) {
      for (final row in rows) {
        if (row is Map) {
          terms.add(FapiOfferTerm.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    return FapiOfferVariant(
      priceCents: cents is num ? cents.round() : null,
      currency: (json['currency'] as String?)?.trim().toLowerCase() ?? '',
      termsUrl: httpUrlOrNull(json['terms_url'] as String?),
      terms: terms,
    );
  }
}

/// Diploma and medal offers from the `fapi-offer` Edge function.
class FapiOffer {
  const FapiOffer({required this.diploma, required this.medal});

  final FapiOfferVariant diploma;
  final FapiOfferVariant medal;

  factory FapiOffer.fromJson(Map<String, dynamic> json) {
    return FapiOffer(
      diploma: FapiOfferVariant.fromJson(json['diploma']),
      medal: FapiOfferVariant.fromJson(json['medal']),
    );
  }
}
