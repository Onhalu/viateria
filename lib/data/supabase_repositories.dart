import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/auth_redirect.dart';
import '../domain/challenge_photos.dart';
import '../models/models.dart';
import 'auth_identity.dart';
import 'challenge_mapping.dart';
import 'repositories.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client) {
    _authSubscription = _client.auth.onAuthStateChange.listen(
      (event) {
        // Set the flag before the profile emit so a router refresh in the
        // same turn still sees the recovery session.
        if (event.event == AuthChangeEvent.passwordRecovery) {
          _setPasswordRecovery(true);
        } else if (event.event == AuthChangeEvent.signedOut) {
          _setPasswordRecovery(false);
        }
        if (_profiles.isClosed) return;
        _profiles.add(_mapUser(event.session?.user));
      },
      onError: (Object error, StackTrace stack) {
        final failure = _failureFrom(error);
        if (failure != null && !_failures.isClosed) {
          _failures.add(failure);
        }
      },
    );
  }

  final SupabaseClient _client;
  final _profiles = StreamController<Profile?>.broadcast();
  final _failures = StreamController<Object>.broadcast();
  final _recovery = StreamController<bool>.broadcast();
  late final StreamSubscription<AuthState> _authSubscription;
  bool _pendingPasswordRecovery = false;

  void _setPasswordRecovery(bool pending) {
    if (_pendingPasswordRecovery == pending) return;
    _pendingPasswordRecovery = pending;
    if (!_recovery.isClosed) _recovery.add(pending);
  }

  Profile? _mapUser(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata;
    return Profile(
      id: user.id,
      email: user.email,
      displayName: displayNameFromMetadata(meta),
      locale: localeFromMetadata(meta),
    );
  }

  Object? _failureFrom(Object error) {
    if (error is AuthProviderUnavailable || error is AuthBrowserLaunchFailed) {
      return error;
    }
    if (error is AuthException) {
      if (authProviderDisabled(code: error.code, message: error.message)) {
        return const AuthProviderUnavailable();
      }
      if (error.message.isNotEmpty) return AuthFailure(error.message);
    }
    if (error is AuthFailure) return error;
    return null;
  }

  @override
  Profile? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<Profile?> authState() => _profiles.stream;

  @override
  Stream<Object> authFailures() => _failures.stream;

  @override
  bool get pendingPasswordRecovery => _pendingPasswordRecovery;

  @override
  Stream<bool> passwordRecovery() => _recovery.stream;

  Never _rethrowAuth(Object error, StackTrace stack) {
    if (error is AuthException && error.message.isNotEmpty) {
      Error.throwWithStackTrace(AuthFailure(error.message), stack);
    }
    Error.throwWithStackTrace(error, stack);
  }

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final profile = _mapUser(result.user);
      if (profile == null) {
        throw const AuthFailure('Sign-in succeeded without a session');
      }
      return profile;
    } catch (error, stack) {
      _rethrowAuth(error, stack);
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final result = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (displayName != null && displayName.isNotEmpty)
            'display_name': displayName,
          'locale': 'cs',
        },
      );
      if (result.session != null) {
        final profile = _mapUser(result.user ?? result.session?.user);
        if (profile == null) {
          throw const AuthFailure('Sign-up succeeded without a user');
        }
        return SignUpResult(sessionEstablished: true, profile: profile);
      }
      // Email confirmation required: user may exist without a session.
      return SignUpResult(
        sessionEstablished: false,
        profile: _mapUser(result.user),
      );
    } catch (error, stack) {
      _rethrowAuth(error, stack);
    }
  }

  @override
  Future<Profile> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    AuthException? lastAuth;
    for (final type in [OtpType.magiclink, OtpType.signup, OtpType.email]) {
      try {
        final result = await _client.auth.verifyOTP(
          email: email,
          token: token,
          type: type,
        );
        final profile = _mapUser(result.user ?? result.session?.user);
        if (profile == null) {
          throw const AuthFailure('Code verified without a session');
        }
        return profile;
      } on AuthException catch (error) {
        lastAuth = error;
      }
    }
    if (lastAuth != null && lastAuth.message.isNotEmpty) {
      throw AuthFailure(lastAuth.message);
    }
    throw const AuthFailure('Could not verify the email code');
  }

  @override
  Future<void> sendMagicLink({required String email}) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: AuthRedirect.forCurrentPlatform(),
        shouldCreateUser: true,
      );
    } catch (error, stack) {
      _rethrowAuth(error, stack);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: AuthRedirect.forCurrentPlatform(),
      );
    } catch (error, stack) {
      _rethrowAuth(error, stack);
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      _setPasswordRecovery(false);
    } catch (error, stack) {
      _rethrowAuth(error, stack);
    }
  }

  @override
  Future<void> signInWithProvider(AuthProvider provider) async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        switch (provider) {
          AuthProvider.google => OAuthProvider.google,
          AuthProvider.apple => OAuthProvider.apple,
        },
        redirectTo: AuthRedirect.forCurrentPlatform(),
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        scopes: provider == AuthProvider.apple ? 'name email' : null,
      );
      if (!launched) throw const AuthBrowserLaunchFailed();
    } on AuthProviderUnavailable {
      rethrow;
    } on AuthBrowserLaunchFailed {
      rethrow;
    } on AuthException catch (error, stack) {
      if (authProviderDisabled(code: error.code, message: error.message)) {
        Error.throwWithStackTrace(AuthProviderUnavailable(provider), stack);
      }
      _rethrowAuth(error, stack);
    } on PlatformException catch (_, stack) {
      Error.throwWithStackTrace(const AuthBrowserLaunchFailed(), stack);
    }
  }

  /// Cancels the auth listener. The running app keeps the repository for
  /// the process lifetime; tests can call this.
  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _profiles.close();
    await _failures.close();
    await _recovery.close();
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> updateLocale(String locale) async {
    await _client.auth.updateUser(UserAttributes(data: {'locale': locale}));
    await _client
        .from('profiles')
        .update({
          'locale': locale,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', _client.auth.currentUser!.id);
  }
}

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Challenge>> fetchPublishedChallenges() async {
    final rows = await _client
        .from('challenges')
        .select('*, challenge_i18n(*)')
        .eq('status', 'published')
        .order('created_at');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(challengeFromRow)
        .where((c) => isPubliclyVisible(c.status))
        .toList();
  }

  @override
  Future<List<ChallengeDetail>> fetchPublishedDetails() async {
    final rows = await _client
        .from('challenges')
        .select('*, challenge_i18n(*), waypoints(*, waypoint_i18n(*))')
        .eq('status', 'published')
        .order('created_at');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(_detailFromRow)
        .where((detail) => isPubliclyVisible(detail.challenge.status))
        .toList();
  }

  @override
  Future<ChallengeDetail> fetchChallenge(String id) async {
    late final Map<String, dynamic> map;
    try {
      final row = await _client
          .from('challenges')
          .select('*, challenge_i18n(*), waypoints(*, waypoint_i18n(*))')
          .eq('id', id)
          .eq('status', 'published')
          .single();
      map = Map<String, dynamic>.from(row as Map);
    } on PostgrestException catch (error, stack) {
      if (error.code == 'PGRST116') {
        Error.throwWithStackTrace(ChallengeMissing(id), stack);
      }
      rethrow;
    }
    return _detailFromRow(map);
  }

  ChallengeDetail _detailFromRow(Map<String, dynamic> map) {
    final challenge = challengeFromRow(map);
    final waypointRows = (map['waypoints'] as List?) ?? const [];
    final waypoints = waypointRows
        .whereType<Map<String, dynamic>>()
        .map(waypointFromRow)
        .toList();
    return ChallengeDetail(challenge: challenge, waypoints: waypoints);
  }

  @override
  Future<List<PromoStripe>> fetchPublishedPromos({DateTime? now}) async {
    final moment = now ?? DateTime.now().toUtc();
    final rows = await _client
        .from('promo_stripes')
        .select('*, promo_stripe_i18n(*)')
        .eq('status', 'published')
        .order('sort_order');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => PromoStripe(
            id: row['id'] as String,
            status: publishStatusFromWire(row['status'] as String? ?? 'draft'),
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            imageUrl: row['image_url'] as String?,
            linkUrl: row['link_url'] as String?,
            challengeId: row['challenge_id'] as String?,
            startsAt: row['starts_at'] == null
                ? null
                : DateTime.parse(row['starts_at'] as String),
            endsAt: row['ends_at'] == null
                ? null
                : DateTime.parse(row['ends_at'] as String),
            translations: i18nFromRows(row['promo_stripe_i18n']),
          ),
        )
        .where((promo) => promo.isActiveAt(moment))
        .toList();
  }
}

class SupabaseProgressRepository implements ProgressRepository {
  SupabaseProgressRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ChallengeProgress?> fetchProgress(String challengeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final runRows = await _client
        .from('challenge_progress')
        .select()
        .eq('user_id', userId)
        .eq('challenge_id', challengeId)
        .maybeSingle();
    final waypointRows = await _client
        .from('waypoint_progress')
        .select('waypoint_id, waypoints!inner(challenge_id)')
        .eq('user_id', userId)
        .eq('waypoints.challenge_id', challengeId);
    final completed = <String>{};
    for (final row
        in (waypointRows as List).whereType<Map<String, dynamic>>()) {
      completed.add(row['waypoint_id'] as String);
    }
    if (runRows == null && completed.isEmpty) return null;
    return ChallengeProgress(
      challengeId: challengeId,
      status: runStatusFromWire(
        (runRows?['status'] as String?) ?? 'in_progress',
      ),
      completedWaypointIds: completed,
      completedAt: runRows?['completed_at'] == null
          ? null
          : DateTime.parse(runRows!['completed_at'] as String),
    );
  }

  @override
  Future<List<ChallengeProgress>> fetchCompleted() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('challenge_progress')
        .select('challenge_id, status, completed_at')
        .eq('user_id', userId)
        .eq('status', 'completed');
    return [
      for (final row in (rows as List).whereType<Map<String, dynamic>>())
        ChallengeProgress(
          challengeId: row['challenge_id'] as String,
          status: ChallengeRunStatus.completed,
          completedWaypointIds: const {},
          completedAt: row['completed_at'] == null
              ? null
              : DateTime.parse(row['completed_at'] as String),
        ),
    ];
  }

  @override
  Future<ChallengeProgress> verifyWaypoint({
    required String challengeId,
    required String waypointId,
    required String photoPath,
  }) async {
    await _client.rpc(
      'verify_waypoint',
      params: {'p_waypoint_id': waypointId, 'p_photo_path': photoPath},
    );
    return (await fetchProgress(challengeId))!;
  }

  @override
  Future<List<ChallengeWaypointPhoto>> fetchChallengePhotos(
    String challengeId,
  ) async {
    // Signed-out clients cannot read the view. When a session exists, the
    // query is not scoped to auth.uid() — the gallery is every user's photos.
    if (_client.auth.currentUser == null) return const [];
    final rows = await _client
        .from('challenge_waypoint_photos')
        .select('challenge_id, waypoint_id, photo_path, completed_at')
        .eq('challenge_id', challengeId)
        .not('photo_path', 'is', null)
        .order('completed_at', ascending: false)
        .order('waypoint_id');
    final photos = <ChallengeWaypointPhoto>[];
    for (final row in (rows as List).whereType<Map<String, dynamic>>()) {
      final path = displayablePhotoPath(row['photo_path'] as String?);
      if (path == null) continue;
      photos.add(
        ChallengeWaypointPhoto(
          challengeId: row['challenge_id'] as String? ?? challengeId,
          waypointId: row['waypoint_id'] as String,
          photoPath: path,
          completedAt: DateTime.parse(row['completed_at'] as String),
        ),
      );
    }
    photos.sort((a, b) {
      final byTime = b.completedAt.compareTo(a.completedAt);
      if (byTime != 0) return byTime;
      return a.waypointId.compareTo(b.waypointId);
    });
    return photos;
  }
}

class SupabasePurchaseRepository implements PurchaseRepository {
  SupabasePurchaseRepository(this._client);

  final SupabaseClient _client;

  Purchase? _fromRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    return Purchase(
      challengeId: row['challenge_id'] as String,
      status: purchaseStatusFromWire(row['status'] as String? ?? 'pending'),
      paidAt: dateTimeFromWire(row['paid_at']),
      rewardVariant: rewardVariantFromWire(row['reward_variant'] as String?),
    );
  }

  @override
  Future<Purchase?> fetchPurchase(String challengeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('purchases')
        .select()
        .eq('user_id', userId)
        .eq('challenge_id', challengeId)
        .maybeSingle();
    return _fromRow(row == null ? null : Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<CheckoutSession> startCheckout(
    String challengeId, {
    RewardVariant? rewardVariant,
  }) async {
    final response = await _client.functions.invoke(
      'start-fapi-checkout',
      body: {
        'challenge_id': challengeId,
        if (rewardVariant != null) 'reward_variant': rewardVariant.wire,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Checkout session did not return a URL');
    }
    return CheckoutSession(url: url);
  }

  @override
  Future<Purchase?> refreshPurchase(String challengeId) =>
      fetchPurchase(challengeId);
}

class SupabasePhotoStorage implements PhotoStorage {
  SupabasePhotoStorage(this._client);

  final SupabaseClient _client;
  static const bucket = 'waypoint-photos';

  /// One hour. Image.network caches decoded frames for the screen session.
  static const signedUrlTtlSeconds = 3600;
  static const _signedUrlBatch = 100;

  @override
  Future<String> uploadWaypointPhoto({
    required String userId,
    required String challengeId,
    required String waypointId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final id = const Uuid().v4();
    final path = '$userId/$challengeId/$waypointId/$id.jpg';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    return path;
  }

  @override
  Future<Map<String, String>> signedUrlsForPhotos(
    List<String> photoPaths,
  ) async {
    final unique = <String>[];
    final seen = <String>{};
    for (final raw in photoPaths) {
      final path = displayablePhotoPath(raw);
      if (path == null) continue;
      if (seen.add(path)) unique.add(path);
    }
    if (unique.isEmpty) return const {};
    final urls = <String, String>{};
    for (var i = 0; i < unique.length; i += _signedUrlBatch) {
      final end = math.min(i + _signedUrlBatch, unique.length);
      final results = await _client.storage
          .from(bucket)
          .createSignedUrlsResult(unique.sublist(i, end), signedUrlTtlSeconds);
      for (final result in results) {
        if (result is SignedUrlSuccess && result.signedUrl.isNotEmpty) {
          urls[result.path] = result.signedUrl;
        }
      }
    }
    return urls;
  }
}
