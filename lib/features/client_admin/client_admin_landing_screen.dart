/// Step-21 landing screen for client_admin users.
///
/// On mount it calls two lightweight API endpoints in parallel:
///   1. GET /customers/{id}/workflows   → how many workflows are linked?
///   2. GET /workflow-answers/by-customer/{id} → do any have isActive=true?
///
/// Decision logic
/// ──────────────
///   • 0 workflows  or  2+ workflows  →  go to /dashboard  (normal hub)
///   • exactly 1 workflow:
///       – has an is_active session  →  workflow is filled  →  /dashboard
///       – no is_active session      →  not yet filled:
///             * in-progress session exists  → continue it (go to answer screen)
///             * no session at all           → create a new one, then go to it
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

    if (customerId == null || !mounted) {
      _go(AppRoutes.dashboard);
      return;
    }

    try {
      final dio = ref.read(dioProvider);

      final results = await Future.wait([
        dio.get<List<dynamic>>('/customers/$customerId/workflows'),
        dio.get<List<dynamic>>('/workflow-answers/by-customer/$customerId'),
      ]);

      if (!mounted) return;

      final workflows =
          (results[0].data ?? []).cast<Map<String, dynamic>>();
      final sessions =
          (results[1].data ?? []).cast<Map<String, dynamic>>();

      // Only intervene when exactly 1 workflow is assigned
      if (workflows.length != 1) {
        _go(AppRoutes.dashboard);
        return;
      }

      final wf = workflows.first;
      final workflowId = wf['workflowId'] as String;
      final workflowName = wf['workflowName'] as String? ?? '';

      // Sessions belonging to this workflow, newest first
      final wfSessions = sessions
          .where((s) => s['workflowId'] == workflowId)
          .toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse(a['dateModified'] as String? ?? '') ??
              DateTime(0);
          final bd = DateTime.tryParse(b['dateModified'] as String? ?? '') ??
              DateTime(0);
          return bd.compareTo(ad);
        });

      // If there is already a completed (active) session → go to dashboard
      final hasCompleted = wfSessions.any((s) => s['isActive'] == true);
      if (hasCompleted) {
        _go(AppRoutes.dashboard);
        return;
      }

      // No completed session — navigate the user to fill the workflow.
      String sessionId;
      if (wfSessions.isNotEmpty) {
        // Continue the most recently modified in-progress session
        sessionId = wfSessions.first['id'] as String;
      } else {
        // Create a brand-new session
        final res = await dio.post<Map<String, dynamic>>(
          '/workflow-answers',
          data: {'workflowId': workflowId, 'customerId': customerId},
        );
        if (!mounted) return;
        sessionId = res.data!['id'] as String;
      }

      context.goNamed(
        'workflowAnswer',
        pathParameters: {'sessionId': sessionId},
        queryParameters: {'workflowName': workflowName},
      );
    } catch (_) {
      if (mounted) _go(AppRoutes.dashboard);
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
