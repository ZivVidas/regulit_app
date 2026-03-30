import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../core/models/user.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = Color(0xFF1B4D3E);
const _kGrad2 = Color(0xFF2E7D5C);

// ── State ─────────────────────────────────────────────────────
class _WqState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? error;

  const _WqState({
    this.items = const [],
    this.isLoading = true,
    this.error,
  });

  _WqState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    String? error,
  }) =>
      _WqState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _WqNotifier extends StateNotifier<_WqState> {
  final Dio _dio;
  final String workflowId;

  _WqNotifier(this._dio, this.workflowId) : super(const _WqState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get<List<dynamic>>(
          '/workflows/$workflowId/quizzes');
      state = state.copyWith(
        isLoading: false,
        items: (res.data ?? []).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addQuiz(Map<String, dynamic> body) async {
    await _dio.post<dynamic>('/workflows/$workflowId/quizzes', data: body);
    await load();
  }

  Future<void> updateEntry(String entryId, Map<String, dynamic> body) async {
    await _dio.put<dynamic>(
        '/workflows/$workflowId/quizzes/$entryId', data: body);
    await load();
  }

  Future<void> removeEntry(String entryId) async {
    await _dio.delete<dynamic>('/workflows/$workflowId/quizzes/$entryId');
    await load();
  }
}

final _wqProviderFamily = StateNotifierProvider.autoDispose
    .family<_WqNotifier, _WqState, String>(
  (ref, workflowId) => _WqNotifier(ref.watch(dioProvider), workflowId),
);

// ── Screen ────────────────────────────────────────────────────
class WorkflowQuizzesScreen extends ConsumerWidget {
  final String workflowId;
  final String workflowName;

  const WorkflowQuizzesScreen({
    super.key,
    required this.workflowId,
    required this.workflowName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_wqProviderFamily(workflowId));
    final dio = ref.read(dioProvider);

    // Determine effective role: global role takes priority, else customer context role
    final user = ref.watch(currentUserProvider);
    final customerCtx = ref.watch(customerContextProvider);
    final effectiveRole = user?.role ??
        switch (customerCtx?['role'] as String?) {
          'client_admin' => UserRole.clientAdmin,
          'it_executor'  => UserRole.itExecutor,
          'employee'     => UserRole.employee,
          _              => null,
        };
    final canFill = effectiveRole == UserRole.clientAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────
          _Header(
            workflowName: workflowName,
            quizCount: s.isLoading ? null : s.items.length,
            onBack: () => context.pop(),
            onAdd: () => _showAddDialog(context, ref, dio),
            onFill: canFill ? () => _startFillSession(context, dio) : null,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),

          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: s.isLoading
                ? const _ShimmerList()
                : s.error != null
                    ? _ErrorView(
                        message: s.error!,
                        onRetry: () => ref
                            .read(_wqProviderFamily(workflowId).notifier)
                            .load(),
                      )
                    : s.items.isEmpty
                        ? _EmptyView(workflowName: workflowName)
                        : ReorderableListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: s.items.length,
                            onReorder: (oldIdx, newIdx) {
                              if (newIdx > oldIdx) newIdx--;
                              _onReorder(ref, s.items, oldIdx, newIdx);
                            },
                            itemBuilder: (_, i) {
                              final entry = s.items[i];
                              return _QuizEntryCard(
                                key: ValueKey(entry['id']),
                                entry: entry,
                                index: i,
                                onEdit: () => _showEditDialog(
                                    context, ref, dio, entry),
                                onRemove: () => _confirmRemove(
                                    context, ref,
                                    entry['id'] as String,
                                    entry['quizName'] as String? ?? ''),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _startFillSession(BuildContext context, Dio dio) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/workflow-answers',
        data: {'workflowId': workflowId},
      );
      final sessionId = res.data!['id'] as String;
      if (context.mounted) {
        context.push(
          Uri(
            path: '/workflow-answer/$sessionId',
            queryParameters: {'workflowName': workflowName},
          ).toString(),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error starting session: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, Dio dio) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddQuizDialog(
        dio: dio,
        existingQuizIds: ref
            .read(_wqProviderFamily(workflowId))
            .items
            .map((e) => e['quizId'] as String)
            .toSet(),
        nextOrder: ref.read(_wqProviderFamily(workflowId)).items.length,
        onAdd: (body) =>
            ref.read(_wqProviderFamily(workflowId).notifier).addQuiz(body),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Dio dio,
      Map<String, dynamic> entry) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditEntryDialog(
        entry: entry,
        onSave: (body) => ref
            .read(_wqProviderFamily(workflowId).notifier)
            .updateEntry(entry['id'] as String, body),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref,
      String entryId, String quizName) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove quiz'),
        content: Text('"$quizName" will be removed from this workflow.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref
            .read(_wqProviderFamily(workflowId).notifier)
            .removeEntry(entryId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.danger));
        }
      }
    }
  }

  void _onReorder(WidgetRef ref, List<Map<String, dynamic>> items,
      int oldIdx, int newIdx) {
    // Update order for the moved item immediately (fire & forget)
    final entry = items[oldIdx];
    ref
        .read(_wqProviderFamily(workflowId).notifier)
        .updateEntry(entry['id'] as String, {'order': newIdx});
  }
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String workflowName;
  final int? quizCount;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final VoidCallback? onFill; // null = user is not clientAdmin → button hidden

  const _Header({
    required this.workflowName,
    required this.quizCount,
    required this.onBack,
    required this.onAdd,
    required this.onFill,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = quizCount == null
        ? 'Loading…'
        : '$quizCount quiz${quizCount == 1 ? '' : 'zes'} in this workflow';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad1, _kGrad2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x331B4D3E), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                tooltip: 'Back to Workflows',
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_tree_rounded,
                    color: Colors.white, size: 22),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workflowName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12)),
                  ],
                ),
              ),
              // Fill workflow button — only shown for clientAdmin
              if (onFill != null) ...[
                _FillButton(onTap: onFill!),
                const Gap(8),
              ],
              _AddButton(onTap: onAdd),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fill Button ───────────────────────────────────────────────
class _FillButton extends StatefulWidget {
  final VoidCallback onTap;
  const _FillButton({required this.onTap});

  @override
  State<_FillButton> createState() => _FillButtonState();
}

class _FillButtonState extends State<_FillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.quiz_rounded, size: 15, color: Colors.white),
            const Gap(6),
            const Text('Fill',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ── Add Button ────────────────────────────────────────────────
class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, size: 16, color: _kGrad1),
            const Gap(6),
            const Text('Add Quiz',
                style: TextStyle(
                    color: _kGrad1,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ── Quiz Entry Card ───────────────────────────────────────────
class _QuizEntryCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _QuizEntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  State<_QuizEntryCard> createState() => _QuizEntryCardState();
}

class _QuizEntryCardState extends State<_QuizEntryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final order = e['order'] as int? ?? widget.index;
    final hasCondition =
        (e['conditionToShowQuiz'] as String?)?.isNotEmpty ?? false;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: _kGrad2, width: 4)),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? _kGrad2.withOpacity(0.14)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _hovered ? 20 : 6,
              offset: Offset(0, _hovered ? 6 : 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Icon(Icons.drag_handle_rounded,
                    color: Colors.grey[300], size: 20),
              ),

              // Order badge
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(top: 1, right: 10),
                decoration: BoxDecoration(
                  color: _kGrad2.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${order + 1}',
                    style: const TextStyle(
                      color: _kGrad2,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e['quizName'] as String? ?? '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if ((e['quizDescription'] as String?)?.isNotEmpty ??
                        false) ...[
                      const Gap(2),
                      Text(
                        e['quizDescription'] as String,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                    if ((e['quizResult'] as String?)?.isNotEmpty ?? false) ...[
                      const Gap(4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.fact_check_outlined,
                              size: 11, color: Color(0xFF2563EB)),
                          const Gap(3),
                          Flexible(
                            child: Text(
                              e['quizResult'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2563EB),
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((e['quizAlgorithmResult'] as String?)?.isNotEmpty ??
                        false) ...[
                      const Gap(4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.smart_toy_outlined,
                              size: 11, color: Color(0xFF7C3AED)),
                          const Gap(3),
                          Flexible(
                            child: Text(
                              e['quizAlgorithmResult'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7C3AED),
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hasCondition) ...[
                      const Gap(4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.rule_rounded,
                                size: 10, color: Color(0xFFD97706)),
                            const Gap(3),
                            Flexible(
                              child: Text(
                                'Condition: ${e['conditionToShowQuiz']}',
                                style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    color: _kGrad2,
                    tooltip: 'Edit Order / Condition',
                    onTap: widget.onEdit,
                  ),
                  const Gap(2),
                  _ActionIcon(
                    icon: Icons.remove_circle_outline_rounded,
                    color: AppColors.danger,
                    tooltip: 'Remove',
                    onTap: widget.onRemove,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action Icon ───────────────────────────────────────────────
class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIcon(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hov
                  ? widget.color.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon,
                size: 16,
                color: _hov ? widget.color : Colors.grey[400]),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────────
class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ── Empty View ────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String workflowName;
  const _EmptyView({required this.workflowName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kGrad1.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.playlist_add_check_rounded,
              size: 48, color: _kGrad1.withOpacity(0.5)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.06, 1.06),
                duration: 1800.ms,
                curve: Curves.easeInOut),
        const Gap(20),
        Text(
          'No quizzes in "$workflowName" yet.\nTap "Add Quiz" to get started.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ]),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(
            begin: const Offset(0.85, 0.85),
            duration: 400.ms,
            curve: Curves.easeOutBack);
  }
}

// ── Error View ────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: AppColors.dangerLight, shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded,
              size: 40, color: AppColors.danger),
        ),
        const Gap(16),
        Text(message,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
            textAlign: TextAlign.center),
        const Gap(20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

// ── Add Quiz Dialog ───────────────────────────────────────────
// Fetches all active quizzes and lets the user pick one.
class _AddQuizDialog extends StatefulWidget {
  final Dio dio;
  final Set<String> existingQuizIds;
  final int nextOrder;
  final Future<void> Function(Map<String, dynamic>) onAdd;

  const _AddQuizDialog({
    required this.dio,
    required this.existingQuizIds,
    required this.nextOrder,
    required this.onAdd,
  });

  @override
  State<_AddQuizDialog> createState() => _AddQuizDialogState();
}

class _AddQuizDialogState extends State<_AddQuizDialog> {
  List<Map<String, dynamic>> _quizzes = [];
  bool _loadingQuizzes = true;
  String? _selectedQuizId;
  late final TextEditingController _orderCtrl;
  late final TextEditingController _condCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orderCtrl = TextEditingController(text: widget.nextOrder.toString());
    _condCtrl = TextEditingController();
    _fetchQuizzes();
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _condCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchQuizzes() async {
    try {
      final res = await widget.dio.get<Map<String, dynamic>>(
        '/quizzes',
        queryParameters: {'page_size': 200, 'page': 1},
      );
      final all = (res.data!['items'] as List).cast<Map<String, dynamic>>();
      // Filter out already-added quizzes
      setState(() {
        _quizzes = all
            .where((q) =>
                (q['isActive'] as bool? ?? true) &&
                !widget.existingQuizIds.contains(q['id'] as String))
            .toList();
        _loadingQuizzes = false;
        if (_quizzes.isNotEmpty) _selectedQuizId = _quizzes.first['id'] as String;
      });
    } catch (e) {
      setState(() {
        _loadingQuizzes = false;
        _error = 'Failed to load quizzes: $e';
      });
    }
  }

  Future<void> _save() async {
    if (_selectedQuizId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAdd({
        'quizId': _selectedQuizId,
        'order': int.tryParse(_orderCtrl.text.trim()) ?? widget.nextOrder,
        'conditionToShowQuiz': _condCtrl.text.trim().isEmpty
            ? null
            : _condCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_kGrad1, _kGrad2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: const Row(children: [
                  Icon(Icons.playlist_add_rounded, color: Colors.white, size: 20),
                  Gap(10),
                  Text('Add Quiz to Workflow',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ]),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.danger)),
                      )
                          .animate()
                          .shake(duration: 400.ms)
                          .fadeIn(duration: 200.ms),
                      const Gap(12),
                    ],

                    // Quiz picker
                    Text('Select Quiz', style: AppTextStyles.label),
                    const Gap(4),
                    if (_loadingQuizzes)
                      const LinearProgressIndicator()
                    else if (_quizzes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No available quizzes to add.',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedQuizId,
                        decoration: const InputDecoration(isDense: true),
                        items: _quizzes
                            .map((q) => DropdownMenuItem(
                                  value: q['id'] as String,
                                  child: Text(q['name'] as String? ?? '—',
                                      style: AppTextStyles.body),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedQuizId = v),
                      ),
                    const Gap(12),

                    // Order
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Display Order', style: AppTextStyles.label),
                        const Gap(4),
                        TextFormField(
                          controller: _orderCtrl,
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                              isDense: true,
                              hintText: '0, 1, 2…'),
                        ),
                      ],
                    ),
                    const Gap(12),

                    // Condition
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Condition to Show Quiz (optional)',
                            style: AppTextStyles.label),
                        const Gap(4),
                        TextFormField(
                          controller: _condCtrl,
                          maxLines: 3,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText:
                                'e.g. "previous_quiz.answer == \'yes\'"',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Gap(8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGrad1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: (_saving ||
                              _loadingQuizzes ||
                              _quizzes.isEmpty ||
                              _selectedQuizId == null)
                          ? null
                          : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Add Quiz'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
        begin: const Offset(0.93, 0.93),
        duration: 250.ms,
        curve: Curves.easeOutBack);
  }
}

// ── Edit Entry Dialog ─────────────────────────────────────────
// Edit order and condition for an existing workflow-quiz entry.
class _EditEntryDialog extends StatefulWidget {
  final Map<String, dynamic> entry;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _EditEntryDialog({required this.entry, required this.onSave});

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late final TextEditingController _orderCtrl;
  late final TextEditingController _condCtrl;
  late final TextEditingController _resultCtrl;
  late final TextEditingController _algoResultCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orderCtrl = TextEditingController(
        text: (widget.entry['order'] as int? ?? 0).toString());
    _condCtrl = TextEditingController(
        text: widget.entry['conditionToShowQuiz'] as String? ?? '');
    _resultCtrl = TextEditingController(
        text: widget.entry['quizResult'] as String? ?? '');
    _algoResultCtrl = TextEditingController(
        text: widget.entry['quizAlgorithmResult'] as String? ?? '');
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _condCtrl.dispose();
    _resultCtrl.dispose();
    _algoResultCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'order': int.tryParse(_orderCtrl.text.trim()) ?? 0,
        'conditionToShowQuiz': _condCtrl.text.trim().isEmpty
            ? null
            : _condCtrl.text.trim(),
        'quizResult': _resultCtrl.text.trim().isEmpty
            ? null
            : _resultCtrl.text.trim(),
        'quizAlgorithmResult': _algoResultCtrl.text.trim().isEmpty
            ? null
            : _algoResultCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizName = widget.entry['quizName'] as String? ?? '';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_kGrad1, _kGrad2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: Row(children: [
                  const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                  const Gap(10),
                  Expanded(
                    child: Text(quizName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.danger)),
                      ).animate().shake(duration: 400.ms).fadeIn(duration: 200.ms),
                      const Gap(12),
                    ],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Display Order', style: AppTextStyles.label),
                        const Gap(4),
                        TextFormField(
                          controller: _orderCtrl,
                          keyboardType: TextInputType.number,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ],
                    ),
                    const Gap(12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Condition to Show Quiz (optional)',
                            style: AppTextStyles.label),
                        const Gap(4),
                        TextFormField(
                          controller: _condCtrl,
                          maxLines: 3,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'e.g. "previous.answer == \'yes\'"'),
                        ),
                      ],
                    ),
                    const Gap(12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.fact_check_outlined,
                              size: 13, color: Color(0xFF2563EB)),
                          const Gap(4),
                          Text('Quiz Result (optional)',
                              style: AppTextStyles.label),
                        ]),
                        const Gap(4),
                        TextFormField(
                          controller: _resultCtrl,
                          maxLines: 6,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Expected result or outcome…',
                          ),
                        ),
                      ],
                    ),
                    const Gap(12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.smart_toy_outlined,
                              size: 13, color: Color(0xFF7C3AED)),
                          const Gap(4),
                          Text('Algorithm Result (optional)',
                              style: AppTextStyles.label),
                        ]),
                        const Gap(4),
                        TextFormField(
                          controller: _algoResultCtrl,
                          maxLines: 6,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Algorithm / AI result logic…',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Gap(8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGrad1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
        begin: const Offset(0.93, 0.93),
        duration: 250.ms,
        curve: Curves.easeOutBack);
  }
}
