import 'dart:async';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:viateria/data/repositories.dart';
import 'package:viateria/data/route_services.dart';
import 'package:viateria/domain/photo_verify.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/domain/unlock_rules.dart';
import 'package:viateria/models/models.dart';

class MemoryAuth implements AuthRepository {
  MemoryAuth({this._user, this.sessionOnSignUp = true});

  Profile? _user;
  final bool sessionOnSignUp;
  final _controller = StreamController<Profile?>.broadcast();

  @override
  Stream<Profile?> authState() => _controller.stream;

  @override
  Profile? get currentUser => _user;

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    _user = Profile(
      id: 'user-1',
      email: email,
      locale: 'cs',
      displayName: 'Ada',
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!sessionOnSignUp) {
      return SignUpResult(
        sessionEstablished: false,
        profile: Profile(
          id: 'pending',
          email: email,
          locale: 'cs',
          displayName: displayName,
        ),
      );
    }
    final profile = await signIn(email: email, password: password);
    return SignUpResult(sessionEstablished: true, profile: profile);
  }

  @override
  Future<Profile> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final code = token.trim();
    if (code.length != 6) {
      throw const AuthFailure('Token has expired or is invalid');
    }
    return signIn(email: email, password: 'verified');
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> updateLocale(String locale) async {
    if (_user != null) {
      _user = Profile(
        id: _user!.id,
        email: _user!.email,
        displayName: _user!.displayName,
        locale: locale,
      );
      _controller.add(_user);
    }
  }
}

class MemoryCatalog implements CatalogRepository {
  MemoryCatalog({
    List<Challenge>? challenges,
    List<ChallengeDetail>? details,
    List<PromoStripe>? promos,
  }) : challenges = challenges ?? const [],
       details = details ?? const [],
       promos = promos ?? const [];

  final List<Challenge> challenges;
  final List<ChallengeDetail> details;
  final List<PromoStripe> promos;

  @override
  Future<List<Challenge>> fetchPublishedChallenges() async =>
      challenges.where((c) => isPubliclyVisible(c.status)).toList();

  Object? fetchChallengeError;

  @override
  Future<ChallengeDetail> fetchChallenge(String id) async {
    final forced = fetchChallengeError;
    if (forced != null) throw forced;
    for (final detail in details) {
      if (detail.challenge.id == id) return detail;
    }
    throw ChallengeMissing(id);
  }

  @override
  Future<List<PromoStripe>> fetchPublishedPromos({DateTime? now}) async {
    final moment = now ?? DateTime.now().toUtc();
    return promos.where((p) => p.isActiveAt(moment)).toList();
  }
}

class MemoryProgress implements ProgressRepository {
  MemoryProgress({this.details = const []});

  final List<ChallengeDetail> details;
  final Map<String, Set<String>> completed = {};
  final Map<String, ChallengeRunStatus> statuses = {};
  Object? fetchProgressError;
  static const _rules = UnlockRules();

  @override
  Future<ChallengeProgress?> fetchProgress(String challengeId) async {
    final forced = fetchProgressError;
    if (forced != null) throw forced;
    final ids = completed[challengeId];
    if (ids == null) return null;
    return ChallengeProgress(
      challengeId: challengeId,
      status: statuses[challengeId] ?? ChallengeRunStatus.inProgress,
      completedWaypointIds: {...ids},
      completedAt: statuses[challengeId] == ChallengeRunStatus.completed
          ? DateTime.utc(2026, 9, 7)
          : null,
    );
  }

  @override
  Future<ChallengeProgress> verifyWaypoint({
    required String challengeId,
    required String waypointId,
    required String photoPath,
  }) async {
    if (photoPath.isEmpty) {
      throw StateError('photo required');
    }
    final detail = details.firstWhere((d) => d.challenge.id == challengeId);
    final done = completed.putIfAbsent(challengeId, () => <String>{});
    final allowed = _rules.canVerifyPhoto(
      mode: detail.challenge.accessMode,
      hasAccess: true,
      orderedWaypoints: detail.orderedWaypoints,
      waypointId: waypointId,
      completedWaypointIds: done,
    );
    if (!allowed) {
      throw StateError('waypoint locked');
    }
    done.add(waypointId);
    if (_rules.isChallengeComplete(
      waypoints: detail.waypoints,
      completedWaypointIds: done,
    )) {
      statuses[challengeId] = ChallengeRunStatus.completed;
    } else {
      statuses[challengeId] = ChallengeRunStatus.inProgress;
    }
    return (await fetchProgress(challengeId))!;
  }
}

class MemoryPurchases implements PurchaseRepository {
  MemoryPurchases({Map<String, Purchase>? purchases})
    : purchases = purchases ?? {};

  final Map<String, Purchase> purchases;

  @override
  Future<Purchase?> fetchPurchase(String challengeId) async =>
      purchases[challengeId];

  @override
  Future<Purchase?> refreshPurchase(String challengeId) async {
    final current = purchases[challengeId];
    if (current != null && current.status == PurchaseStatus.pending) {
      return pay(
        challengeId,
        rewardVariant: current.rewardVariant ?? RewardVariant.diploma,
      );
    }
    return current;
  }

  /// Marks the purchase paid and stamps [Purchase.paidAt].
  Purchase pay(
    String challengeId, {
    DateTime? paidAt,
    RewardVariant? rewardVariant = RewardVariant.diploma,
  }) {
    final current = purchases[challengeId];
    final purchase = Purchase(
      challengeId: challengeId,
      status: PurchaseStatus.paid,
      checkoutUrl: current?.checkoutUrl,
      paidAt: paidAt ?? DateTime.now(),
      rewardVariant: rewardVariant ?? current?.rewardVariant,
    );
    purchases[challengeId] = purchase;
    return purchase;
  }

  @override
  Future<CheckoutSession> startCheckout(String challengeId) async {
    purchases[challengeId] = Purchase(
      challengeId: challengeId,
      status: PurchaseStatus.pending,
      rewardVariant: purchases[challengeId]?.rewardVariant,
    );
    return const CheckoutSession(url: 'https://checkout.stripe.com/test');
  }
}

class MemoryPhotos implements PhotoStorage {
  final List<String> uploaded = [];

  @override
  Future<String> uploadWaypointPhoto({
    required String userId,
    required String challengeId,
    required String waypointId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) throw StateError('empty photo');
    final path = '$userId/$challengeId/$waypointId/photo.jpg';
    uploaded.add(path);
    return path;
  }
}

class MemoryCapture implements PhotoCapture {
  MemoryCapture({this.photo});

  LivePhoto? photo;

  @override
  Future<LivePhoto?> captureLivePhoto() async => photo;
}

ChallengeDetail sampleOpenChallenge() {
  const challenge = Challenge(
    id: 'open-1',
    slug: 'open-trail',
    accessMode: AccessMode.open,
    pricingType: PricingType.free,
    priceCents: 0,
    currency: 'eur',
    status: PublishStatus.published,
    translations: [
      LocalizedText(
        locale: 'en',
        title: 'Open trail',
        description: 'Visit any stop',
      ),
      LocalizedText(locale: 'cs', title: 'Otevřená stezka', description: ''),
      LocalizedText(locale: 'de', title: 'Offener Pfad', description: ''),
    ],
  );
  final waypoints = [
    const Waypoint(
      id: 'ow-1',
      challengeId: 'open-1',
      sortOrder: 0,
      lat: 50.08,
      lng: 14.42,
      elevationM: 200,
      translations: [LocalizedText(locale: 'en', title: 'Start')],
    ),
    const Waypoint(
      id: 'ow-2',
      challengeId: 'open-1',
      sortOrder: 1,
      lat: 50.09,
      lng: 14.43,
      elevationM: 280,
      translations: [LocalizedText(locale: 'en', title: 'Ridge')],
    ),
  ];
  return ChallengeDetail(challenge: challenge, waypoints: waypoints);
}

ChallengeDetail sampleStoryChallenge() {
  const challenge = Challenge(
    id: 'story-1',
    slug: 'story-trail',
    accessMode: AccessMode.story,
    pricingType: PricingType.paid,
    priceCents: 900,
    currency: 'eur',
    status: PublishStatus.published,
    translations: [
      LocalizedText(
        locale: 'en',
        title: 'Story trail',
        description: 'Unlock in order',
        diplomaHeadline: 'Story master',
      ),
    ],
  );
  final waypoints = [
    const Waypoint(
      id: 'sw-1',
      challengeId: 'story-1',
      sortOrder: 0,
      lat: 48.97,
      lng: 14.47,
      elevationM: 400,
      translations: [LocalizedText(locale: 'en', title: 'Gate')],
    ),
    const Waypoint(
      id: 'sw-2',
      challengeId: 'story-1',
      sortOrder: 1,
      lat: 48.98,
      lng: 14.48,
      elevationM: 520,
      translations: [LocalizedText(locale: 'en', title: 'Tower')],
    ),
  ];
  return ChallengeDetail(challenge: challenge, waypoints: waypoints);
}

PromoStripe samplePromo() {
  return PromoStripe(
    id: 'promo-1',
    status: PublishStatus.published,
    sortOrder: 0,
    challengeId: 'open-1',
    translations: const [
      LocalizedText(
        locale: 'en',
        title: 'Weekend hike',
        subtitle: 'Start this week',
        ctaLabel: 'Go',
      ),
    ],
  );
}

class MemoryRoutingClient implements RoutingClient {
  MemoryRoutingClient({this.fail = false});

  var fail = false;

  @override
  Future<RoutedPath> route({
    required TravelMode mode,
    required LatLng start,
    required LatLng end,
  }) async {
    if (fail) throw const RoutingFailure('memory fail');
    return RoutedPath(
      points: [start, LatLng(start.latitude + 0.001, start.longitude), end],
      distanceMeters: mode == TravelMode.bike ? 1200 : 1600,
      duration: Duration(minutes: mode == TravelMode.bike ? 4 : 18),
    );
  }
}

class MemoryGeocoder implements PlaceGeocoder {
  MemoryGeocoder({this.places = const {}});

  final Map<String, RouteEndpoint> places;

  @override
  Future<RouteEndpoint?> findPlace(String query, {LatLng? near}) async {
    final parsed = parseCoordinateQuery(query);
    if (parsed != null) return parsed;
    final key = query.trim().toLowerCase();
    return places[key];
  }
}

class MemoryDeviceLocation implements DeviceLocation {
  MemoryDeviceLocation({this.point, this.error});

  RouteEndpoint? point;
  Object? error;

  @override
  Future<RouteEndpoint> current() async {
    final thrown = error;
    if (thrown != null) throw thrown;
    return point ?? const RouteEndpoint(lat: 50.07, lng: 14.41, label: 'GPS');
  }
}

class MemoryElevationLookup implements ElevationLookup {
  MemoryElevationLookup({this.fail = false, this.gainStep = 15});

  var fail = false;
  double gainStep;

  @override
  Future<List<double?>> lookup(List<LatLng> points) async {
    if (fail) throw const RoutingFailure('elevation fail');
    return [for (var i = 0; i < points.length; i++) 200 + i * gainStep];
  }
}
