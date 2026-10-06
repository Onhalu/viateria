import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/data/challenge_mapping.dart';
import 'package:viateria/domain/catalog_query.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/models/models.dart';

void main() {
  test('pickLocale falls back preferred, then cs, en, de', () {
    final texts = [
      const LocalizedText(locale: 'en', title: 'English', description: 'EN'),
      const LocalizedText(locale: 'cs', title: 'Cesky', description: 'CS'),
    ];
    expect(pickLocale(texts, 'de').title, 'Cesky');
    expect(pickLocale(texts, 'en').title, 'English');
    expect(pickLocale(texts, 'fr').title, 'Cesky');
    expect(
      pickLocale([
        const LocalizedText(locale: 'cs', title: '   '),
        const LocalizedText(locale: 'en', title: 'English'),
      ], 'cs').title,
      'English',
    );
    expect(
      pickLocale(const [
        LocalizedText(locale: 'en', title: 'Only English'),
      ], 'de').title,
      'Only English',
    );
  });

  test('session locale uses the profile when signed in', () {
    expect(
      resolveSessionLocale(
        signedIn: true,
        profileLocale: 'de',
        storedLocale: 'en',
      ),
      'de',
    );
    expect(
      resolveSessionLocale(
        signedIn: true,
        profileLocale: 'fr',
        storedLocale: 'en',
      ),
      'cs',
    );
    expect(resolveSessionLocale(signedIn: false, storedLocale: 'en'), 'en');
    expect(resolveSessionLocale(signedIn: false, storedLocale: null), 'cs');
  });

  test('catalog view mapping ignores stripe sku columns', () {
    final mapped = challengeFromRow({
      'id': 'c',
      'slug': 'c',
      'access_mode': 'story',
      'pricing_type': 'paid',
      'status': 'published',
      'currency': 'czk',
      'diploma_price_cents': 19900,
      'medal_price_cents': 39900,
      'stripe_price_id_diploma': 'not-a-column',
      'stripe_price_id_medal': 'not-a-column',
      'fapi_form_url_diploma': 'https://form.fapi.cz/d',
      'fapi_form_url_medal': ' https://form.fapi.cz/m ',
      'length': 'medium',
      'is_promo': false,
      'title_cs': 'Cesky',
      'title_en': 'English',
      'title_de': '  ',
      'desc_cs': 'Popis',
      'desc_en': 'About',
      'diploma_headline': 'DIPLOM',
      'diploma_body': 'za zdolani',
    });
    expect(mapped.stripePriceId, isNull);
    expect(mapped.stripePriceIdFor(RewardVariant.diploma), isNull);
    expect(mapped.stripePriceIdFor(RewardVariant.medalAndDiploma), isNull);
    expect(mapped.priceCents, 19900);
    expect(mapped.diplomaPriceCents, 19900);
    expect(mapped.medalPriceCents, 39900);
    expect(mapped.currency, 'czk');
    expect(mapped.length, ChallengeLength.medium);
    expect(mapped.fapiFormUrlDiploma, 'https://form.fapi.cz/d');
    expect(mapped.fapiFormUrlMedal, 'https://form.fapi.cz/m');
    expect(mapped.copyFor('de').title, 'Cesky');
    expect(mapped.copyFor('de').description, 'Popis');
    expect(mapped.copyFor('en').title, 'English');
    expect(mapped.copyFor('en').diplomaHeadline, 'DIPLOM');
    expect(
      catalogLengthBandForChallenge(mapped, null),
      CatalogLengthBand.medium,
    );
  });

  test('sale forms and prices overlay a legacy challenge row', () {
    final now = DateTime.utc(2026, 10, 6, 12);
    final forms = [
      {
        'challenge_id': 'c',
        'locale': 'en',
        'reward_variant': 'diploma',
        'fapi_form_url': 'https://form.fapi.cz/en',
        'status': 'published',
        'valid_from': '2026-01-01T00:00:00Z',
      },
      {
        'challenge_id': 'c',
        'locale': 'cs',
        'reward_variant': 'diploma',
        'fapi_form_url': 'https://form.fapi.cz/cs',
        'status': 'published',
        'valid_from': '2026-01-01T00:00:00Z',
      },
      {
        'challenge_id': 'c',
        'locale': 'de',
        'reward_variant': 'medal_and_diploma',
        'fapi_form_url': 'https://form.fapi.cz/medal',
        'status': 'published',
        'valid_from': '2026-01-01T00:00:00Z',
      },
    ];
    expect(
      pickSaleFormUrl(
        forms,
        challengeId: 'c',
        rewardVariant: 'diploma',
        locale: 'de',
        now: now,
      ),
      'https://form.fapi.cz/cs',
    );
    final overlaid = overlayChallengeSatellites(
      {
        'id': 'c',
        'fapi_form_url_diploma': 'https://form.fapi.cz/legacy',
        'fapi_form_url_medal': 'https://form.fapi.cz/legacy-medal',
        'diploma_price_cents': 1,
        'medal_price_cents': 2,
        'currency': 'eur',
      },
      locale: 'en',
      saleForms: forms,
      prices: [
        {
          'challenge_id': 'c',
          'status': 'published',
          'valid_from': '2026-01-01T00:00:00Z',
          'valid_to': '2026-06-01T00:00:00Z',
          'diploma_price_cents': 100,
          'medal_price_cents': 200,
          'currency': 'czk',
        },
        {
          'challenge_id': 'c',
          'status': 'published',
          'valid_from': '2026-06-01T00:00:00Z',
          'diploma_price_cents': 19900,
          'medal_price_cents': 39900,
          'currency': 'czk',
        },
      ],
      now: now,
    );
    expect(overlaid['fapi_form_url_diploma'], 'https://form.fapi.cz/en');
    expect(overlaid['fapi_form_url_medal'], 'https://form.fapi.cz/medal');
    expect(overlaid['diploma_price_cents'], 19900);
    expect(overlaid['currency'], 'czk');
  });

  test('participation and diploma rows keep duration', () {
    final progress = progressFromRunRow('c', {
      'status': 'completed',
      'started_at': '2026-10-01T08:00:00Z',
      'completed_at': '2026-10-03T18:00:00Z',
      'duration': '2 days 10:00:00',
    });
    expect(progress.startedAt, DateTime.parse('2026-10-01T08:00:00Z'));
    expect(progress.inclusiveDayCount, 3);
    expect(progress.duration, const Duration(days: 2, hours: 10));
    expect(formatParticipationDays('cs', 1), '1 den');
    expect(formatParticipationDays('cs', 3), '3 dny');
    expect(formatParticipationDays('cs', 5), '5 dní');
    expect(formatParticipationDays('en', 1), '1 day');
    expect(formatParticipationDays('de', 3), '3 Tage');

    final issued = issuedDiplomaFromRow('c', {
      'headline': 'DIPLOM',
      'body': 'za zdolani',
      'recipient_name': 'Pavel Novak',
      'recipient_name_display': 'Pavla Novak',
      'challenge_title': 'Cesky',
      'completed_at': '2026-10-03T18:00:00Z',
      'duration': 'P2DT10H',
      'lang': 'cs',
      'period_days': 3,
    });
    expect(issued.recipientNameDisplay, 'Pavla Novak');
    expect(issued.displayDayCount, 3);
    expect(issued.challengeTitle, 'Cesky');
    expect(durationFromWire('P2DT10H'), const Duration(days: 2, hours: 10));
  });

  test('cms length filters without hike stats', () {
    const challenge = Challenge(
      id: 'c',
      slug: 'c',
      accessMode: AccessMode.open,
      pricingType: PricingType.free,
      priceCents: 0,
      currency: 'eur',
      status: PublishStatus.published,
      length: ChallengeLength.short,
      translations: [LocalizedText(locale: 'cs', title: 'Kratka')],
    );
    final matches = filterCatalogChallenges([
      challenge,
    ], const CatalogFilter(lengthBands: {CatalogLengthBand.short}));
    expect(matches, [challenge]);
    final longOnly = filterCatalogChallenges([
      challenge,
    ], const CatalogFilter(lengthBands: {CatalogLengthBand.long}));
    expect(longOnly, isEmpty);
  });
}
