/// Task List Screen — flat list view of tasks for the selected session.
/// Permissions:
/// • it_executor  → sees ALL tasks; tapping opens full edit dialog.
/// • client_admin → sees ALL tasks; can change status only on assigned tasks.
/// • employee     → sees ALL tasks; can change status only on assigned tasks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_header.dart';
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
    final l10n = AppLocalizations.of(context);
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

    // it_executor & client_admin: can fully edit tasks.
    // employee: view-only; status change only on assigned tasks.
    final isItExecutor  = ctxRole == UserRole.itExecutor;
    final isClientAdmin = ctxRole == UserRole.clientAdmin;
    final isEmployee    = ctxRole == UserRole.employee;
    // Both it_executor and client_admin get full edit access
    final canEditTasks = isItExecutor || isClientAdmin;

    // Logged-in user ID — for task-assignment status-change check.
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: customerId == null
          ? Center(
              child: Text(l10n.noCustomerSelected,
                  style: const TextStyle(color: AppColors.muted)))
          : Column(
              children: [
                // ── Page Header ──────────────────────────────────────
                PageHeader(
                  title: l10n.myTasks,
                  variant: PageHeaderVariant.flat,
                  actions: [
                    // Refresh — always visible
                    IconButton(
                      icon: const Icon(Icons.refresh_outlined, size: 20),
                      color: AppColors.muted,
                      tooltip: l10n.retry,
                      onPressed: () {
                        ref.invalidate(_listSessionsProvider(customerId));
                        if (_selectedSessionId != null) {
                          ref.invalidate(
                              _sessionTasksListProvider(_selectedSessionId!));
                        }
                      },
                    ),
                    // Switch to Kanban — hidden for employee (router also blocks them)
                    if (!isEmployee)
                      Tooltip(
                        message: l10n.switchToKanban,
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
                  ],
                ),
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
                      hintText: l10n.searchTasksHint,
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
                      ? Center(
                          child: Text(l10n.selectSessionAbove,
                              style: const TextStyle(color: AppColors.muted)))
                      : _TaskListBody(
                          sessionId: _selectedSessionId!,
                          isItExecutor: canEditTasks,
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
    final l10n = AppLocalizations.of(context);
    final sessionsAsync = ref.watch(_listSessionsProvider(customerId));

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: sessionsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(l10n.failedToLoadSessions,
            style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Text(l10n.noActiveSessions,
                style: const TextStyle(color: AppColors.muted, fontSize: 13));
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
              Text(l10n.sessionLabel,
                  style: const TextStyle(
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
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (allTasks) {
        // Filter by search
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
          return EmptyState(
            icon: Icons.task_alt_rounded,
            title: search.isNotEmpty
                ? l10n.noTasksMatch(search)
                : l10n.noTasksForSession,
            description: search.isNotEmpty ? null : 'All caught up!',
          );
        }

        // Split into mine vs everyone else's
        final myTasks = currentUserId == null
            ? <WorkflowTask>[]
            : tasks
                .where((t) => t.assignedToUserId == currentUserId)
                .toList();
        final otherTasks = currentUserId == null
            ? tasks
            : tasks
                .where((t) => t.assignedToUserId != currentUserId)
                .toList();

        void refresh() => ref.invalidate(_sessionTasksListProvider(sessionId));

        SliverList _buildSliver(List<WorkflowTask> items, bool isMine) =>
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final task = items[i];
                  final canChangeStatus = isMine && currentUserId != null;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i < items.length - 1 ? 8 : 0,
                    ),
                    child: _TaskListTile(
                      task: task,
                      isItExecutor: isItExecutor,
                      canChangeStatus: canChangeStatus,
                      l10n: l10n,
                      onRefresh: refresh,
                    ).animate(delay: Duration(milliseconds: i * 40))
                        .fadeIn(duration: 200.ms)
                        .slideX(begin: -0.04, curve: Curves.easeOut),
                  );
                },
                childCount: items.length,
              ),
            );

        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: CustomScrollView(
            slivers: [
              // ── My Tasks panel ──────────────────────────────────
              if (myTasks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    icon: Icons.person_pin_outlined,
                    label: l10n.myTasks,
                    count: myTasks.length,
                    accent: AppColors.blue,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: _buildSliver(myTasks, true),
                ),
              ],

              // ── Other Tasks panel ───────────────────────────────
              if (otherTasks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    icon: Icons.group_outlined,
                    label: l10n.otherTasks,
                    count: otherTasks.length,
                    accent: AppColors.muted,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: _buildSliver(otherTasks, false),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section header (My Tasks / Other Tasks)
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color accent;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(8),
          Icon(icon, size: 15, color: accent),
          const Gap(6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.2,
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Task tile
// ─────────────────────────────────────────────────────────────

class _TaskListTile extends StatefulWidget {
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

  static Color _statusColor(WorkflowTaskStatus s) => switch (s) {
        WorkflowTaskStatus.todo          => AppColors.muted,
        WorkflowTaskStatus.inProgress    => AppColors.warning,
        WorkflowTaskStatus.pendingReview => AppColors.orange,
        WorkflowTaskStatus.approved      => AppColors.success,
        WorkflowTaskStatus.overdue       => AppColors.danger,
      };

  @override
  State<_TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<_TaskListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final status = widget.task.status;
    final accent = _TaskListTile._statusColor(status);
    final overdue = widget.task.dueDate != null &&
        widget.task.dueDate!.isBefore(DateTime.now()) &&
        status != WorkflowTaskStatus.approved;

    final body = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.task.taskName,
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
                  if (widget.task.assignedToUserName != null)
                    _Chip(
                      label: widget.task.assignedToUserName!,
                      color: AppColors.blue,
                      icon: Icons.person_outline,
                    ),
                  if (widget.task.dueDate != null)
                    _Chip(
                      label: DateFormat('dd MMM yyyy')
                          .format(widget.task.dueDate!),
                      color: overdue ? AppColors.danger : AppColors.muted,
                      icon: Icons.calendar_today_outlined,
                    ),
                  if (widget.task.estimatedFine != null)
                    _Chip(
                      label:
                          '₪${NumberFormat.compact().format(widget.task.estimatedFine)}',
                      color: AppColors.orange,
                      icon: Icons.account_balance_outlined,
                    ),
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.muted),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3 px accent stripe — status colour
              Container(width: 3, color: accent),
              // Card body
              Expanded(
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: () => _openDetail(context),
                    child: Padding(
                      padding: AppSpacing.listTilePadding,
                      child: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    if (widget.isItExecutor) {
      showDialog<bool>(
        context: context,
        builder: (_) => TaskEditDialog(task: widget.task, l10n: widget.l10n),
      ).then((refreshed) {
        if (refreshed == true) widget.onRefresh();
      });
    } else {
      showDialog<bool>(
        context: context,
        builder: (_) => TaskEditDialog(
          task: widget.task,
          l10n: widget.l10n,
          readOnly: true,
          canChangeStatus: widget.canChangeStatus,
          canUploadEvidence: widget.canChangeStatus,
          onStatusChanged: widget.onRefresh,
        ),
      ).then((refreshed) {
        if (refreshed == true) widget.onRefresh();
      });
    }
  }

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
