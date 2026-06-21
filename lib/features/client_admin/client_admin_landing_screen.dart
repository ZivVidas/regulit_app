/// Landing screen for all client-side roles (client_admin, it_executor, employee).
///
/// Every role passes through here on workspace entry so the workflow-completion
/// check runs before the user reaches their actual home screen.
///
/// On mount it calls GET /customers/{id}/workflow-check, which returns:
///   • { redirectToWorkflow: false }
///       → customer already completed at least one workflow
///       → forward to the role-appropriate home (dashboard / tasks / task-list)
///
///   • { redirectToWorkflow: true, sessionId, workflowId, workflowName }
///       → customer has never completed any workflow
///       – sessionId non-null  → continue the most recent in-progress session
///       – sessionId null      → create a new session via POST /workflow-answers
///
/// The screen shows only a full-screen loading spinner; it's invisible to the
/// user on fast connections.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_client.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../app/theme.dart';

class ClientAdminLandingScreen extends ConsumerStatefulWidget {
  const ClientAdminLandingScreen({super.key});

  @override
  ConsumerState<ClientAdminLandingScreen> createState() =>
      _ClientAdminLandingState();
}

class _ClientAdminLandingState
    extends ConsumerState<ClientAdminLandingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final ctx = ref.read(customerContextProvider);
    final customerId = ctx?['customerId'] as String?;

    // Determine the role-appropriate home for this user so we know where to
    // forward them when no workflow redirect is needed.
    final role = (ctx?['role'] as String?) ?? '';
    final home = switch (role) {
      'it_executor' => AppRoutes.tasks,
      'employee'    => AppRoutes.taskList,
      _             => AppRoutes.dashboard, // client_admin or unknown
    };

    if (customerId == null || !mounted) {
      _go(home);
      return;
    }

    try {
      final dio = ref.read(dioProvider);

      // Single endpoint — backend checks whether the customer has any evaluated
      // workflow (workflow_answers_evaluation row). If not, it returns the first
      // workflow that still needs filling.
      final res = await dio.get<Map<String, dynamic>>(
        '/customers/$customerId/workflow-check',
      );

      if (!mounted) return;

      final data = res.data!;
      final hasEvaluated = data['redirectToWorkflow'] != true;

      // Tell the nav shell whether to show the full menu.
      // Written to a separate provider so the router is NOT triggered.
      ref.read(clientHasEvaluatedWorkflowsProvider.notifier).state =
          hasEvaluated;

      // Customer already completed at least one workflow → normal home screen.
      if (hasEvaluated) {
        _go(home);
        return;
      }

      // No completed workflow yet → redirect to fill-in.
      // Step 41: the new model creates a workflow_answer_group (one
      // session per customer environment). Fall back to single-session
      // mode only when the backend's workflow-check returns a sessionId
      // that's NOT linked to a group (legacy in-progress data).
      final workflowId   = data['workflowId']   as String;
      final workflowName = data['workflowName'] as String? ?? '';
      final existingId   = data['sessionId']    as String?;

      if (existingId != null) {
        // Continue the most recent in-progress legacy session.
        // (Group resumption isn't covered by /workflow-check yet — that
        // would require the backend to return a group_id field too.
        // Tracked as deferred enhancement.)
        context.goNamed(
          'workflowAnswer',
          pathParameters: {'sessionId': existingId},
          queryParameters: {'workflowName': workflowName},
        );
        return;
      }

      // No existing session — create a fresh workflow_answer_group with
      // one env-session per customer environment.
      final created = await dio.post<Map<String, dynamic>>(
        '/workflow-answer-groups',
        data: {'workflowId': workflowId, 'customerId': customerId},
      );
      if (!mounted) return;
      final groupId = created.data!['id'] as String;
      context.goNamed(
        'workflowAnswerGroup',
        pathParameters: {'groupId': groupId},
        queryParameters: {'workflowName': workflowName},
      );
    } catch (_) {
      if (mounted) _go(home);
    }
  }

  void _go(String path) {
    if (mounted) context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
