import 'dart:typed_data';

import '../domain/leaderboard_score.dart';
import '../models/models.dart';

/// Auth API failure with a message safe to show in the UI.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Google or Apple, both via `signInWithOAuth` on the same Supabase client.
enum AuthProvider {
  google,
  apple;

  String get label => switch (this) {
    AuthProvider.google => 'Google',
    AuthProvider.apple => 'Apple',
  };
}

/// The provider is switched off in the Supabase dashboard.
///
/// [provider] is null when the failure comes back on the redirect URL and
/// the app no longer knows which button was pressed.
class AuthProviderUnavailable implements Exception {
  const AuthProviderUnavailable([this.provider]);

  final AuthProvider? provider;
}

/// The system browser did not open, so the OAuth page never started.
class AuthBrowserLaunchFailed implements Exception {
  const AuthBrowserLaunchFailed();
}

/// Outcome of [AuthRepository.signUp].
///
/// When email confirmation is on, Supabase returns a user but no session.
/// That is success, not an error — the UI must show a confirmation step.
class SignUpResult {
  const SignUpResult({required this.sessionEstablished, this.profile});

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

  /// Confirm signup, email OTP, or a magic-link code.
  /// Creates a session so the existing auth redirect can enter the app.
  Future<Profile> verifyEmailOtp({
    required String email,
    required String token,
  });

  /// Email magic link. The session arrives later, from the link or from
  /// [verifyEmailOtp], on the same `auth.uid()` as password sign-in.
  Future<void> sendMagicLink({required String email});

  /// Opens Google or Apple. The session arrives on [authState] after the
  /// redirect; this method only starts the browser flow.
  Future<void> signInWithProvider(AuthProvider provider);

  /// Deep-link or provider failures that are not thrown to the button.
  /// [authState] itself does not emit errors.
  Stream<Object> authFailures();

  /// True from a password-recovery session until [updatePassword] succeeds.
  ///
  /// A recovery link creates a real session, so the router must read this
  /// and keep `/auth` open for the new-password step.
  bool get pendingPasswordRecovery;

  /// Emits `true` when a recovery session starts and `false` when it ends.
  Stream<bool> passwordRecovery();

  /// Emails a reset link. [redirectTo] matches OAuth and magic link
  /// (`AuthRedirect.forCurrentPlatform`).
  Future<void> sendPasswordReset({required String email});

  /// Sets a new password on the current recovery session.
  Future<void> updatePassword(String password);

  Future<void> signOut();
  Future<void> updateLocale(String locale);
}

/// Challenge id is unknown or no longer published.
class ChallengeMissing implements Exception {
  const ChallengeMissing(this.id);

  final String id;

  @override
  String toString() => 'Challenge $id is not available';
}

abstract class CatalogRepository {
  Future<List<Challenge>> fetchPublishedChallenges();

  /// Published challenges with waypoints, for catalog route stats.
  Future<List<ChallengeDetail>> fetchPublishedDetails();

  Future<ChallengeDetail> fetchChallenge(String id);
  Future<List<PromoStripe>> fetchPublishedPromos({DateTime? now});
}

abstract class ProgressRepository {
  Future<ChallengeProgress?> fetchProgress(String challengeId);

  /// Completed runs for the signed-in user. Empty when signed out.
  ///
  /// Prefers `challenge_participations` (own-row RLS). Falls back to
  /// `challenge_progress` when that table is absent or still empty.
  Future<List<ChallengeProgress>> fetchCompleted();

  /// Issued diploma for the signed-in user, or null when the table or row
  /// is absent. Templates (`user_id` null) are not returned.
  Future<IssuedDiploma?> fetchIssuedDiploma(String challengeId);

  Future<ChallengeProgress> verifyWaypoint({
    required String challengeId,
    required String waypointId,
    required String photoPath,
  });

  /// Verification photos for every user on [challengeId].
  ///
  /// Does not filter by the signed-in user. Blank paths and GPS sentinel
  /// paths are omitted. Empty when signed out.
  Future<List<ChallengeWaypointPhoto>> fetchChallengePhotos(String challengeId);
}

abstract class PurchaseRepository {
  Future<Purchase?> fetchPurchase(String challengeId);
  Future<CheckoutSession> startCheckout(
    String challengeId, {
    RewardVariant? rewardVariant,
  });
  Future<Purchase?> refreshPurchase(String challengeId);
}

/// Live leaderboard. Scores are not cached on device.
abstract class LeaderboardRepository {
  /// Inserts one place visit. Duplicate `(user, place)` is a no-op.
  ///
  /// Non-uuid ids (bundled map fixtures) are ignored.
  Future<void> recordPlaceVisit(
    String placeId, {
    required PlaceVisitSource source,
  });

  /// One-shot upload of ids already stored on the device.
  Future<void> recordPlaceVisitsBatch(
    List<String> placeIds, {
    PlaceVisitSource source = PlaceVisitSource.prefsSync,
  });

  /// Top [limit] rows. The server clamps [limit] to at most 50.
  Future<List<LeaderboardEntry>> fetchLeaderboard({int limit = 50});

  /// Caller row, including rank when they sit outside the top N.
  Future<LeaderboardEntry> fetchMyScore();

  /// `place_id` values from the caller's `place_visits` rows.
  ///
  /// Empty when signed out. The authenticated client selects its own rows
  /// (RLS). This does not use the service role.
  Future<List<String>> fetchMyVisitedPlaceIds();
}

abstract class PhotoStorage {
  Future<String> uploadWaypointPhoto({
    required String userId,
    required String challengeId,
    required String waypointId,
    required Uint8List bytes,
    required String mimeType,
  });

  /// Signed HTTPS URLs for private `waypoint-photos` objects.
  ///
  /// Same bucket and auth client as [uploadWaypointPhoto]. Blank paths and
  /// GPS sentinels are ignored. Missing objects are omitted.
  Future<Map<String, String>> signedUrlsForPhotos(List<String> photoPaths);
}
