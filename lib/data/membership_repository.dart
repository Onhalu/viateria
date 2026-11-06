import '../domain/vandery_plus.dart';

/// Reads membership and starts checkout. There is no method that writes status.
abstract class MembershipRepository {
  Future<VanderyPlusMembership> fetchMine();

  /// Returns the FAPI form URL. Does not mark the user active.
  Future<Uri> startCheckout();
}
