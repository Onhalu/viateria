import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/vandery_plus.dart';
import 'membership_repository.dart';

/// User-JWT client only. Selects the caller's row and invokes checkout.
/// It does not update `vandery_plus_memberships` and it has no service role.
class SupabaseMembershipRepository implements MembershipRepository {
  SupabaseMembershipRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<VanderyPlusMembership> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return VanderyPlusMembership.none;
    final row = await _client
        .from('vandery_plus_memberships')
        .select('status, expires_at, cancel_at_period_end')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return VanderyPlusMembership.none;
    return membershipFromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<Uri> startCheckout() async {
    final response = await _client.functions.invoke(
      'start-fapi-checkout',
      body: const {'product': 'vandery_plus'},
    );
    final data = response.data;
    if (data is! Map || data['url'] is! String) {
      throw StateError('checkout_failed');
    }
    final url = Uri.parse(data['url'] as String);
    if (url.queryParameters.containsKey('challenge_id')) {
      throw StateError('challenge_id_not_allowed');
    }
    return url;
  }
}
