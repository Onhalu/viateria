import 'dart:typed_data';

import '../models/models.dart';

/// Auth API failure with a message safe to show in the UI.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Outcome of [AuthRepository.signUp].
///
/// When email confirmation is on, Supabase returns a user but no session.
/// That is success, not an error — the UI must show a confirmation step.
class SignUpResult {
  const SignUpResult({
    required this.sessionEstablished,
    this.profile,
  });

  /// True when a session exists and the existing router redirect can send
  /// the user into the app.
  final bool sessionEstablished;
  final Profile? profile;
}

abstract class AuthRepository {
  Stream<Profile?> authState();
  Profile? get currentUser;
  Future<Profile> signIn({required String email, required String password});
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Confirm signup (or email OTP) with the 6-digit code from the mail.
  /// Creates a session so the existing auth redirect can enter the app.
  Future<Profile> verifyEmailOtp({
    required String email,
    required String token,
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
