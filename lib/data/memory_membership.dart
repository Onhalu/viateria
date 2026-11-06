import '../domain/vandery_plus.dart';
import 'membership_repository.dart';

/// In-memory membership for tests and the unconfigured shell.
class MemoryMembershipRepository implements MembershipRepository {
  MemoryMembershipRepository({VanderyPlusMembership? initial})
    : current = initial ?? VanderyPlusMembership.none;

  VanderyPlusMembership current;
  int checkoutCalls = 0;
  Uri checkoutUrl = Uri.parse('https://sandbox.fapi.example/vandery-plus');
  Object? checkoutError;
  Object? readError;

  @override
  Future<VanderyPlusMembership> fetchMine() async {
    final failure = readError;
    if (failure != null) throw failure;
    return current;
  }

  @override
  Future<Uri> startCheckout() async {
    checkoutCalls += 1;
    final failure = checkoutError;
    if (failure != null) throw failure;
    return checkoutUrl;
  }
}
