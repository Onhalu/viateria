import 'dart:typed_data';

import '../models/models.dart';

abstract class AuthRepository {
  Stream<Profile?> authState();
  Profile? get currentUser;
  Future<Profile> signIn({required String email, required String password});
  Future<Profile> signUp({
    required String email,
    required String password,
    String? displayName,
  });
  Future<void> signOut();
  Future<void> updateLocale(String locale);
}

abstract class CatalogRepository {
  Future<List<Challenge>> fetchPublishedChallenges();
  Future<ChallengeDetail> fetchChallenge(String id);
  Future<List<PromoStripe>> fetchPublishedPromos({DateTime? now});
}

abstract class ProgressRepository {
  Future<ChallengeProgress?> fetchProgress(String challengeId);
  Future<ChallengeProgress> verifyWaypoint({
    required String challengeId,
    required String waypointId,
    required String photoPath,
  });
}

abstract class PurchaseRepository {
  Future<Purchase?> fetchPurchase(String challengeId);
  Future<CheckoutSession> startCheckout(String challengeId);
  Future<Purchase?> refreshPurchase(String challengeId);
}

abstract class PhotoStorage {
  Future<String> uploadWaypointPhoto({
    required String userId,
    required String challengeId,
    required String waypointId,
    required Uint8List bytes,
    required String mimeType,
  });
}
