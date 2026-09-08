import 'dart:typed_data';

import '../domain/photo_verify.dart';
import '../models/models.dart';
import 'repositories.dart';

/// Used only when env is missing. Catalog/auth are not reached because
/// [MissingConfigScreen] is shown first.
class UnconfiguredAuth implements AuthRepository {
  @override
  Stream<Profile?> authState() => Stream<Profile?>.value(null);

  @override
  Profile? get currentUser => null;

  @override
  Future<Profile> signIn({required String email, required String password}) {
    throw StateError('Supabase is not configured');
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<Profile> signUp({
    required String email,
    required String password,
    String? displayName,
  }) {
    throw StateError('Supabase is not configured');
  }

  @override
  Future<void> updateLocale(String locale) async {}
}

class UnconfiguredCatalog implements CatalogRepository {
  @override
  Future<ChallengeDetail> fetchChallenge(String id) async {
    throw StateError('Supabase is not configured');
  }

  @override
  Future<List<Challenge>> fetchPublishedChallenges() async => const [];

  @override
  Future<List<PromoStripe>> fetchPublishedPromos({DateTime? now}) async =>
      const [];
}

class UnconfiguredProgress implements ProgressRepository {
  @override
  Future<ChallengeProgress?> fetchProgress(String challengeId) async => null;

  @override
  Future<ChallengeProgress> verifyWaypoint({
    required String challengeId,
    required String waypointId,
    required String photoPath,
  }) {
    throw StateError('Supabase is not configured');
  }
}

class UnconfiguredPurchases implements PurchaseRepository {
  @override
  Future<Purchase?> fetchPurchase(String challengeId) async => null;

  @override
  Future<Purchase?> refreshPurchase(String challengeId) async => null;

  @override
  Future<CheckoutSession> startCheckout(String challengeId) {
    throw StateError('Stripe is not configured');
  }
}

class UnconfiguredPhotos implements PhotoStorage {
  @override
  Future<String> uploadWaypointPhoto({
    required String userId,
    required String challengeId,
    required String waypointId,
    required Uint8List bytes,
    required String mimeType,
  }) {
    throw StateError('Supabase is not configured');
  }
}

class UnconfiguredCapture implements PhotoCapture {
  @override
  Future<LivePhoto?> captureLivePhoto() async => null;
}
