import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/config/app_config.dart';
import 'package:viateria/data/app_services.dart';
import 'package:viateria/data/challenge_mapping.dart';
import 'package:viateria/data/last_opened_challenge.dart';
import 'package:viateria/domain/challenge_reward.dart';
import 'package:viateria/domain/fapi_offer.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/domain/story_feed.dart';
import 'package:viateria/domain/story_fog.dart';
import 'package:viateria/domain/youtube_url.dart';
import 'package:viateria/l10n/app_strings.dart';
import 'package:viateria/l10n/locale_controller.dart';
import 'package:viateria/map/place.dart';
import 'package:viateria/map/place_catalog.dart';
import 'package:viateria/map/place_category.dart';
import 'package:viateria/map/story_fog_icon.dart';
import 'package:viateria/models/models.dart';
import 'package:viateria/theme/brand_colors.dart';
import 'package:viateria/ui/screens/challenge_screen.dart';
import 'package:viateria/ui/screens/verify_waypoint_screen.dart';
import 'package:viateria/ui/widgets/challenge_map.dart';
import 'package:viateria/ui/widgets/fapi_checkout_webview.dart';
import 'package:viateria/ui/widgets/route_planner_panel.dart';
import 'package:viateria/ui/widgets/story_chapter_card.dart';

import 'helpers/fake_payment_webview.dart';
import 'helpers/fakes.dart';
import 'helpers/map_harness.dart';

ChallengeDetail _story() {
  const challenge = Challenge(
    id: 'story-mock',
    slug: 'story-mock',
    accessMode: AccessMode.story,
    pricingType: PricingType.free,
    priceCents: 0,
    currency: 'czk',
    status: PublishStatus.published,
    countryCode: 'CZ',
    translations: [
      LocalizedText(
        locale: 'cs',
        title: 'Příběhová výzva (mock)',
        description: 'Lineární výprava.',
      ),
      LocalizedText(locale: 'en', title: 'Story challenge (mock)'),
    ],
  );
  final waypoints = [
    const Waypoint(
      id: 'w0',
      challengeId: 'story-mock',
      sortOrder: 0,
      lat: 50.611389,
      lng: 16.115,
      elevationM: 500,
      placeId: 'adrspach',
      category: PlaceCategory.nature,
      translations: [
        LocalizedText(locale: 'cs', title: 'Adršpašské skály', hint: 'Skála'),
        LocalizedText(locale: 'en', title: 'Adršpach rocks'),
      ],
    ),
    const Waypoint(
      id: 'w1',
      challengeId: 'story-mock',
      sortOrder: 1,
      lat: 49.3732361,
      lng: 16.7298156,
      elevationM: 400,
      placeId: 'macocha',
      category: PlaceCategory.nature,
      translations: [
        LocalizedText(locale: 'cs', title: 'Propast Macocha'),
        LocalizedText(locale: 'en', title: 'Macocha abyss'),
      ],
    ),
    const Waypoint(
      id: 'w2',
      challengeId: 'story-mock',
      sortOrder: 2,
      lat: 49.300278,
      lng: 17.393056,
      elevationM: 200,
      placeId: 'kromeriz',
      category: PlaceCategory.historical,
      translations: [
        LocalizedText(locale: 'cs', title: 'Zámek Kroměříž'),
        LocalizedText(locale: 'en', title: 'Kroměříž castle'),
      ],
    ),
  ];
  final steps = [
    const StoryStep(
      id: 's-open',
      challengeId: 'story-mock',
      sortOrder: 0,
      kind: StoryStepKind.opening,
      youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      translations: [
        LocalizedText(
          locale: 'cs',
          title: 'Úvod výzvy',
          description: 'Vítej v příběhové výpravě.',
        ),
        LocalizedText(
          locale: 'en',
          title: 'Challenge intro',
          description: 'Welcome.',
        ),
      ],
    ),
    const StoryStep(
      id: 's-b0',
      challengeId: 'story-mock',
      sortOrder: 1,
      kind: StoryStepKind.beforeWaypoint,
      waypointId: 'w0',
      translations: [
        LocalizedText(
          locale: 'cs',
          title: 'Před Adršpachem',
          description: 'Mlha se zvedá.',
        ),
      ],
    ),
    const StoryStep(
      id: 's-b1',
      challengeId: 'story-mock',
      sortOrder: 2,
      kind: StoryStepKind.beforeWaypoint,
      waypointId: 'w1',
      imageUrl: 'https://images.example.test/macocha.jpg',
      translations: [
        LocalizedText(
          locale: 'cs',
          title: 'Cesta k Macoše',
          description: 'Po skále přichází propast.',
        ),
      ],
    ),
    const StoryStep(
      id: 's-empty',
      challengeId: 'story-mock',
      sortOrder: 3,
      kind: StoryStepKind.beforeWaypoint,
      waypointId: 'w2',
      translations: [
        LocalizedText(locale: 'cs', title: 'Bez média', description: ''),
      ],
    ),
    const StoryStep(
      id: 's-close',
      challengeId: 'story-mock',
      sortOrder: 4,
      kind: StoryStepKind.closing,
      translations: [
        LocalizedText(
          locale: 'cs',
          title: 'Závěr výzvy',
          description: 'Hotovo. Příběh končí.',
        ),
      ],
    ),
  ];
  return ChallengeDetail(
    challenge: challenge,
    waypoints: waypoints,
    storySteps: steps,
  );
}

/// Same intro, chapters, and closing as [_story], sold as a paid challenge.
ChallengeDetail _paidStory() {
  final base = _story();
  return ChallengeDetail(
    challenge: Challenge(
      id: base.challenge.id,
      slug: base.challenge.slug,
      accessMode: AccessMode.story,
      pricingType: PricingType.paid,
      priceCents: 499,
      diplomaPriceCents: 499,
      medalPriceCents: 900,
      currency: 'eur',
      status: base.challenge.status,
      countryCode: base.challenge.countryCode,
      translations: base.challenge.translations,
      fapiFormUrlDiploma: 'https://form.fapi.cz/diploma-test',
      fapiFormUrlMedal: 'https://form.fapi.cz/medal-test',
    ),
    waypoints: base.waypoints,
    storySteps: base.storySteps,
  );
}

List<String> _labels(List<ChallengeFeedItem> feed, String locale) {
  return [
    for (final item in feed)
      if (item is StoryFeedChapter)
        'chapter:${item.step.id}'
      else if (item is StoryFeedPlace)
        'place:${item.waypoint.id}:${item.unlocked}',
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cs en de name the locked stop without spoiling it', () {
    expect(AppStrings('cs').storyNextStop, 'Další zastávka');
    expect(AppStrings('en').storyNextStop, 'Next stop');
    expect(AppStrings('de').storyNextStop, 'Nächster Halt');
    expect(AppStrings('cs').storyFogLocked, 'Nejdřív dolož předchozí místo');
    expect(AppStrings('en').storyFogLocked, 'Verify the previous place first');
    expect(AppStrings('de').storyFogLocked, 'Belege zuerst den vorherigen Ort');
  });

  test('youtube ids come from watch, share, embed, and shorts urls', () {
    expect(
      youtubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(youtubeVideoId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    expect(
      youtubeVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      youtubeVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(youtubeVideoId('https://example.com/watch?v=dQw4w9WgXcQ'), isNull);
    expect(youtubeEmbedUri('dQw4w9WgXcQ').host, 'www.youtube-nocookie.com');
  });

  test('story feed is opening, first place, then locked generic stops', () {
    final detail = _story();
    final feed = buildChallengeFeed(
      mode: AccessMode.story,
      hasAccess: true,
      ordered: detail.orderedWaypoints,
      steps: detail.orderedStorySteps,
      completedIds: const {},
    );
    expect(_labels(feed, 'cs'), [
      'chapter:s-open',
      'chapter:s-b0',
      'place:w0:true',
      'place:w1:false',
      'place:w2:false',
      'chapter:s-close',
    ]);
    expect(
      storyPlaceTitle(
        mode: AccessMode.story,
        unlocked: false,
        completed: false,
        waypoint: detail.orderedWaypoints[1],
        locale: 'cs',
        lockedTitle: AppStrings('cs').storyNextStop,
      ),
      'Další zastávka',
    );
    expect(
      storyPlaceTitle(
        mode: AccessMode.story,
        unlocked: true,
        completed: false,
        waypoint: detail.orderedWaypoints[0],
        locale: 'cs',
        lockedTitle: 'Další zastávka',
      ),
      'Adršpašské skály',
    );
  });

  test(
    'unpaid story keeps the intro and closing, and reveals a verified stop',
    () {
      final detail = _story();
      final feed = buildChallengeFeed(
        mode: AccessMode.story,
        hasAccess: false,
        ordered: detail.orderedWaypoints,
        steps: detail.orderedStorySteps,
        completedIds: const {'w0'},
      );
      expect(_labels(feed, 'cs'), [
        'chapter:s-open',
        'place:w0:false',
        'place:w1:false',
        'place:w2:false',
        'chapter:s-close',
      ]);
      expect(
        storyPlaceTitle(
          mode: AccessMode.story,
          unlocked: false,
          completed: true,
          waypoint: detail.orderedWaypoints[0],
          locale: 'cs',
          lockedTitle: 'Další zastávka',
        ),
        'Adršpašské skály',
      );
      expect(
        storyHiddenWaypointIds(
          mode: AccessMode.story,
          hasAccess: false,
          ordered: detail.orderedWaypoints,
          completedIds: const {'w0'},
        ),
        {'w1', 'w2'},
      );
    },
  );

  test('after the first verify the next chapter and place unlock', () {
    final detail = _story();
    final feed = buildChallengeFeed(
      mode: AccessMode.story,
      hasAccess: true,
      ordered: detail.orderedWaypoints,
      steps: detail.orderedStorySteps,
      completedIds: const {'w0'},
    );
    expect(_labels(feed, 'cs'), [
      'chapter:s-open',
      'chapter:s-b0',
      'place:w0:true',
      'chapter:s-b1',
      'place:w1:true',
      'place:w2:false',
      'chapter:s-close',
    ]);
    final hints = storyStepIdsAfterVerify(
      detail: detail,
      verifiedWaypointId: 'w0',
      completedIds: const {'w0'},
    );
    expect(hints.nextStoryStepId, 's-b1');
    expect(hints.unlockedWaypointId, 'w1');
    expect(hints.closingStoryStepId, isNull);
  });

  test('closing is always last, and empty media is skipped', () {
    final detail = _story();
    final early = buildChallengeFeed(
      mode: AccessMode.story,
      hasAccess: true,
      ordered: detail.orderedWaypoints,
      steps: detail.orderedStorySteps,
      completedIds: const {},
    );
    expect(early.whereType<StoryFeedChapter>().last.step.id, 's-close');
    final feed = buildChallengeFeed(
      mode: AccessMode.story,
      hasAccess: true,
      ordered: detail.orderedWaypoints,
      steps: detail.orderedStorySteps,
      completedIds: const {'w0', 'w1', 'w2'},
    );
    expect(
      feed.whereType<StoryFeedChapter>().map((item) => item.step.id),
      containsAll(['s-open', 's-b0', 's-b1', 's-close']),
    );
    expect(
      feed.whereType<StoryFeedChapter>().map((item) => item.step.id),
      isNot(contains('s-empty')),
    );
    final hints = storyStepIdsAfterVerify(
      detail: detail,
      verifiedWaypointId: 'w2',
      completedIds: const {'w0', 'w1', 'w2'},
    );
    expect(hints.closingStoryStepId, 's-close');
    expect(hints.nextStoryStepId, isNull);
  });

  test('open mode ignores story steps and keeps real titles', () {
    final detail = _story();
    final open = Challenge(
      id: detail.challenge.id,
      slug: detail.challenge.slug,
      accessMode: AccessMode.open,
      pricingType: PricingType.free,
      priceCents: 0,
      currency: 'czk',
      status: PublishStatus.published,
      translations: detail.challenge.translations,
    );
    final feed = buildChallengeFeed(
      mode: AccessMode.open,
      hasAccess: true,
      ordered: detail.orderedWaypoints,
      steps: detail.orderedStorySteps,
      completedIds: const {},
    );
    expect(feed.whereType<StoryFeedChapter>(), isEmpty);
    expect(
      feed.whereType<StoryFeedPlace>().every((item) => item.unlocked),
      isTrue,
    );
    expect(
      storyPlaceTitle(
        mode: open.accessMode,
        unlocked: true,
        completed: false,
        waypoint: detail.orderedWaypoints[2],
        locale: 'en',
        lockedTitle: 'Next stop',
      ),
      'Kroměříž castle',
    );
    expect(
      storyHiddenWaypointIds(
        mode: AccessMode.open,
        hasAccess: true,
        ordered: detail.orderedWaypoints,
        completedIds: const {},
      ),
      isEmpty,
    );
  });

  test('fog pins stay kilometres from every true coordinate', () {
    final detail = _story();
    final hidden = storyHiddenWaypointIds(
      mode: AccessMode.story,
      hasAccess: true,
      ordered: detail.orderedWaypoints,
      completedIds: const {},
    );
    expect(hidden, {'w1', 'w2'});
    final fog = storyFogPins(
      ordered: detail.orderedWaypoints,
      hiddenIds: hidden,
    );
    expect(fog.map((pin) => pin.waypointId), ['w1', 'w2']);
    final again = storyFogPins(
      ordered: detail.orderedWaypoints,
      hiddenIds: hidden,
    );
    expect(sameStoryFog(fog, again), isTrue);
    final truths = [
      for (final waypoint in detail.orderedWaypoints) waypoint.latLng,
    ];
    for (final pin in fog) {
      for (final truth in truths) {
        expect(
          metersBetween(pin.position, truth),
          greaterThanOrEqualTo(storyFogMinSeparationMeters),
        );
      }
      final own = detail.orderedWaypoints
          .firstWhere((waypoint) => waypoint.id == pin.waypointId)
          .latLng;
      expect(metersBetween(pin.position, own), greaterThan(250));
    }
    final anchors = storyMapAnchors(
      ordered: detail.orderedWaypoints,
      hiddenIds: hidden,
      fog: fog,
    );
    expect(anchors.first.latitude, closeTo(50.611389, 0.0001));
    for (final locked in [
      detail.orderedWaypoints[1],
      detail.orderedWaypoints[2],
    ]) {
      expect(
        anchors.any((point) => metersBetween(point, locked.latLng) < 250),
        isFalse,
      );
    }
  });

  test('a tight cluster still refuses a 200 m jitter', () {
    final ordered = [
      for (var i = 0; i < 3; i++)
        Waypoint(
          id: 'near-$i',
          challengeId: 'c',
          sortOrder: i,
          lat: 50.0 + i * 0.0004,
          lng: 14.0,
          elevationM: 0,
          translations: const [LocalizedText(locale: 'cs', title: 'Blízko')],
        ),
    ];
    final fog = storyFogPins(
      ordered: ordered,
      hiddenIds: const {'near-1', 'near-2'},
    );
    for (final pin in fog) {
      for (final waypoint in ordered) {
        expect(
          metersBetween(pin.position, waypoint.latLng),
          greaterThanOrEqualTo(storyFogMinSeparationMeters),
        );
      }
    }
  });

  test('story steps map from the embed and skip an unknown kind', () {
    final steps = storyStepsFromRows([
      {
        'id': 's1',
        'challenge_id': 'c',
        'sort_order': 2,
        'kind': 'closing',
        'waypoint_id': null,
        'youtube_url': '  ',
        'image_url': 'not a url',
        'challenge_story_step_i18n': [
          {'locale': 'de', 'title': 'Schluss', 'body': 'Ende'},
        ],
      },
      {
        'id': 's0',
        'challenge_id': 'c',
        'sort_order': 0,
        'kind': 'opening',
        'youtube_url': 'https://youtu.be/dQw4w9WgXcQ',
        'challenge_story_step_i18n': [
          {'locale': 'cs', 'title': 'Úvod', 'body': ''},
        ],
      },
      {'id': 'bad', 'challenge_id': 'c', 'sort_order': 9, 'kind': 'epilogue'},
    ]);
    expect(steps.map((step) => step.id), ['s0', 's1']);
    expect(steps.first.youtubeUrl, 'https://youtu.be/dQw4w9WgXcQ');
    expect(steps.last.copyFor('de').title, 'Schluss');
    expect(steps.last.imageUrl, isNull);
  });

  test('0016 and 0017 match the approved story schema', () {
    final schema = File('supabase/migrations/0016_challenge_story_steps.sql')
        .readAsStringSync();
    final enrich = File(
      'supabase/migrations/0017_verify_waypoint_story_enrich.sql',
    ).readAsStringSync();
    expect(schema, contains('challenge_story_steps'));
    expect(schema, contains('challenge_story_step_i18n'));
    expect(schema, contains("'opening'"));
    expect(schema, contains("'before_waypoint'"));
    expect(schema, contains("'closing'"));
    expect(schema, contains('story-mock'));
    expect(schema.toLowerCase(), isNot(contains('service_role')));
    expect(enrich, contains('next_story_step_id'));
    expect(enrich, contains('closing_story_step_id'));
    expect(enrich, contains('unlocked_waypoint_id'));
    expect(enrich, contains('previous waypoint incomplete'));
    expect(enrich, contains('user_has_promo_challenge'));
    expect(enrich.toLowerCase(), isNot(contains('service_role')));
  });

  test('memory verify returns the next story step id', () async {
    final detail = _story();
    final progress = MemoryProgress(details: [detail]);
    final after = await progress.verifyWaypoint(
      challengeId: detail.challenge.id,
      waypointId: 'w0',
      photoPath: 'user-1/story-mock/w0/p.jpg',
    );
    expect(after.nextStoryStepId, 's-b1');
    expect(after.unlockedWaypointId, 'w1');
    expect(after.closingStoryStepId, isNull);
    await progress.verifyWaypoint(
      challengeId: detail.challenge.id,
      waypointId: 'w1',
      photoPath: 'user-1/story-mock/w1/p.jpg',
    );
    final done = await progress.verifyWaypoint(
      challengeId: detail.challenge.id,
      waypointId: 'w2',
      photoPath: 'user-1/story-mock/w2/p.jpg',
    );
    expect(done.isCompleted, isTrue);
    expect(done.closingStoryStepId, 's-close');
  });

  test('fog marker png is a sage question mark, not a logo', () async {
    final bytes = await storyQuestionMarkPng();
    expect(bytes.length, greaterThan(80));
    final dir = Directory('/opt/cursor/artifacts/screenshots');
    if (dir.existsSync()) {
      await File('${dir.path}/story-fog-marker.png').writeAsBytes(bytes);
    }
  });

  testWidgets('story list hides locked names and expands a cream chapter', (
    tester,
  ) async {
    await _pumpStory(tester, progressIds: const {});
    expect(find.text('Úvod výzvy'), findsOneWidget);
    expect(find.text('Před Adršpachem'), findsOneWidget);
    expect(find.text('Adršpašské skály'), findsAtLeastNWidgets(1));
    expect(find.text('Další zastávka'), findsNWidgets(2));
    expect(find.text('Propast Macocha'), findsNothing);
    expect(find.text('Zámek Kroměříž'), findsNothing);
    expect(find.text('Cesta k Macoše'), findsNothing);
    expect(find.text('Závěr výzvy'), findsOneWidget);
    expect(find.text('Hotovo. Příběh končí.'), findsNothing);
    expect(find.byKey(const Key('waypoint-mystery-w1')), findsOneWidget);

    final card = tester.widget<Card>(
      find.byKey(const Key('story-chapter-s-open')),
    );
    expect(card.color, BrandColors.cream);
    expect(card.color, isNot(BrandColors.shellFill));

    expect(find.byKey(const Key('route-destination-place')), findsOneWidget);
    expect(find.text('Propast Macocha'), findsNothing);

    await tester.tap(find.byKey(const Key('story-chapter-toggle-s-b0')));
    await tester.pumpAndSettle();
    expect(find.text('Mlha se zvedá.'), findsOneWidget);
    expect(find.byKey(const Key('story-chapter-body-s-b0')), findsOneWidget);
    final bodyCard = tester.widget<Card>(
      find.byKey(const Key('story-chapter-s-b0')),
    );
    expect(bodyCard.color, isNot(BrandColors.shellFill));

    await tester.ensureVisible(find.byKey(const Key('waypoint-tile-w1')));
    await tester.tap(find.byKey(const Key('waypoint-tile-w1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-fog-locked')), findsOneWidget);
    expect(find.text('Propast Macocha'), findsNothing);
  });

  testWidgets(
    'paid unpaid story shows pay buttons and the lock opens checkout',
    (tester) async {
      debugPaymentWebViewBuilder = fakePaymentWebViewBuilder();
      addTearDown(() => debugPaymentWebViewBuilder = null);
      final strings = AppStrings('cs');
      final purchases = MemoryPurchases(completeOnRefresh: false);
      await _pumpDetail(tester, _paidStory(), purchases: purchases);

      expect(find.byKey(const Key('challenge-pay-ctas')), findsOneWidget);
      expect(
        find.text(
          strings.payCtaAmount(
            strings.payDigitalDiploma,
            formatChallengePrice(499, 'eur', 'cs')!,
          ),
        ),
        findsNWidgets(2),
      );
      expect(
        find.text(
          strings.payCtaAmount(
            strings.payMedalAndDiploma,
            formatChallengePrice(900, 'eur', 'cs')!,
          ),
        ),
        findsNWidgets(2),
      );
      expect(find.text(strings.challengeLockedPaid), findsNothing);
      expect(find.byKey(const Key('story-chapter-s-open')), findsOneWidget);
      expect(find.text('Úvod výzvy'), findsOneWidget);
      expect(find.text('Vítej v příběhové výpravě.'), findsOneWidget);
      expect(
        find.byKey(const Key('story-youtube-dQw4w9WgXcQ')),
        findsOneWidget,
      );
      expect(find.text('Před Adršpachem'), findsNothing);
      expect(find.text('Závěr výzvy'), findsOneWidget);
      expect(find.text('Další zastávka'), findsNWidgets(3));

      await tester.ensureVisible(
        find.byKey(const Key('challenge-reward-lock')),
      );
      expect(
        find.byKey(const Key('challenge-reward-lock-overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('challenge-reward-diploma-texture')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('challenge-reward-diploma')), findsOneWidget);
      expect(
        find.byKey(const Key('challenge-reward-diploma-blur')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('challenge-reward-lock')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment-checkout-dialog')), findsOneWidget);
      expect(find.byKey(const Key('payment-checkout-screen')), findsOneWidget);
      expect(
        find.text(fapiCheckoutUrlFor(RewardVariant.diploma)),
        findsOneWidget,
      );
      expect(purchases.purchases['story-mock']!.status, PurchaseStatus.pending);
      expect(
        purchases.purchases['story-mock']!.rewardVariant,
        RewardVariant.diploma,
      );
    },
  );

  testWidgets(
    'pending story shows intro then gated places then closing, and a verified stop',
    (tester) async {
      final strings = AppStrings('cs');
      final base = _paidStory();
      final detail = ChallengeDetail(
        challenge: Challenge(
          id: base.challenge.id,
          slug: base.challenge.slug,
          accessMode: AccessMode.story,
          pricingType: PricingType.paid,
          priceCents: 69700,
          diplomaPriceCents: 69700,
          currency: 'czk',
          status: base.challenge.status,
          countryCode: base.challenge.countryCode,
          translations: base.challenge.translations,
          fapiFormUrlDiploma: 'https://form.fapi.cz/diploma-test',
        ),
        waypoints: base.waypoints,
        storySteps: base.storySteps,
      );
      final progress = MemoryProgress(details: [detail]);
      progress.completed[detail.challenge.id] = {'w0'};
      final purchases =
          MemoryPurchases(
              completeOnRefresh: false,
              purchases: {
                detail.challenge.id: Purchase(
                  challengeId: detail.challenge.id,
                  status: PurchaseStatus.pending,
                  rewardVariant: RewardVariant.diploma,
                ),
              },
            )
            ..offer = const FapiOffer(
              diploma: FapiOfferVariant(
                priceCents: 19700,
                currency: 'czk',
                termsUrl: 'https://vyslapni.cz/obchodni-podminky/',
                terms: [
                  FapiOfferTerm(
                    text: 'Souhlasím se',
                    url: 'https://vyslapni.cz/obchodni-podminky/',
                  ),
                ],
              ),
              medal: FapiOfferVariant.unknown,
            );
      await _pumpDetail(
        tester,
        detail,
        progress: progress,
        purchases: purchases,
        height: 5200,
      );

      expect(
        tester.getTopLeft(find.byType(ChallengeMap)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('challenge-description'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('challenge-description'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('challenge-pay-heading'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('challenge-pay-heading'))).dy,
        lessThan(tester.getTopLeft(find.byType(RoutePlannerPanel)).dy),
      );
      expect(
        tester.getTopLeft(find.byType(RoutePlannerPanel)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('story-chapter-s-open'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('story-chapter-s-open'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('waypoint-tile-w0'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('waypoint-tile-w0'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('waypoint-tile-w1'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('waypoint-tile-w2'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('story-chapter-s-close'))).dy,
        ),
      );
      expect(find.text('Před Adršpachem'), findsNothing);
      expect(find.text('Cesta k Macoše'), findsNothing);
      expect(find.byKey(const Key('waypoint-category-w0')), findsOneWidget);
      expect(find.byKey(const Key('waypoint-mystery-w0')), findsNothing);
      expect(find.byKey(const Key('waypoint-mystery-w1')), findsOneWidget);
      expect(find.byKey(const Key('waypoint-mystery-w2')), findsOneWidget);
      expect(find.text('Propast Macocha'), findsNothing);
      expect(find.text('Zámek Kroměříž'), findsNothing);
      expect(find.text('Další zastávka'), findsNWidgets(2));
      expect(find.text(strings.verified), findsWidgets);
      expect(find.text('Souhlasím se'), findsNothing);
      expect(find.text('https://vyslapni.cz/obchodni-podminky/'), findsNothing);
      expect(find.byKey(const Key('challenge-pay-terms')), findsNothing);
      expect(find.text('197${priceThinSpace}Kč'), findsNothing);
      expect(find.text(strings.payPriceUnavailable), findsNothing);
      final medal = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('challenge-pay-medal')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(medal.onPressed, isNull);
      expect(
        medal.style?.foregroundColor?.resolve({WidgetState.disabled}),
        BrandColors.cream.withValues(alpha: 0.7),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: find.byKey(const Key('challenge-pay-diploma')),
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('paid story sequence is intro, chapter, place, then closing', (
    tester,
  ) async {
    final detail = _paidStory();
    final progress = MemoryProgress(details: [detail]);
    progress.completed[detail.challenge.id] = {'w0', 'w1', 'w2'};
    final purchases = MemoryPurchases(
      purchases: {
        detail.challenge.id: Purchase(
          challengeId: detail.challenge.id,
          status: PurchaseStatus.paid,
          paidAt: DateTime.utc(2026, 10, 1),
        ),
      },
    );
    await _pumpDetail(
      tester,
      detail,
      progress: progress,
      purchases: purchases,
      height: 5200,
    );

    final ordered = [
      const Key('story-chapter-s-open'),
      const Key('story-chapter-s-b0'),
      const Key('waypoint-tile-w0'),
      const Key('story-chapter-s-b1'),
      const Key('waypoint-tile-w1'),
      const Key('waypoint-tile-w2'),
      const Key('story-chapter-s-close'),
    ];
    for (var i = 0; i < ordered.length - 1; i++) {
      expect(
        tester.getTopLeft(find.byKey(ordered[i])).dy,
        lessThan(tester.getTopLeft(find.byKey(ordered[i + 1])).dy),
        reason: '${ordered[i]} before ${ordered[i + 1]}',
      );
    }
    expect(find.text('Bez média'), findsNothing);
    expect(find.byKey(const Key('waypoint-mystery-w0')), findsNothing);
    expect(find.byKey(const Key('waypoint-mystery-w1')), findsNothing);
    expect(find.byKey(const Key('waypoint-mystery-w2')), findsNothing);
    expect(find.byKey(const Key('story-youtube-dQw4w9WgXcQ')), findsOneWidget);
    expect(find.text('Vítej v příběhové výpravě.'), findsOneWidget);
  });

  testWidgets('before and closing chapters embed YouTube with their text', (
    tester,
  ) async {
    const before = StoryStep(
      id: 'yt-before',
      challengeId: 'story-mock',
      sortOrder: 1,
      kind: StoryStepKind.beforeWaypoint,
      waypointId: 'w1',
      youtubeUrl: 'https://youtu.be/abcdefghijk',
      translations: [
        LocalizedText(
          locale: 'cs',
          title: 'Mezi zastávkami',
          description: 'Text před dalším místem.',
        ),
      ],
    );
    const closing = StoryStep(
      id: 'yt-close',
      challengeId: 'story-mock',
      sortOrder: 2,
      kind: StoryStepKind.closing,
      youtubeUrl: 'https://www.youtube.com/watch?v=zzzzzzzzzzz',
      translations: [
        LocalizedText(
          locale: 'cs',
          title: 'Závěr s videem',
          description: 'Text závěru.',
        ),
      ],
    );
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                StoryChapterCard(step: before, locale: 'cs', expandOnce: true),
                StoryChapterCard(step: closing, locale: 'cs', expandOnce: true),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('story-youtube-abcdefghijk')), findsOneWidget);
    expect(find.text('Text před dalším místem.'), findsOneWidget);
    expect(find.byKey(const Key('story-youtube-zzzzzzzzzzz')), findsOneWidget);
    expect(find.text('Text závěru.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Mezi zastávkami')).dy,
      lessThan(tester.getTopLeft(find.text('Závěr s videem')).dy),
    );
  });

  testWidgets('free story shows the pay buttons and stays locked until paid', (
    tester,
  ) async {
    debugPaymentWebViewBuilder = fakePaymentWebViewBuilder();
    addTearDown(() => debugPaymentWebViewBuilder = null);
    final strings = AppStrings('cs');
    final base = _story();
    final detail = ChallengeDetail(
      challenge: Challenge(
        id: base.challenge.id,
        slug: base.challenge.slug,
        accessMode: base.challenge.accessMode,
        pricingType: PricingType.free,
        priceCents: 99900,
        diplomaPriceCents: 99900,
        medalPriceCents: 99900,
        currency: 'czk',
        status: base.challenge.status,
        countryCode: base.challenge.countryCode,
        translations: base.challenge.translations,
        fapiFormUrlDiploma: 'https://form.fapi.cz/diploma-test',
        fapiFormUrlMedal: 'https://form.fapi.cz/medal-test',
      ),
      waypoints: base.waypoints,
      storySteps: base.storySteps,
    );
    final purchases = MemoryPurchases(completeOnRefresh: false)
      ..offer = const FapiOffer(
        diploma: FapiOfferVariant(
          priceCents: 0,
          currency: 'czk',
          termsUrl: 'https://form.fapi.cz/terms',
        ),
        medal: FapiOfferVariant(priceCents: 0, currency: 'czk'),
      );
    await _pumpDetail(tester, detail, purchases: purchases);

    expect(find.byKey(const Key('story-chapter-s-open')), findsOneWidget);
    expect(find.byKey(const Key('challenge-pay-ctas')), findsOneWidget);
    expect(find.text(strings.payCtaFree), findsNWidgets(4));
    expect(find.text(strings.payDigitalDiploma), findsNothing);
    expect(find.text(strings.payMedalAndDiploma), findsNothing);
    expect(find.text(strings.payPriceFree), findsNothing);
    expect(find.text('999${priceThinSpace}Kč'), findsNothing);
    expect(find.text(strings.challengeLockedPaid), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('challenge-reward-lock')));
    expect(
      find.byKey(const Key('challenge-reward-lock-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('challenge-reward-diploma-texture')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('challenge-reward-diploma-blur')),
      findsNothing,
    );
    expect(find.byKey(const Key('challenge-save-diploma')), findsNothing);

    await tester.tap(find.byKey(const Key('challenge-reward-lock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payment-checkout-dialog')), findsOneWidget);
    expect(
      purchases.purchases['story-mock']!.rewardVariant,
      RewardVariant.diploma,
    );
  });

  testWidgets('chapter auto-expands once, and reduce-motion stays closed', (
    tester,
  ) async {
    final step = _story().orderedStorySteps[1];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryChapterCard(step: step, locale: 'cs', expandOnce: true),
        ),
      ),
    );
    expect(find.byKey(const Key('story-chapter-body-s-b0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('story-chapter-toggle-s-b0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-chapter-body-s-b0')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: Scaffold(
          body: StoryChapterCard(step: step, locale: 'cs', expandOnce: true),
        ),
      ),
    );
    expect(find.byKey(const Key('story-chapter-body-s-b0')), findsNothing);
    expect(find.text('Před Adršpachem'), findsOneWidget);
  });

  testWidgets('youtube chapter embeds in-app and does not use shellFill', (
    tester,
  ) async {
    final step = _story().orderedStorySteps.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryChapterCard(step: step, locale: 'cs', expandOnce: true),
        ),
      ),
    );
    expect(find.byKey(const Key('story-youtube-dQw4w9WgXcQ')), findsOneWidget);
    expect(find.text('Vítej v příběhové výpravě.'), findsOneWidget);
    expect(
      tester.widget<Card>(find.byKey(const Key('story-chapter-s-open'))).color,
      BrandColors.cream,
    );
  });

  testWidgets('verify stop 1 reveals the next chapter and the next stop', (
    tester,
  ) async {
    final detail = _story();
    final progress = MemoryProgress(details: [detail]);
    final services = _services(
      detail,
      progress: progress,
      deviceLocation: MemoryDeviceLocation(
        point: const RouteEndpoint(lat: 50.611389, lng: 16.115, label: 'GPS'),
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/challenge/${detail.challenge.id}',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'challenge/:id',
              builder: (_, state) =>
                  ChallengeScreen(challengeId: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(
          path: '/verify/:challengeId/:waypointId',
          builder: (_, state) => VerifyWaypointScreen(
            challengeId: state.pathParameters['challengeId'],
            waypointId: state.pathParameters['waypointId'],
            place: state.extra is Place ? state.extra as Place : null,
            places: MemoryPlaceCatalog(const []),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'cs'),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                LastOpenedChallengeStore(initialId: detail.challenge.id),
          ),
          Provider.value(value: services),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final verify = find.descendant(
      of: find.byKey(const Key('waypoint-tile-w0')),
      matching: find.byType(FilledButton),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('waypoint-tile-w0')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('challenge-feed-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('story-chapter-s-b1')), findsNothing);
    expect(find.byKey(const Key('waypoint-mystery-w1')), findsOneWidget);
    await tester.tap(verify);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-chapter-s-b1')), findsOneWidget);
    expect(find.byKey(const Key('story-chapter-text-s-b1')), findsOneWidget);
    expect(find.text('Po skále přichází propast.'), findsOneWidget);
    expect(find.byKey(const Key('waypoint-tile-w1')), findsOneWidget);
    expect(find.text('Propast Macocha'), findsWidgets);
    expect(find.byKey(const Key('waypoint-mystery-w1')), findsNothing);
    expect(find.byKey(const Key('waypoint-category-w1')), findsOneWidget);
    final stored = await services.progress.fetchProgress(detail.challenge.id);
    expect(stored?.completedWaypointIds, contains('w0'));
    if (Platform.environment['CAPTURE_UX'] == '1') {
      await tester.runAsync(_loadShotFonts);
      await tester.ensureVisible(find.byKey(const Key('story-chapter-s-b1')));
      await tester.pumpAndSettle();
      goldenFileComparator = _StoryShot();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('story-after-verify.png'),
      );
    }
  });

  testWidgets('after verify the next place uses its real name', (tester) async {
    await _pumpStory(tester, progressIds: const {'w0'});
    expect(find.text('Cesta k Macoše'), findsOneWidget);
    expect(find.text('Propast Macocha'), findsAtLeastNWidgets(1));
    expect(find.text('Zámek Kroměříž'), findsNothing);
    expect(find.text('Další zastávka'), findsOneWidget);
    expect(find.byKey(const Key('waypoint-category-w1')), findsOneWidget);
    expect(find.byKey(const Key('waypoint-mystery-w2')), findsOneWidget);
  });

  testWidgets('open challenge keeps both names and skips chapters', (
    tester,
  ) async {
    final story = _story();
    final openChallenge = Challenge(
      id: 'open-1',
      slug: 'open-trail',
      accessMode: AccessMode.open,
      pricingType: PricingType.free,
      priceCents: 0,
      currency: 'eur',
      status: PublishStatus.published,
      translations: const [
        LocalizedText(locale: 'cs', title: 'Otevřená stezka', description: ''),
      ],
    );
    final open = ChallengeDetail(
      challenge: openChallenge,
      waypoints: [
        for (final waypoint in story.waypoints)
          Waypoint(
            id: waypoint.id,
            challengeId: 'open-1',
            sortOrder: waypoint.sortOrder,
            lat: waypoint.lat,
            lng: waypoint.lng,
            elevationM: waypoint.elevationM,
            placeId: waypoint.placeId,
            category: waypoint.category,
            translations: waypoint.translations,
          ),
      ],
      storySteps: story.storySteps,
    );
    await _pumpDetail(tester, open);
    expect(find.byKey(const Key('story-chapter-s-open')), findsNothing);
    expect(find.text('Adršpašské skály'), findsAtLeastNWidgets(1));
    expect(find.text('Propast Macocha'), findsAtLeastNWidgets(1));
    expect(find.text('Zámek Kroměříž'), findsAtLeastNWidgets(1));
    expect(find.text('Další zastávka'), findsNothing);
  });

  testWidgets('finishing a story returns to the list route', (tester) async {
    final detail = _story();
    final progress = MemoryProgress(details: [detail]);
    progress.completed[detail.challenge.id] = {'w0', 'w1'};
    final services = _services(detail, progress: progress);
    final router = GoRouter(
      initialLocation: '/verify/${detail.challenge.id}/w2',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('home', key: Key('home')),
          routes: [
            GoRoute(
              path: 'verify/:challengeId/:waypointId',
              builder: (context, state) => VerifyWaypointScreen(
                challengeId: state.pathParameters['challengeId'],
                waypointId: state.pathParameters['waypointId'],
                places: MemoryPlaceCatalog(samplePlaces()),
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'cs'),
          ),
          Provider.value(value: services),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home')), findsOneWidget);
    final done = await services.progress.fetchProgress(detail.challenge.id);
    expect(done?.isCompleted, isTrue);
    expect(done?.completedWaypointIds, contains('w2'));
  });
}

AppServices _services(
  ChallengeDetail detail, {
  MemoryProgress? progress,
  MemoryPurchases? purchases,
  MemoryDeviceLocation? deviceLocation,
}) {
  return AppServices(
    config: const AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon',
      stripePublishableKey: 'pk_test',
    ),
    auth: MemoryAuth(
      user: const Profile(id: 'user-1', locale: 'cs', displayName: 'Ada'),
    ),
    catalog: MemoryCatalog(challenges: [detail.challenge], details: [detail]),
    progress: progress ?? MemoryProgress(details: [detail]),
    purchases: purchases ?? MemoryPurchases(),
    photos: MemoryPhotos(),
    photoCapture: MemoryCapture(),
    routing: MemoryRoutingClient(),
    geocoder: MemoryGeocoder(places: const {}),
    deviceLocation:
        deviceLocation ??
        MemoryDeviceLocation(
          point: const RouteEndpoint(
            lat: 49.300278,
            lng: 17.393056,
            label: 'GPS',
          ),
        ),
    elevation: MemoryElevationLookup(),
    places: MemoryPlaceCatalog(const []),
  );
}

Future<void> _pumpStory(
  WidgetTester tester, {
  required Set<String> progressIds,
}) async {
  final detail = _story();
  final progress = MemoryProgress(details: [detail]);
  if (progressIds.isNotEmpty) {
    progress.completed[detail.challenge.id] = {...progressIds};
  }
  await _pumpDetail(tester, detail, progress: progress);
}

Future<void> _loadShotFonts() async {
  Future<void> family(
    String name,
    List<String> paths, {
    bool fromBundle = false,
  }) async {
    final loader = FontLoader(name);
    for (final path in paths) {
      final Future<ByteData> data = fromBundle
          ? rootBundle.load(path)
          : File(path).readAsBytes().then(
              (bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
            );
      loader.addFont(data);
    }
    await loader.load();
  }

  await family('Roboto', const [
    '/usr/share/fonts/truetype/macos/Inter-Regular.ttf',
    '/usr/share/fonts/truetype/macos/Inter-Medium.ttf',
    '/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf',
    '/usr/share/fonts/truetype/macos/Inter-Bold.ttf',
  ]);
  await family('Onest', const [
    'assets/fonts/Onest[wght].ttf',
  ], fromBundle: true);
  await family('MaterialIcons', const [
    '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

class _StoryShot extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final file = File('/opt/cursor/artifacts/${golden.pathSegments.last}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes, flush: true);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    return compare(imageBytes, golden);
  }
}

Future<void> _pumpDetail(
  WidgetTester tester,
  ChallengeDetail detail, {
  MemoryProgress? progress,
  MemoryPurchases? purchases,
  double height = 3200,
}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TickerMode(
      enabled: false,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LocaleController(initial: 'cs'),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                LastOpenedChallengeStore(initialId: detail.challenge.id),
          ),
          Provider.value(
            value: _services(detail, progress: progress, purchases: purchases),
          ),
        ],
        child: MaterialApp(
          home: ChallengeScreen(challengeId: detail.challenge.id),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
