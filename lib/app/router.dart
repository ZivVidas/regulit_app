import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/auth/auth_provider.dart';
import '../core/customer/customer_context_provider.dart';
import '../core/models/user.dart'; // UserRole enum used in _homeForRole()
import '../features/auth/login_screen.dart';
import '../features/customer_select/customer_select_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/customers/customer_dashboard_screen.dart';
import '../features/dashboard/executive_dashboard_screen.dart';
import '../features/dashboard/admin_dashboard_screen.dart';
import '../features/tasks/task_board_screen.dart';
import '../features/tasks/task_list_screen.dart';
import '../features/portfolio/portfolio_screen.dart';
import '../features/gaps/gap_analysis_screen.dart';
import '../features/classifier/classifier_wizard_screen.dart';
import '../features/audit_pack/audit_pack_screen.dart';
import '../features/evidence/evidence_queue_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../features/quizzes/quiz_numeric_engine_screen.dart';
import '../features/quizzes/quiz_questions_screen.dart';
import '../features/quizzes/quiz_result_engine_screen.dart';
import '../features/quizzes/quiz_steps_screen.dart';
import '../features/quizzes/quizzes_screen.dart';
import '../features/workflows/workflow_answer_screen.dart';
import '../features/workflows/workflow_quizzes_screen.dart';
import '../features/workflows/workflow_rule_engine_screen.dart';
import '../features/workflows/workflows_screen.dart';
import '../features/agents/agents_screen.dart';
import '../features/users/users_screen.dart';
import '../features/client_admin/client_users_screen.dart';
import '../shared/widgets/app_shell.dart';

part 'router.g.dart';

/// Route name constants — use these instead of raw strings
abstract class AppRoutes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const tasks = '/tasks';
  static const auditPack = '/audit-pack';
  static const aiChat = '/ai-assistant';
  static const portfolio = '/admin/tenants';
  static const tenantGaps = '/admin/tenants/:tenantId/gaps';
  static const classifier = '/admin/tenants/:tenantId/classifier';
  static const evidenceQueue = '/admin/evidence-queue';
  // Admin management screens (real API)
  static const users = '/admin/users';
  static const customers = '/admin/customers';
  static const quizzes = '/admin/quizzes';
  static const quizSteps = '/admin/quizzes/:quizId/steps';
  static const quizQuestions = '/admin/quizzes/:quizId/steps/:stepId/questions';
  static const quizResultEngine = '/admin/quizzes/:quizId/result-engine';
  static const quizNumericEngine = '/admin/quizzes/:quizId/numeric-engine';
  static const workflows = '/admin/workflows';
  static const workflowQuizzes = '/admin/workflows/:workflowId/quizzes';
  static const workflowRuleEngine = '/admin/workflows/:workflowId/rule-engine';
  static const workflowAnswer = '/workflow-answer/:sessionId';
  static const agents = '/admin/agents';
  // Step 2: new admin routes
  static const adminDashboard = '/admin/dashboard';
  static const customerDashboard = '/admin/customers/:customerId/dashboard';
  // Customer workspace selection (client-side users)
  static const selectCustomer = '/select-customer';
  // Step 14: flat task list (employee/itExecutor/clientAdmin)
  static const taskList = '/task-list';
  // Client-admin user management
  static const clientUsers = '/client-users';
}

@riverpod
GoRouter router(RouterRef ref) {
  // React to both auth state and customer context changes.
  // NOTE: customerContextProvider already self-resets when the user identity
  // changes (see CustomerContextNotifier), so no extra listener is needed here.
  final authState = ref.watch(authStateProvider);
  final customerContext = ref.watch(customerContextProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,

    // ── Global redirect: enforces auth + role-based routing ──
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final loc = state.matchedLocation;
      final isLoginPage = loc == AppRoutes.login;
      final isSelectCustomer = loc == AppRoutes.selectCustomer;

      // Not logged in → always go to login
      if (user == null) {
        return isLoginPage ? null : AppRoutes.login;
      }

      // Client-side users (role == null or isClientSide) must select a workspace first
      if (user.role?.isClientSide ?? true) {
        if (customerContext == null && !isSelectCustomer) {
          return AppRoutes.selectCustomer;
        }
        if (customerContext != null && isSelectCustomer) {
          // Resolve home using the customer-context role, not the bare user role
          return _homeForRole(_roleFromCtxMap(customerContext));
        }
      }

      // Logged in but on login page → send to correct home
      if (isLoginPage) {
        return _homeForRole(user.role);
      }

      // Block clients from admin routes
      if (loc.startsWith('/admin') && !(user.role?.isReguLitStaff ?? false)) {
        return _homeForRole(user.role);
      }

      // Enforce role-based access for client-side users (step 15)
      if (customerContext != null) {
        final ctxRole = _roleFromCtxMap(customerContext);

        // Routes only client_admin can reach
        const clientAdminOnly = [
          AppRoutes.dashboard,
          AppRoutes.auditPack,
          AppRoutes.aiChat,
          AppRoutes.clientUsers,
        ];

        if (ctxRole == UserRole.employee) {
          // employee: only task list screen
          if (clientAdminOnly.contains(loc) || loc == AppRoutes.tasks) {
            return AppRoutes.taskList;
          }
        } else if (ctxRole == UserRole.itExecutor) {
          // it_executor: kanban + task list only (no dashboard/audit/ai)
          if (clientAdminOnly.contains(loc)) {
            return AppRoutes.tasks;
          }
        }
      }

      return null; // no redirect needed
    },

    routes: [
      // ── Public ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (_, __) => _fadePage(const LoginScreen()),
      ),

      // ── Customer workspace selector (outside shell — no sidebar) ──
      GoRoute(
        path: AppRoutes.selectCustomer,
        name: 'selectCustomer',
        pageBuilder: (_, __) => _fadePage(const CustomerSelectScreen()),
      ),

      // ── App shell wraps all authenticated screens ────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // ── Admin management (regulitAdmin) ─────────────────
          GoRoute(
            path: AppRoutes.users,
            name: 'users',
            pageBuilder: (_, __) => _fadePage(const UsersScreen()),
          ),
          GoRoute(
            path: AppRoutes.customers,
            name: 'customers',
            pageBuilder: (_, __) => _fadePage(const CustomersScreen()),
          ),
          GoRoute(
            path: AppRoutes.quizzes,
            name: 'quizzes',
            pageBuilder: (_, __) => _fadePage(const QuizzesScreen()),
          ),
          GoRoute(
            path: AppRoutes.quizSteps,
            name: 'quizSteps',
            pageBuilder: (context, state) {
              final quizId = state.pathParameters['quizId']!;
              final quizName =
                  state.uri.queryParameters['name'] ?? 'Quiz';
              return _fadePage(
                  QuizStepsScreen(quizId: quizId, quizName: quizName));
            },
          ),
          GoRoute(
            path: AppRoutes.quizQuestions,
            name: 'quizQuestions',
            pageBuilder: (context, state) {
              final quizId = state.pathParameters['quizId']!;
              final stepId = state.pathParameters['stepId']!;
              final stepName =
                  state.uri.queryParameters['stepName'] ?? 'Step';
              final quizName =
                  state.uri.queryParameters['quizName'] ?? 'Quiz';
              return _fadePage(QuizQuestionsScreen(
                quizId: quizId,
                stepId: stepId,
                stepName: stepName,
                quizName: quizName,
              ));
            },
          ),
          GoRoute(
            path: AppRoutes.quizResultEngine,
            name: 'quizResultEngine',
            pageBuilder: (context, state) {
              final quizId = state.pathParameters['quizId']!;
              final quizName =
                  state.uri.queryParameters['name'] ?? 'Quiz';
              return _fadePage(
                  QuizResultEngineScreen(quizId: quizId, quizName: quizName));
            },
          ),
          GoRoute(
            path: AppRoutes.quizNumericEngine,
            name: 'quizNumericEngine',
            pageBuilder: (context, state) {
              final quizId = state.pathParameters['quizId']!;
              final quizName =
                  state.uri.queryParameters['name'] ?? 'Quiz';
              return _fadePage(QuizNumericEngineScreen(
                  quizId: quizId, quizName: quizName));
            },
          ),
          GoRoute(
            path: AppRoutes.workflows,
            name: 'workflows',
            pageBuilder: (_, __) => _fadePage(const WorkflowsScreen()),
          ),
          GoRoute(
            path: AppRoutes.workflowQuizzes,
            name: 'workflowQuizzes',
            pageBuilder: (context, state) {
              final workflowId = state.pathParameters['workflowId']!;
              final workflowName =
                  state.uri.queryParameters['name'] ?? 'Workflow';
              return _fadePage(WorkflowQuizzesScreen(
                workflowId: workflowId,
                workflowName: workflowName,
              ));
            },
          ),
          GoRoute(
            path: AppRoutes.workflowRuleEngine,
            name: 'workflowRuleEngine',
            pageBuilder: (context, state) {
              final workflowId = state.pathParameters['workflowId']!;
              final workflowName =
                  state.uri.queryParameters['name'] ?? 'Workflow';
              return _fadePage(WorkflowRuleEngineScreen(
                workflowId: workflowId,
                workflowName: workflowName,
              ));
            },
          ),
          GoRoute(
            path: AppRoutes.workflowAnswer,
            name: 'workflowAnswer',
            pageBuilder: (context, state) {
              final sessionId = state.pathParameters['sessionId']!;
              final workflowName =
                  state.uri.queryParameters['workflowName'] ?? 'Workflow';
              return _fadePage(WorkflowAnswerScreen(
                sessionId: sessionId,
                workflowName: workflowName,
              ));
            },
          ),
          GoRoute(
            path: AppRoutes.agents,
            name: 'agents',
            pageBuilder: (_, __) => _fadePage(const AgentsScreen()),
          ),
          GoRoute(
            path: AppRoutes.adminDashboard,
            name: 'adminDashboard',
            pageBuilder: (_, __) =>
                _fadePage(const AdminDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.customerDashboard,
            name: 'customerDashboard',
            pageBuilder: (context, state) {
              final customerId =
                  state.pathParameters['customerId']!;
              return _fadePage(
                  CustomerDashboardScreen(customerId: customerId));
            },
          ),

          // ── Client Admin (CEO) routes ────────────────────────
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (_, __) =>
                _fadePage(const ExecutiveDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.auditPack,
            name: 'auditPack',
            pageBuilder: (_, __) => _fadePage(const AuditPackScreen()),
          ),
          GoRoute(
            path: AppRoutes.aiChat,
            name: 'aiChat',
            pageBuilder: (_, __) => _fadePage(const AiChatScreen()),
          ),

          // ── IT Executor routes ───────────────────────────────
          GoRoute(
            path: AppRoutes.tasks,
            name: 'tasks',
            pageBuilder: (_, __) => _fadePage(const TaskBoardScreen()),
          ),

          // ── Task list (flat view — employee / itExecutor / clientAdmin) ──
          GoRoute(
            path: AppRoutes.taskList,
            name: 'taskList',
            pageBuilder: (_, __) => _fadePage(const TaskListScreen()),
          ),

          // ── Client-admin user management ─────────────────────
          GoRoute(
            path: AppRoutes.clientUsers,
            name: 'clientUsers',
            pageBuilder: (_, __) => _fadePage(const ClientUsersScreen()),
          ),

          // ── Regulit Staff (CSM / Analyst) routes ─────────────
          GoRoute(
            path: AppRoutes.portfolio,
            name: 'portfolio',
            pageBuilder: (_, __) => _fadePage(const PortfolioScreen()),
          ),
          GoRoute(
            path: AppRoutes.tenantGaps,
            name: 'tenantGaps',
            pageBuilder: (context, state) {
              final tenantId = state.pathParameters['tenantId']!;
              return _fadePage(GapAnalysisScreen(tenantId: tenantId));
            },
          ),
          GoRoute(
            path: AppRoutes.classifier,
            name: 'classifier',
            pageBuilder: (context, state) {
              final tenantId = state.pathParameters['tenantId']!;
              return _fadePage(
                  ClassifierWizardScreen(tenantId: tenantId));
            },
          ),
          GoRoute(
            path: AppRoutes.evidenceQueue,
            name: 'evidenceQueue',
            pageBuilder: (_, __) =>
                _fadePage(const EvidenceQueueScreen()),
          ),
        ],
      ),
    ],

    // ── Error page ────────────────────────────────────────────
    errorPageBuilder: (context, state) => _fadePage(
      Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('404',
                  style: TextStyle(
                      fontSize: 48, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Page not found: ${state.uri}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Maps the `role` string inside a customer-context map to a [UserRole].
UserRole? _roleFromCtxMap(Map<String, dynamic>? ctx) {
  return switch (ctx?['role'] as String?) {
    'client_admin' => UserRole.clientAdmin,
    'it_executor'  => UserRole.itExecutor,
    'employee'     => UserRole.employee,
    _              => null,
  };
}

/// Which screen to land on after login, based on role.
/// Null role = client user (role lives in customer context) → dashboard.
String _homeForRole(UserRole? role) {
  if (role == null) return AppRoutes.dashboard;
  switch (role) {
    case UserRole.regulitAdmin:
      return AppRoutes.users; // Admin lands on User Management
    case UserRole.csm:
    case UserRole.analyst:
      return AppRoutes.portfolio;
    case UserRole.clientAdmin:
      return AppRoutes.dashboard;
    case UserRole.itExecutor:
      return AppRoutes.tasks;
    case UserRole.employee:
      return AppRoutes.taskList;
  }
}

/// Smooth fade transition instead of default slide
CustomTransitionPage<void> _fadePage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 180),
  );
}
