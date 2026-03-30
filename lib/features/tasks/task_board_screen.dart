import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../core/models/workflow_task.dart';
import '../../l10n/app_localizations.dart';
import 'task_detail_sheet.dart';
import 'task_edit_dialog.dart';

// CustomerUserItem and customerUsersProvider are now in task_edit_dialog.dart
// and re-exported from here via the import above.

class ActiveSession {
  final String id;
  final String workflowId;
  final String workflowName;
  const ActiveSession({
    required this.id,
    required this.workflowId,
    required this.workflowName,
  });

  factory ActiveSession.fromJson(Map<String, dynamic> j) => ActiveSession(
        id: j['id'] as String,
        workflowId: j['workflowId'] as String,
        workflowName: j['workflowName'] as String,
      );
}

// ── Providers ──────────────────────────────────────────────────────────────────

/// Active workflow-answer sessions for a customer (the select-box data).
/// autoDispose → data is re-fetched from the server whenever the screen mounts.
final activeSessionsProvider =
    FutureProvider.autoDispose.family<List<ActiveSession>, String>((ref, customerId) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<List<dynamic>>(
    '/workflow-answers/active-sessions/$customerId',
  );
  return (res.data ?? [])
      .map((e) => ActiveSession.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Tasks for a specific workflow_answer_id session.
/// autoDispose → data is re-fetched from the server whenever the screen mounts.
final sessionTasksProvider =
    FutureProvider.autoDispose.family<List<WorkflowTask>, String>((ref, sessionId) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    '/workflow-tasks',
    queryParameters: {'workflow_answer_id': sessionId, 'page_size': 200},
  );
  final items = (res.data!['items'] as List<dynamic>);
  return items
      .map((e) => WorkflowTask.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class TaskBoardScreen extends ConsumerStatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  ConsumerState<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends ConsumerState<TaskBoardScreen> {
  String? _selectedSessionId;
  WorkflowTaskStatus? _filter;

  String? _customerId() {
    final ctx = ref.read(customerContextProvider);
    return ctx?['customerId'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customerId = ref.watch(customerContextProvider)?['customerId'] as String?;

    if (customerId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sessionsAsync = ref.watch(activeSessionsProvider(customerId));

    // Role resolution:
    //   it_executor    → create / edit / delete any task (always opens edit dialog).
    //   client_admin   → view all tasks & evidence; change status + add/remove evidence
    //                    only on tasks assigned to themselves.
    //   employee       → same as client_admin.
    final customerCtx = ref.watch(customerContextProvider);
    final ctxRoleStr  = customerCtx?['role'] as String?;
    final isItExecutor = ctxRoleStr == 'it_executor' ||
                         ref.watch(isItExecutorProvider); // fallback for demo users
    final canEdit = isItExecutor;

    // Current user ID — used to check task assignment for status-change permission.
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(activeSessionsProvider(customerId)),
        ),
        data: (sessions) {
          // Auto-select first session on first load
          if (_selectedSessionId == null && sessions.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedSessionId = sessions.first.id);
            });
          }

          return Column(
            children: [
              // ── Session selector bar ─────────────────────────────────────
              _SessionBar(
                sessions: sessions,
                selectedId: _selectedSessionId,
                canEdit: canEdit,
                onSessionChanged: (id) => setState(() {
                  _selectedSessionId = id;
                  _filter = null; // reset filter when switching session
                }),
                onRefresh: () {
                  ref.invalidate(activeSessionsProvider(customerId));
                  if (_selectedSessionId != null) {
                    ref.invalidate(sessionTasksProvider(_selectedSessionId!));
                  }
                },
                onSwitchView: () => context.go(AppRoutes.taskList),
                l10n: l10n,
              ),

              // ── Board ────────────────────────────────────────────────────
              Expanded(
                child: _selectedSessionId == null
                    ? _NoSessionView(
                        hasSessions: sessions.isNotEmpty, l10n: l10n)
                    : _BoardForSession(
                        sessionId: _selectedSessionId!,
                        isItExecutor: isItExecutor,
                        currentUserId: currentUserId,
                        filter: _filter,
                        onFilterChanged: (v) => setState(() => _filter = v),
                        l10n: l10n,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Session Selector Bar ───────────────────────────────────────────────────────

class _SessionBar extends StatelessWidget {
  final List<ActiveSession> sessions;
  final String? selectedId;
  final bool canEdit;
  final ValueChanged<String?> onSessionChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSwitchView;
  final AppLocalizations l10n;

  const _SessionBar({
    required this.sessions,
    required this.selectedId,
    required this.canEdit,
    required this.onSessionChanged,
    required this.onRefresh,
    required this.onSwitchView,
    required this.l10n,
  });

  ActiveSession? get _selected =>
      sessions.where((s) => s.id == selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(l10n.navMyTasks, style: AppTextStyles.h3),
          const Gap(16),

          // Session dropdown
          if (sessions.isNotEmpty)
            Expanded(
              child: _SessionDropdown(
                sessions: sessions,
                selectedId: selectedId,
                onChanged: onSessionChanged,
              ),
            )
          else
            Expanded(
              child: Text(
                '— no active sessions —',
                style: AppTextStyles.caption
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            ),

          const Gap(12),

          // ── New Task button — only visible to IT Executor ────────────────
          if (canEdit && _selected != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                textStyle: AppTextStyles.button,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.createTask),
              onPressed: () => _openCreateDialog(context, _selected!),
            ),

          const Gap(8),

          // ── Switch to List View ──────────────────────────────────────────
          Tooltip(
            message: 'Switch to List View',
            child: IconButton(
              icon: const Icon(Icons.view_list_outlined, size: 20),
              color: AppColors.blue,
              onPressed: onSwitchView,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.blue.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          const Gap(4),

          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 18),
            color: AppColors.muted,
            tooltip: 'Refresh',
            onPressed: onRefresh,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _openCreateDialog(BuildContext context, ActiveSession session) {
    showDialog<bool>(
      context: context,
      builder: (_) => _CreateTaskDialog(session: session, l10n: l10n),
    ).then((created) {
      if (created == true) onRefresh();
    });
  }
}

class _SessionDropdown extends StatelessWidget {
  final List<ActiveSession> sessions;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _SessionDropdown({
    required this.sessions,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
          style: AppTextStyles.body.copyWith(color: AppColors.text),
          hint: Text('Select a session…',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.muted)),
          items: sessions
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      s.workflowName,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Board for selected session ─────────────────────────────────────────────────

class _BoardForSession extends ConsumerWidget {
  final String sessionId;
  /// True only for it_executor — can create, edit, delete tasks.
  final bool isItExecutor;
  /// Logged-in user's UUID — used to gate status-change for non-executors.
  final String? currentUserId;
  final WorkflowTaskStatus? filter;
  final ValueChanged<WorkflowTaskStatus?> onFilterChanged;
  final AppLocalizations l10n;

  const _BoardForSession({
    required this.sessionId,
    required this.isItExecutor,
    required this.currentUserId,
    required this.filter,
    required this.onFilterChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(sessionTasksProvider(sessionId));

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(sessionTasksProvider(sessionId)),
      ),
      data: (tasks) {
        final visible = filter == null
            ? tasks
            : tasks.where((t) => t.status == filter).toList();

        final todo = visible
            .where((t) => t.status == WorkflowTaskStatus.todo)
            .toList();
        final inProg = visible
            .where((t) => t.status == WorkflowTaskStatus.inProgress)
            .toList();
        final pending = visible
            .where((t) => t.status == WorkflowTaskStatus.pendingReview)
            .toList();
        final done = visible
            .where((t) => t.status == WorkflowTaskStatus.approved)
            .toList();
        final overdue = visible
            .where((t) => t.status == WorkflowTaskStatus.overdue)
            .toList();

        final overdueTotal = tasks
            .where((t) => t.status == WorkflowTaskStatus.overdue)
            .length;

        return Column(
          children: [
            // Metric + filter bar
            _MetricBar(
              tasks: tasks,
              overdueTotal: overdueTotal,
              filter: filter,
              onFilterChanged: onFilterChanged,
              l10n: l10n,
            ),

            // Kanban
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: _KanbanBoard(
                  todo: todo,
                  inProgress: inProg,
                  pendingReview: pending,
                  done: done,
                  overdue: overdue,
                  l10n: l10n,
                  // it_executor  → full edit dialog on tap.
                  // client_admin → read-only detail sheet; status change only
                  //                if task is assigned to the current user.
                  // (employee is blocked from kanban by the router.)
                  onTaskTap: (task) async {
                    if (isItExecutor) {
                      final refreshed = await showDialog<bool>(
                        context: context,
                        builder: (_) =>
                            TaskEditDialog(task: task, l10n: l10n),
                      );
                      if (refreshed == true) {
                        ref.invalidate(sessionTasksProvider(sessionId));
                      }
                    } else {
                      // client_admin / employee: status change + evidence
                      // upload only when the task is assigned to them.
                      // Everyone can view tasks and evidence.
                      final canChange =
                          currentUserId != null &&
                          task.assignedToUserId == currentUserId;
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        builder: (_) => TaskDetailSheet(
                          task: task,
                          canChangeStatus: canChange,
                          onStatusChanged: () =>
                              ref.invalidate(sessionTasksProvider(sessionId)),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Metric + Filter Bar ────────────────────────────────────────────────────────

class _MetricBar extends StatelessWidget {
  final List<WorkflowTask> tasks;
  final int overdueTotal;
  final WorkflowTaskStatus? filter;
  final ValueChanged<WorkflowTaskStatus?> onFilterChanged;
  final AppLocalizations l10n;

  const _MetricBar({
    required this.tasks,
    required this.overdueTotal,
    required this.filter,
    required this.onFilterChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _MetricTile(
              label: l10n.taskAssigned,
              value: tasks.length,
              color: AppColors.blue,
              bgColor: AppColors.infoLight),
          const _VSep(),
          _MetricTile(
              label: l10n.taskInProgress,
              value: tasks
                  .where((t) => t.status == WorkflowTaskStatus.inProgress)
                  .length,
              color: AppColors.warning,
              bgColor: AppColors.warningLight),
          const _VSep(),
          _MetricTile(
              label: l10n.taskPendingReview,
              value: tasks
                  .where(
                      (t) => t.status == WorkflowTaskStatus.pendingReview)
                  .length,
              color: AppColors.orange,
              bgColor: AppColors.orangeLight),
          const _VSep(),
          _MetricTile(
              label: l10n.taskCompleted,
              value: tasks
                  .where((t) => t.status == WorkflowTaskStatus.approved)
                  .length,
              color: AppColors.success,
              bgColor: AppColors.successLight),
          const _VSep(),
          _MetricTile(
              label: l10n.taskOverdue,
              value: overdueTotal,
              color: AppColors.danger,
              bgColor: AppColors.dangerLight),

          const Gap(16),

          // Overdue badge
          if (overdueTotal > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.overdueWarning(overdueTotal),
                style: AppTextStyles.tag.copyWith(color: AppColors.danger),
              ),
            ),

          const Spacer(),

          // Status filter
          _FilterDropdown(
            current: filter,
            onChanged: onFilterChanged,
            l10n: l10n,
          ),
        ],
      ),
    );
  }
}

// ── Filter Dropdown ────────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final WorkflowTaskStatus? current;
  final ValueChanged<WorkflowTaskStatus?> onChanged;
  final AppLocalizations l10n;

  const _FilterDropdown({
    required this.current,
    required this.onChanged,
    required this.l10n,
  });

  String _label(WorkflowTaskStatus? s) => switch (s) {
        null => l10n.taskFilterAll,
        WorkflowTaskStatus.todo => l10n.taskToDo,
        WorkflowTaskStatus.inProgress => l10n.taskInProgress,
        WorkflowTaskStatus.pendingReview => l10n.taskPendingReview,
        WorkflowTaskStatus.approved => l10n.taskDone,
        WorkflowTaskStatus.overdue => l10n.taskOverdue,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WorkflowTaskStatus?>(
          value: current,
          isDense: true,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
          items: [
            DropdownMenuItem(
                value: null, child: Text('${l10n.taskFilterAll} ▼')),
            for (final s in WorkflowTaskStatus.values)
              DropdownMenuItem(value: s, child: Text(_label(s))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Shared metric widgets ──────────────────────────────────────────────────────

class _VSep extends StatelessWidget {
  const _VSep();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
}

class _MetricTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color bgColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(8)),
              child: Text('$value',
                  style: AppTextStyles.h3.copyWith(color: color)),
            ),
            const Gap(8),
            Flexible(
              child: Text(label,
                  style: AppTextStyles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Kanban Board ───────────────────────────────────────────────────────────────

class _KanbanBoard extends StatelessWidget {
  final List<WorkflowTask> todo;
  final List<WorkflowTask> inProgress;
  final List<WorkflowTask> pendingReview;
  final List<WorkflowTask> done;
  final List<WorkflowTask> overdue;
  final AppLocalizations l10n;
  final void Function(WorkflowTask)? onTaskTap;

  const _KanbanBoard({
    required this.todo,
    required this.inProgress,
    required this.pendingReview,
    required this.done,
    required this.overdue,
    required this.l10n,
    this.onTaskTap,
  });

  static const _colW = 252.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    const cols = 5;
    // Outer vertical scroll lets columns grow to their natural (tallest) height.
    // IntrinsicHeight makes every column the same height as the tallest one.
    // Inner horizontal scroll handles narrow viewports.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: SizedBox(
            width: _colW * cols + _gap * (cols - 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KanbanCol(
                  title: l10n.taskToDo,
                  tasks: todo,
                  headerColor: AppColors.muted,
                  headerBg: AppColors.surface,
                  l10n: l10n,
                  onTaskTap: onTaskTap,
                ),
                const Gap(_gap),
                _KanbanCol(
                  title: l10n.taskInProgress,
                  tasks: inProgress,
                  headerColor: AppColors.warning,
                  headerBg: AppColors.warningLight,
                  l10n: l10n,
                  onTaskTap: onTaskTap,
                ),
                const Gap(_gap),
                _KanbanCol(
                  title: l10n.taskPendingReview,
                  tasks: pendingReview,
                  headerColor: AppColors.orange,
                  headerBg: AppColors.orangeLight,
                  l10n: l10n,
                  onTaskTap: onTaskTap,
                ),
                const Gap(_gap),
                _KanbanCol(
                  title: l10n.taskDone,
                  tasks: done,
                  headerColor: AppColors.success,
                  headerBg: AppColors.successLight,
                  dimmed: true,
                  l10n: l10n,
                  onTaskTap: onTaskTap,
                ),
                const Gap(_gap),
                _KanbanCol(
                  title: l10n.taskOverdue,
                  tasks: overdue,
                  headerColor: AppColors.danger,
                  headerBg: AppColors.dangerLight,
                  l10n: l10n,
                  onTaskTap: onTaskTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Kanban Column ──────────────────────────────────────────────────────────────

class _KanbanCol extends StatelessWidget {
  final String title;
  final List<WorkflowTask> tasks;
  final Color headerColor;
  final Color headerBg;
  final bool dimmed;
  final AppLocalizations l10n;
  final void Function(WorkflowTask)? onTaskTap;

  const _KanbanCol({
    required this.title,
    required this.tasks,
    required this.headerColor,
    required this.headerBg,
    this.dimmed = false,
    required this.l10n,
    this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    // Single Container wraps header + cards so the background/border fills
    // the full column height (determined by IntrinsicHeight on the Row).
    // No Flexible/Expanded needed — vertical scroll handles overflow.
    return SizedBox(
      width: _KanbanBoard._colW,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: headerColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppTextStyles.label
                        .copyWith(color: headerColor, fontSize: 11),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: headerColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${tasks.length}',
                        style:
                            AppTextStyles.tag.copyWith(color: headerColor)),
                  ),
                ],
              ),
            ),

            // Cards — plain Column so every task is always visible.
            // IntrinsicHeight + outer vertical scroll handle equal height
            // and overflow respectively; no shrinkWrap/NeverScrollable needed.
            if (tasks.isEmpty)
              _EmptyCol(label: l10n.taskNoItems)
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (int i = 0; i < tasks.length; i++) ...[
                      _TaskCard(
                        task: tasks[i],
                        dimmed: dimmed,
                        l10n: l10n,
                        onTap: onTaskTap == null
                            ? null
                            : () => onTaskTap!(tasks[i]),
                      ),
                      if (i < tasks.length - 1) const Gap(6),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCol extends StatelessWidget {
  final String label;
  const _EmptyCol({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(fontStyle: FontStyle.italic)),
        ),
      );
}

// ── Task Card ──────────────────────────────────────────────────────────────────

class _TaskCard extends ConsumerStatefulWidget {
  final WorkflowTask task;
  final bool dimmed;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  const _TaskCard({
    required this.task,
    required this.dimmed,
    required this.l10n,
    this.onTap,
  });

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _hovered = false;

  Color get _accent => switch (widget.task.status) {
        WorkflowTaskStatus.todo => AppColors.muted,
        WorkflowTaskStatus.inProgress => AppColors.warning,
        WorkflowTaskStatus.pendingReview => AppColors.orange,
        WorkflowTaskStatus.approved => AppColors.success,
        WorkflowTaskStatus.overdue => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isOverdue = task.status == WorkflowTaskStatus.overdue;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE3EC)),
        ),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task name
                Text(
                  task.taskName.isEmpty ? '(no name)' : task.taskName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.whatToDo != null && task.whatToDo!.isNotEmpty) ...[
                  const Gap(4),
                  Text(
                    task.whatToDo!,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (task.risk != null && task.risk!.isNotEmpty) ...[
                  const Gap(4),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 11, color: AppColors.orange),
                      const Gap(3),
                      Expanded(
                        child: Text(
                          task.risk!,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.orange,
                              fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const Gap(8),
                // Due date row
                if (task.dueDate != null)
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 11,
                          color: isOverdue
                              ? AppColors.danger
                              : AppColors.muted),
                      const Gap(3),
                      Expanded(
                        child: Text(
                          '${widget.l10n.taskDueLabel} ${_fmtDate(task.dueDate!)}',
                          style: AppTextStyles.caption.copyWith(
                            color: isOverdue
                                ? AppColors.danger
                                : AppColors.muted,
                            fontWeight: isOverdue
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                // Assignee row
                if (task.assignedToUserName != null &&
                    task.assignedToUserName!.isNotEmpty) ...[
                  const Gap(4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 11, color: AppColors.muted),
                      const Gap(3),
                      Expanded(
                        child: Text(
                          task.assignedToUserName!,
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                // Footer: required badge + evidence count
                const Gap(6),
                Row(
                  children: [
                    if (task.isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.l10n.taskRequired,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.danger, fontSize: 9),
                        ),
                      ),
                    const Spacer(),
                    if (task.evidenceCount > 0) ...[
                      Icon(Icons.attach_file_rounded,
                          size: 11, color: AppColors.muted),
                      Text('${task.evidenceCount}',
                          style: AppTextStyles.caption),
                    ],
                    if (_hovered && widget.onTap != null)
                      Icon(Icons.edit_outlined,
                          size: 11,
                          color: _accent.withOpacity(0.7)),
                  ],
                ),

              ],
            ),
        ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}';
  }
}

// ── Create Task Dialog ─────────────────────────────────────────────────────────

class _CreateTaskDialog extends ConsumerStatefulWidget {
  final ActiveSession session;
  final AppLocalizations l10n;

  const _CreateTaskDialog({required this.session, required this.l10n});

  @override
  ConsumerState<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<_CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _whatCtrl = TextEditingController();
  final _fineCtrl = TextEditingController();

  int _statusId = 1; // To Do
  DateTime? _dueDate;
  bool _isRequired = false;
  bool _saving = false;
  String? _assignedToUserId;

  AppLocalizations get l10n => widget.l10n;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _whatCtrl.dispose();
    _fineCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final dio = ref.read(dioProvider);
      final fineText = _fineCtrl.text.trim();
      final fine = fineText.isNotEmpty ? double.tryParse(fineText) : null;

      await dio.post('/workflow-tasks', data: {
        'workflowId': widget.session.workflowId,
        'workflowAnswerId': widget.session.id,
        'taskName': _nameCtrl.text.trim(),
        if (_whatCtrl.text.trim().isNotEmpty) 'whatToDo': _whatCtrl.text.trim(),
        'statusId': _statusId,
        if (_dueDate != null)
          'dueDate':
              '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
        'isRequired': _isRequired,
        if (_assignedToUserId != null) 'assignedToUserId': _assignedToUserId,
        if (fine != null) 'estimatedFine': fine,
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  String _statusLabel(int id) => switch (id) {
        1 => l10n.taskToDo,
        2 => l10n.taskInProgress,
        3 => l10n.taskPendingReview,
        4 => l10n.taskDone,
        5 => l10n.taskOverdue,
        _ => l10n.taskToDo,
      };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_task_rounded,
                          color: AppColors.blue, size: 20),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.createTask, style: AppTextStyles.h3),
                          Text(
                            widget.session.workflowName,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(false),
                      color: AppColors.muted,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

                const Gap(24),
                const Divider(color: AppColors.border, height: 1),
                const Gap(20),

                // Task Name
                Text(l10n.taskNameLabel,
                    style: AppTextStyles.label),
                const Gap(6),
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: _inputDeco(
                      hint: l10n.taskNameLabel),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.required : null,
                ),

                const Gap(16),

                // What To Do
                Text(l10n.whatToDoLabel,
                    style: AppTextStyles.label),
                const Gap(6),
                TextFormField(
                  controller: _whatCtrl,
                  maxLines: 3,
                  decoration: _inputDeco(
                      hint: 'Describe the steps to complete this task…'),
                ),

                const Gap(16),

                // Status + Due Date (side by side)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.taskStatusLabel,
                              style: AppTextStyles.label),
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _statusId,
                                isExpanded: true,
                                isDense: true,
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.text),
                                items: [1, 2, 3]
                                    .map((id) => DropdownMenuItem(
                                          value: id,
                                          child: Text(_statusLabel(id)),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _statusId = v!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Gap(16),

                    // Due date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.dueDateLabel,
                              style: AppTextStyles.label),
                          const Gap(6),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                                color: AppColors.white,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 14, color: AppColors.muted),
                                  const Gap(8),
                                  Expanded(
                                    child: Text(
                                      _dueDate == null
                                          ? l10n.noDueDate
                                          : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                                      style: AppTextStyles.body.copyWith(
                                        color: _dueDate == null
                                            ? AppColors.muted
                                            : AppColors.text,
                                      ),
                                    ),
                                  ),
                                  if (_dueDate != null)
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _dueDate = null),
                                      child: const Icon(Icons.clear,
                                          size: 14,
                                          color: AppColors.muted),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Gap(16),

                // Is Required toggle
                Row(
                  children: [
                    Switch(
                      value: _isRequired,
                      onChanged: (v) => setState(() => _isRequired = v),
                      activeColor: AppColors.danger,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Gap(8),
                    Text(l10n.isRequiredLabel,
                        style: AppTextStyles.body),
                    if (_isRequired) ...[
                      const Gap(6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(l10n.taskRequired,
                            style: AppTextStyles.tag
                                .copyWith(color: AppColors.danger)),
                      ),
                    ],
                  ],
                ),

                const Gap(16),

                // Assignee + Estimated Fine (side by side)
                Builder(builder: (context) {
                  final customerId = ref
                          .watch(customerContextProvider)?['customerId']
                          as String? ??
                      '';
                  final usersAsync =
                      ref.watch(customerUsersProvider(customerId));

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Assignee dropdown
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.assignToLabel,
                                style: AppTextStyles.label),
                            const Gap(6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                                color: AppColors.white,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: usersAsync.when(
                                  loading: () => const SizedBox(
                                    height: 32,
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                  error: (_, __) => DropdownButton<
                                      String?>(
                                    value: null,
                                    isExpanded: true,
                                    isDense: true,
                                    items: [
                                      DropdownMenuItem(
                                          value: null,
                                          child: Text(l10n.unassigned,
                                              style: AppTextStyles.body
                                                  .copyWith(
                                                      color:
                                                          AppColors.muted))),
                                    ],
                                    onChanged: (_) {},
                                  ),
                                  data: (users) =>
                                      DropdownButton<String?>(
                                    value: _assignedToUserId,
                                    isExpanded: true,
                                    isDense: true,
                                    style: AppTextStyles.body
                                        .copyWith(color: AppColors.text),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          l10n.unassigned,
                                          style: AppTextStyles.body
                                              .copyWith(
                                                  color: AppColors.muted),
                                        ),
                                      ),
                                      ...users.map((u) =>
                                          DropdownMenuItem<String?>(
                                            value: u.userId,
                                            child: Text(
                                              u.displayName,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          )),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _assignedToUserId = v),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Gap(16),

                      // Estimated Fine
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.estimatedFineLabel,
                                style: AppTextStyles.label),
                            const Gap(6),
                            TextFormField(
                              controller: _fineCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              decoration: _inputDeco(hint: '0.00'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),

                const Gap(24),
                const Divider(color: AppColors.border, height: 1),
                const Gap(16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel,
                          style: AppTextStyles.button
                              .copyWith(color: AppColors.muted)),
                    ),
                    const Gap(8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        textStyle: AppTextStyles.button,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(l10n.save),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.white,
      );
}

// ── Empty / Error states ───────────────────────────────────────────────────────

class _NoSessionView extends StatelessWidget {
  final bool hasSessions;
  final AppLocalizations l10n;
  const _NoSessionView({required this.hasSessions, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSessions
                ? Icons.touch_app_outlined
                : Icons.assignment_outlined,
            size: 56,
            color: AppColors.border,
          ),
          const Gap(16),
          Text(
            hasSessions
                ? 'Select a workflow session above to view tasks'
                : 'No active workflow sessions found for this customer',
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const Gap(12),
          Text(message,
              style: AppTextStyles.body.copyWith(color: AppColors.muted)),
          const Gap(16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
