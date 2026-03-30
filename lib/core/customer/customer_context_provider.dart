import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_provider.dart';

/// The currently selected customer workspace for client-side users.
///
/// • null  → user hasn't picked a workspace yet (router redirects to /select-customer)
/// • non-null → keys: customerId, customerName, role
final customerContextProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// All customers the current user is linked to.
/// Used on the customer-select screen and to auto-select when there's only 1.
final userLinkedCustomersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get<List<dynamic>>('/users/${user.id}/customers');
  return (res.data ?? []).cast<Map<String, dynamic>>();
});
