import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/domain/fapi_offer.dart';

void main() {
  test('fapi-offer json keeps a zero price and drops a bad terms url', () {
    final offer = FapiOffer.fromJson({
      'diploma': {
        'price_cents': 0,
        'currency': 'EUR',
        'terms_url': 'https://example.com/terms',
        'terms': [
          {'text': 'Podmínky', 'url': 'not a url'},
        ],
      },
      'medal': null,
    });
    expect(offer.diploma.priceCents, 0);
    expect(offer.diploma.currency, 'eur');
    expect(offer.diploma.termsUrl, 'https://example.com/terms');
    expect(offer.diploma.terms.single.text, 'Podmínky');
    expect(offer.diploma.terms.single.url, isNull);
    expect(offer.medal.priceCents, isNull);
    expect(
      formatPayButtonPrice(
        cents: 0,
        currency: 'eur',
        locale: 'cs',
        freeLabel: 'Zdarma',
      ),
      'Zdarma',
    );
    expect(
      formatPayButtonPrice(
        cents: null,
        currency: 'eur',
        locale: 'en',
        freeLabel: 'Free',
      ),
      isNull,
    );
  });
}
