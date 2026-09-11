import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'repositories.dart';

List<LocalizedText> _i18nFromRows(
  dynamic raw, {
  String titleKey = 'title',
  String descriptionKey = 'description',
}) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(
        (row) => LocalizedText(
          locale: row['locale'] as String? ?? 'en',
          title: row[titleKey] as String? ?? '',
          description: row[descriptionKey] as String? ?? '',
          subtitle: row['subtitle'] as String?,
          ctaLabel: row['cta_label'] as String?,
          diplomaHeadline: row['diploma_headline'] as String?,
          diplomaBody: row['diploma_body'] as String?,
          hint: row['hint'] as String?,
        ),
      )
      .toList();
}

Challenge _challengeFromRow(Map<String, dynamic> row) {
  return Challenge(
    id: row['id'] as String,
    slug: row['slug'] as String,
    accessMode: accessModeFromWire(row['access_mode'] as String? ?? 'open'),
    pricingType: pricingTypeFromWire(row['pricing_type'] as String? ?? 'free'),
    priceCents: (row['price_cents'] as num?)?.toInt() ?? 0,
    currency: row['currency'] as String? ?? 'eur',
    status: publishStatusFromWire(row['status'] as String? ?? 'draft'),
    coverImageUrl: row['cover_image_url'] as String?,
    region: row['region'] as String?,
    stripePriceId: row['stripe_price_id'] as String?,
    rewardVariant: rewardVariantFromWire(row['reward_variant'] as String?),
    translations: _i18nFromRows(row['challenge_i18n']),
  );
}

Waypoint _waypointFromRow(Map<String, dynamic> row) {
  return Waypoint(
    id: row['id'] as String,
    challengeId: row['challenge_id'] as String,
    sortOrder: (row['sort_order'] as num).toInt(),
    lat: (row['lat'] as num).toDouble(),
    lng: (row['lng'] as num).toDouble(),
    elevationM: (row['elevation_m'] as num?)?.toDouble() ?? 0,
    translations: _i18nFromRows(row['waypoint_i18n']),
  );
}

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
        .map(_challengeFromRow)
        .where((c) => isPubliclyVisible(c.status))
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
    final challenge = _challengeFromRow(map);
    final waypointRows = (map['waypoints'] as List?) ?? const [];
    final waypoints = waypointRows
        .whereType<Map<String, dynamic>>()
        .map(_waypointFromRow)
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
            translations: _i18nFromRows(row['promo_stripe_i18n']),
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
      'create-checkout-session',
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
