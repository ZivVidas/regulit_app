import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_provider.dart';

// ── CustomerContextNotifier ───────────────────────────────────────────────────
//
// Holds the currently-selected customer workspace for client-side users:
//   null       → not yet selected (router redirects to /select-customer)
//   non-null   → {customerId, customerName, role, …}
//
// Automatically resets to null whenever the authenticated user's identity
// changes (logout, or a different user logs in).  This guarantees that the
// previous user's workspace can never leak into the next user's session,
// regardless of how quickly the sign-in/sign-out cycle happens.
//
class CustomerContextNotifier extends StateNotifier<Map<String, dynamic>?> {
  CustomerContextNotifier(this._ref) : super(null) {
    // Watch the current user's ID.  When it changes (including to null on
    // logout, or to a different UUID when another user logs in), synchronously
    // reset to null so the router immediately redirects to /select-customer.
    _ref.listen<String?>(
      currentUserProvider.select((u) => u?.id),
      (prev, next) {
        if (prev != next) {
          state = null;
          // Also reset the workflow-evaluation flag so the next user/workspace
          // starts clean.
          _ref.read(clientHasEvaluatedWorkflowsProvider.notifier).state = false;
        }
      },
    );
  }

  final Ref _ref;
}

/// The currently selected customer workspace.
/// Consumers read/write exactly as before:
///   ref.watch(customerContextProvider)
///   ref.read(customerContextProvider.notifier).state = {...}
final customerContextProvider =
    StateNotifierProvider<CustomerContextNotifier, Map<String, dynamic>?>(
  (ref) => CustomerContextNotifier(ref),
);

// ── Has the current customer at least one analyzed workflow session? ──────────
//
// Stored separately from customerContextProvider so that writing to it does
// NOT trigger a router rebuild (the router only watches customerContextProvider
// and authStateProvider).  Writing to customerContextProvider caused an
// infinite loop: update → router rebuilds → new GoRouter → screen remounts →
// update → …
//
// Reset to false on logout / user switch (see CustomerContextNotifier above)
// and whenever the user selects a new workspace (see customer_select_screen).
final clientHasEvaluatedWorkflowsProvider = StateProvider<bool>((ref) => false);

// ── Direct nav-gate check (used by AppShell) ─────────────────────────────────
//
// Calls workflow-check for a given customerId and returns true when
// redirectToWorkflow == false (i.e. at least one evaluated session exists).
//
// Using FutureProvider.family (non-autoDispose) so the result is cached per
// customerId across rebuilds — no flicker, no extra round-trips on re-render.
// Invalidate via ref.invalidate(clientNavEnabledProvider(customerId)) after a
// workflow is completed to force a fresh check.
final clientNavEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, customerId) async {
  try {
    final dio = ref.read(dioProvider);
    final res = await dio
        .get<Map<String, dynamic>>('/customers/$customerId/workflow-check');
    return res.data?['redirectToWorkflow'] != true;
  } catch (_) {
    return false;
  }
});

// ── All customers this user is linked to ─────────────────────────────────────
/// Used by /select-customer to list workspaces and to auto-select when the
/// user belongs to exactly one customer.
final userLinkedCustomersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final dio = ref.watch(dioProvider);
  final res = await dio.get<List<dynamic>>('/users/${user.id}/customers');
  return (res.data ?? []).cast<Map<String, dynamic>>();
});
