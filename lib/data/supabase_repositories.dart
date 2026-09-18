import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'challenge_mapping.dart';
import 'repositories.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  Profile? _mapUser(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? {};
    return Profile(
      id: user.id,
      email: user.email,
      displayName: meta['display_name'] as String?,
      locale: (meta['locale'] as String?) ?? 'cs',
    );
  }

  @override
  Profile? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<Profile?> authState() {
    return _client.auth.onAuthStateChange.map(
      (event) => _mapUser(event.session?.user),
    );
  }

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
    for (final type in [OtpType.signup, OtpType.email]) {
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
}
