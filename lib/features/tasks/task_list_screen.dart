/// Task List Screen — flat list view of tasks for the selected session.
/// Permissions:
/// • it_executor  → sees ALL tasks; tapping opens full edit dialog.
/// • client_admin → sees ALL tasks; can change status only on assigned tasks.
/// • employee     → sees ALL tasks; can change status only on assigned tasks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../core/models/user.dart';
import '../../core/models/workflow_task.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_localizations.dart';
import 'task_detail_sheet.dart';
import 'task_edit_dialog.dart';

// ─────────────────────────────────────────────────────────────
// Local models
// ─────────────────────────────────────────────────────────────

class _ListSession {
  final String id;
  final String workflowName;
  const _ListSession({required this.id, required this.workflowName});

  factory _ListSession.fromJson(Map<String, dynamic> j) => _ListSession(
        id: j['id'] as String,
        workflowName: j['workflowName'] as String? ?? '—',
      );
}

// ─────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────

final _listSessionsProvider =
    FutureProvider.autoDispose.family<List<_ListSession>, String>(
  (ref, customerId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<List<dynamic>>(
      '/workflow-answers/active-sessions/$customerId',
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(_ListSession.fromJson)
        .toList();
  },
);

// All roles now see ALL tasks for the session.
// Status-change permission is enforced in the UI (assigned-to-me check).
final _sessionTasksListProvider =
    FutureProvider.autoDispose.family<List<WorkflowTask>, String>(
  (ref, sessionId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<Map<String, dynamic>>(
      '/workflow-tasks',
      queryParameters: {
        'workflow_answer_id': sessionId,
        'page_size': 200,
      },
    );
    final items = (res.data?['items'] as List<dynamic>?) ?? [];
    return items
        .cast<Map<String, dynamic>>()
        .map(WorkflowTask.fromJson)
        .toList();
  },
);

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String? _selectedSessionId;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerId =
        ref.watch(customerContextProvider)?['customerId'] as String?;
    final user = ref.watch(currentUserProvider);

    // Determine context role (may come from customerContext for client users).
    // Customer context stores role as snake_case ('client_admin', 'it_executor',
    // 'employee') so we map explicitly instead of matching enum.name (camelCase).
    final ctxRole = (() {
      final ctx = ref.watch(customerContextProvider);
      if (ctx != null) {
        return switch (ctx['role'] as String?) {
          'client_admin' => UserRole.clientAdmin,
          'it_executor'  => UserRole.itExecutor,
          'employee'     => UserRole.employee,
          _              => user?.role ?? UserRole.employee,
        };
      }
      return user?.role ?? UserRole.employee;
    })();

    // it_executor: can create / edit / delete tasks; tapping always opens edit.
    // client_admin & employee: view all tasks; status change only on assigned.
    final isItExecutor = ctxRole == UserRole.itExecutor;
    final isEmployee   = ctxRole == UserRole.employee;

    // Logged-in user ID — for task-assignment status-change check.
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('All Tasks'),
        actions: [
          // Refresh — always visible
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20),
            color: AppColors.muted,
            tooltip: 'Refresh',
            onPressed: () {
              if (customerId != null) {
                ref.invalidate(_listSessionsProvider(customerId));
              }
              if (_selectedSessionId != null) {
                ref.invalidate(
                    _sessionTasksListProvider(_selectedSessionId!));
              }
            },
          ),
          // Switch to Kanban — hidden for employee (router also blocks them)
          if (!isEmployee)
            Tooltip(
              message: 'Switch to Kanban View',
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.view_kanban_outlined, size: 22),
                  color: AppColors.blue,
                  onPressed: () => context.go(AppRoutes.tasks),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.blue.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: customerId == null
          ? const Center(
              child: Text('No customer selected.',
                  style: TextStyle(color: AppColors.muted)))
          : Column(
              children: [
                // ── Session picker ─────────────────────────────
                _SessionBar(
                  customerId: customerId,
                  selectedId: _selectedSessionId,
                  onChanged: (id) => setState(() => _selectedSessionId = id),
                  onSessionLoaded: (firstId) {
                    if (_selectedSessionId == null) {
                      setState(() => _selectedSessionId = firstId);
                    }
                  },
                ),

                // ── Search box ─────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search tasks…',
                      prefixIcon:
                          const Icon(Icons.search, size: 18, color: AppColors.muted),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                ),

                // ── Task list ──────────────────────────────────
                Expanded(
                  child: _selectedSessionId == null
                      ? const Center(
                          child: Text('Select an assessment session above.',
                              style: TextStyle(color: AppColors.muted)))
                      : _TaskListBody(
                          sessionId: _selectedSessionId!,
                          isItExecutor: isItExecutor,
                          currentUserId: currentUserId,
                          search: _search,
                        ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Session picker bar
// ─────────────────────────────────────────────────────────────

class _SessionBar extends ConsumerWidget {
  final String customerId;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onSessionLoaded;

  const _SessionBar({
    required this.customerId,
    required this.selectedId,
    required this.onChanged,
    required this.onSessionLoaded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(_listSessionsProvider(customerId));

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: sessionsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Failed to load sessions',
            style: TextStyle(color: AppColors.danger, fontSize: 12)),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Text('No active sessions',
                style: TextStyle(color: AppColors.muted, fontSize: 13));
          }

          // Auto-select first session
          if (selectedId == null && sessions.isNotEmpty) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onSessionLoaded(sessions.first.id));
          }

          final effectiveId = selectedId != null &&
                  sessions.any((s) => s.id == selectedId)
              ? selectedId
              : sessions.first.id;

          return Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 16, color: AppColors.muted),
              const Gap(8),
              const Text('Session:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted)),
              const Gap(12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: effectiveId,
                  isExpanded: true,
                  isDense: true,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  items: sessions
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.workflowName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Task list body
// ─────────────────────────────────────────────────────────────

class _TaskListBody extends ConsumerWidget {
  final String sessionId;
  /// True only for it_executor — tapping opens the full edit dialog.
  final bool isItExecutor;
  /// Current logged-in user UUID — for status-change assignment check.
  final String? currentUserId;
  final String search;

  const _TaskListBody({
    required this.sessionId,
    required this.isItExecutor,
    required this.currentUserId,
    required this.search,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(_sessionTasksListProvider(sessionId));

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const Gap(12),
            Text(e.toString(),
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            const Gap(12),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(_sessionTasksListProvider(sessionId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (allTasks) {
        final tasks = search.isEmpty
            ? allTasks
            : allTasks
                .where((t) =>
                    t.taskName
                        .toLowerCase()
                        .contains(search.toLowerCase()) ||
                    (t.whatToDo
                            ?.toLowerCase()
                            .contains(search.toLowerCase()) ??
                        false))
                .toList();

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.task_outlined, size: 48, color: AppColors.muted),
                const Gap(12),
                Text(
                  search.isNotEmpty
                      ? 'No tasks match "$search"'
                      : 'No tasks found for this session.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_sessionTasksListProvider(sessionId)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const Gap(8),
            itemBuilder: (context, i) {
              final task = tasks[i];
              // it_executor always opens the edit dialog — canChangeStatus
              // only applies to the detail sheet (client_admin / employee).
              // Both status change and evidence upload are allowed only when
              // the task is assigned to the current user.
              final canChangeStatus = currentUserId != null &&
                  task.assignedToUserId == currentUserId;
              return _TaskListTile(
                task: task,
                isItExecutor: isItExecutor,
                canChangeStatus: canChangeStatus,
                l10n: l10n,
                onRefresh: () =>
                    ref.invalidate(_sessionTasksListProvider(sessionId)),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Task tile
// ─────────────────────────────────────────────────────────────

class _TaskListTile extends StatelessWidget {
  final WorkflowTask task;
  /// True when current user is it_executor — tap opens full edit dialog.
  final bool isItExecutor;
  /// True when current user may change this task's status.
  final bool canChangeStatus;
  final AppLocalizations l10n;
  final VoidCallback onRefresh;

  const _TaskListTile({
    required this.task,
    required this.isItExecutor,
    required this.canChangeStatus,
    required this.l10n,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final status = task.status;
    final accent = _statusColor(status);
    final overdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        status != WorkflowTaskStatus.approved;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetail(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),

              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.taskName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Chip(label: status.label, color: accent),
                        if (task.assignedToUserName != null)
                          _Chip(
                            label: task.assignedToUserName!,
                            color: AppColors.blue,
                            icon: Icons.person_outline,
                          ),
                        if (task.dueDate != null)
                          _Chip(
                            label: DateFormat('dd MMM yyyy')
                                .format(task.dueDate!),
                            color: overdue ? AppColors.danger : AppColors.muted,
                            icon: Icons.calendar_today_outlined,
                          ),
                        if (task.estimatedFine != null)
                          _Chip(
                            label:
                                '₪${NumberFormat.compact().format(task.estimatedFine)}',
                            color: AppColors.orange,
                            icon: Icons.account_balance_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    if (isItExecutor) {
      // it_executor always opens the full edit dialog.
      showDialog<bool>(
        context: context,
        builder: (_) => TaskEditDialog(task: task, l10n: l10n),
      ).then((refreshed) {
        if (refreshed == true) onRefresh();
      });
    } else {
      // client_admin / employee: read-only detail sheet.
      // Status change is enabled only if this task is assigned to them.
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => TaskDetailSheet(
          task: task,
          canChangeStatus: canChangeStatus,
          onStatusChanged: onRefresh,
        ),
      );
    }
  }

  static Color _statusColor(WorkflowTaskStatus s) => switch (s) {
        WorkflowTaskStatus.todo          => AppColors.muted,
        WorkflowTaskStatus.inProgress    => AppColors.warning,
        WorkflowTaskStatus.pendingReview => AppColors.orange,
        WorkflowTaskStatus.approved      => AppColors.success,
        WorkflowTaskStatus.overdue       => AppColors.danger,
      };
}

// ─────────────────────────────────────────────────────────────
// Small chip used in tile
// ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const Gap(3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
