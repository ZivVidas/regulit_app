import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = Color(0xFF1B4D3E);
const _kGrad2 = Color(0xFF2E7D5C);
const _kRulePurple = Color(0xFF7C3AED);

// ── Question group (for option picker) ───────────────────────
class _QuestionGroup {
  final int questionNumber;
  final String questionText;
  final List<Map<String, dynamic>> options;
  const _QuestionGroup(this.questionNumber, this.questionText, this.options);
}

// ── State ─────────────────────────────────────────────────────
class _RuleEngineState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> signals;
  final List<Map<String, dynamic>> rules;
  final Map<String, String> optionLabels;
  final List<_QuestionGroup> optionGroups;

  const _RuleEngineState({
    this.isLoading = true,
    this.error,
    this.signals = const [],
    this.rules = const [],
    this.optionLabels = const {},
    this.optionGroups = const [],
  });

  _RuleEngineState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? signals,
    List<Map<String, dynamic>>? rules,
    Map<String, String>? optionLabels,
    List<_QuestionGroup>? optionGroups,
  }) =>
      _RuleEngineState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        signals: signals ?? this.signals,
        rules: rules ?? this.rules,
        optionLabels: optionLabels ?? this.optionLabels,
        optionGroups: optionGroups ?? this.optionGroups,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _RuleEngineNotifier extends StateNotifier<_RuleEngineState> {
  final Dio _dio;
  final String workflowId;

  _RuleEngineNotifier(this._dio, this.workflowId)
      : super(const _RuleEngineState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _dio.get<List<dynamic>>('/workflows/$workflowId/signals'),
        _dio.get<List<dynamic>>('/workflows/$workflowId/task-rules'),
        _dio.get<Map<String, dynamic>>(
            '/workflows/$workflowId/signals/option-labels'),
        _dio.get<List<dynamic>>(
            '/workflows/$workflowId/signals/option-groups'),
      ]);

      final optionLabels =
          (results[2].data as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));

      final groups = (results[3].data as List).map((g) {
        final gm = g as Map<String, dynamic>;
        return _QuestionGroup(
          gm['questionNumber'] as int,
          gm['questionText'] as String,
          (gm['options'] as List).cast<Map<String, dynamic>>(),
        );
      }).toList();

      state = state.copyWith(
        isLoading: false,
        signals: (results[0].data as List).cast<Map<String, dynamic>>(),
        rules: (results[1].data as List).cast<Map<String, dynamic>>(),
        optionLabels: optionLabels,
        optionGroups: groups,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteSignal(String id) async {
    try {
      await _dio.delete<dynamic>('/workflows/$workflowId/signals/$id');
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteRule(String id) async {
    try {
      await _dio.delete<dynamic>('/workflows/$workflowId/task-rules/$id');
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final _engineProvider = StateNotifierProvider.autoDispose
    .family<_RuleEngineNotifier, _RuleEngineState, String>(
  (ref, workflowId) =>
      _RuleEngineNotifier(ref.watch(dioProvider), workflowId),
);

// ── Screen ────────────────────────────────────────────────────
class WorkflowRuleEngineScreen extends ConsumerWidget {
  final String workflowId;
  final String workflowName;

  const WorkflowRuleEngineScreen({
    super.key,
    required this.workflowId,
    required this.workflowName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_engineProvider(workflowId));
    final dio = ref.read(dioProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _Header(
            workflowName: workflowName,
            onBack: () => context.pop(),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),
          Expanded(
            child: s.isLoading
                ? const Center(child: CircularProgressIndicator())
                : s.error != null
                    ? _ErrorView(
                        message: s.error!,
                        onRetry: () =>
                            ref.read(_engineProvider(workflowId).notifier).load(),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(_engineProvider(workflowId).notifier).load(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          children: [
                            // ── Signals section ─────────────────────────
                            _SectionHeader(
                              title: 'Signals',
                              subtitle: '${s.signals.length} defined',
                              icon: Icons.sensors_rounded,
                              color: _kGrad1,
                              onAdd: () => _showSignalDialog(
                                  context, dio, workflowId, s.optionLabels,
                                  s.optionGroups, null,
                                  onSaved: () => ref
                                      .read(_engineProvider(workflowId).notifier)
                                      .load()),
                            ),
                            const Gap(8),
                            ...s.signals.asMap().entries.map((e) => _SignalCard(
                                  signal: e.value,
                                  index: e.key,
                                  optionLabels: s.optionLabels,
                                  onEdit: () => _showSignalDialog(
                                      context, dio, workflowId, s.optionLabels,
                                      s.optionGroups, e.value,
                                      onSaved: () => ref
                                          .read(_engineProvider(workflowId).notifier)
                                          .load()),
                                  onDelete: () => _confirmDelete(
                                    context,
                                    'signal "${e.value['signalName']}"',
                                    () => ref
                                        .read(_engineProvider(workflowId).notifier)
                                        .deleteSignal(e.value['id'] as String),
                                  ),
                                )),
                            if (s.signals.isEmpty)
                              const _EmptyHint(
                                  message:
                                      'No signals yet. Add the first signal.'),
                            const Gap(24),

                            // ── Task Rules section ───────────────────────
                            _SectionHeader(
                              title: 'Task Rules',
                              subtitle:
                                  '${s.rules.length} rules · evaluated in priority order',
                              icon: Icons.task_alt_rounded,
                              color: _kRulePurple,
                              onAdd: () => _showRuleDialog(
                                  context, dio, workflowId, s.signals, null,
                                  onSaved: () => ref
                                      .read(_engineProvider(workflowId).notifier)
                                      .load()),
                            ),
                            const Gap(8),
                            ...s.rules.asMap().entries.map((e) => _RuleCard(
                                  rule: e.value,
                                  index: e.key,
                                  onEdit: () => _showRuleDialog(
                                      context, dio, workflowId, s.signals,
                                      e.value,
                                      onSaved: () => ref
                                          .read(_engineProvider(workflowId).notifier)
                                          .load()),
                                  onDelete: () => _confirmDelete(
                                    context,
                                    'task rule "${e.value['taskName']}"',
                                    () => ref
                                        .read(_engineProvider(workflowId).notifier)
                                        .deleteRule(e.value['id'] as String),
                                  ),
                                )),
                            if (s.rules.isEmpty)
                              const _EmptyHint(
                                  message:
                                      'No task rules yet. Add the first rule.'),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showSignalDialog(
    BuildContext context,
    Dio dio,
    String workflowId,
    Map<String, String> optionLabels,
    List<_QuestionGroup> optionGroups,
    Map<String, dynamic>? initial, {
    required VoidCallback onSaved,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SignalDialog(
        dio: dio,
        workflowId: workflowId,
        optionLabels: optionLabels,
        optionGroups: optionGroups,
        initial: initial,
        onSaved: onSaved,
      ),
    );
  }

  void _showRuleDialog(
    BuildContext context,
    Dio dio,
    String workflowId,
    List<Map<String, dynamic>> signals,
    Map<String, dynamic>? initial, {
    required VoidCallback onSaved,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RuleDialog(
        dio: dio,
        workflowId: workflowId,
        signals: signals,
        initial: initial,
        onSaved: onSaved,
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String label, Future<void> Function() onConfirm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm delete'),
        content: Text('Delete $label?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await onConfirm();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: Colors.white)),
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String workflowName;
  final VoidCallback onBack;

  const _Header({required this.workflowName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4C1D95), _kRulePurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x337C3AED), blurRadius: 20, offset: Offset(0, 6)),
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
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rule_folder_rounded,
                    color: Colors.white, size: 22),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Workflow Rule Engine',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        )),
                    Text(workflowName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onAdd;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: Icon(Icons.add_rounded, size: 16, color: color),
          label: Text('Add', style: TextStyle(color: color, fontSize: 13)),
          style: TextButton.styleFrom(
            backgroundColor: color.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

// ── Signal Card ───────────────────────────────────────────────
class _SignalCard extends StatelessWidget {
  final Map<String, dynamic> signal;
  final int index;
  final Map<String, String> optionLabels;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SignalCard({
    required this.signal,
    required this.index,
    required this.optionLabels,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final required =
        (signal['requiredOptionIds'] as List?)?.cast<String>() ?? [];
    final excluded =
        (signal['excludedOptionIds'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: _kGrad1.withOpacity(0.6), width: 3)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(signal['signalName'] as String? ?? '—',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  if ((signal['description'] as String?)?.isNotEmpty ??
                      false) ...[
                    const Gap(2),
                    Text(signal['description'] as String,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                  if (required.isNotEmpty) ...[
                    const Gap(6),
                    _OptionChips(
                        ids: required,
                        labels: optionLabels,
                        color: AppColors.success),
                  ],
                  if (excluded.isNotEmpty) ...[
                    const Gap(4),
                    _OptionChips(
                        ids: excluded,
                        labels: optionLabels,
                        color: AppColors.danger,
                        prefix: 'NOT '),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                _IconBtn(
                    icon: Icons.edit_outlined,
                    color: _kGrad2,
                    tooltip: 'Edit',
                    onTap: onEdit),
                const Gap(2),
                _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    tooltip: 'Delete',
                    onTap: onDelete),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
        duration: 300.ms,
        delay: (index * 40).ms,
        curve: Curves.easeOut);
  }
}

// ── Rule Card ─────────────────────────────────────────────────
class _RuleCard extends StatelessWidget {
  final Map<String, dynamic> rule;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleCard({
    required this.rule,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final priority = rule['priority'] as int? ?? 0;
    final taskName = rule['taskName'] as String? ?? '—';
    final whatToDo = rule['whatToDo'] as String?;
    final dueDays = rule['dueDays'] as int?;
    final isRequired = rule['isRequired'] as bool? ?? false;
    final estimatedFine = rule['estimatedFine'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left:
                BorderSide(color: _kRulePurple.withOpacity(0.7), width: 3)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority badge
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 12, top: 1),
              decoration: BoxDecoration(
                color: _kRulePurple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('#$priority',
                    style: const TextStyle(
                        color: _kRulePurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(taskName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  if (whatToDo != null && whatToDo.isNotEmpty) ...[
                    const Gap(2),
                    Text(whatToDo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                  const Gap(6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (isRequired)
                      _Chip(label: 'Required', color: AppColors.danger),
                    if (dueDays != null)
                      _Chip(
                          label: 'Due in $dueDays days',
                          color: const Color(0xFFD97706)),
                    if (estimatedFine != null)
                      _Chip(
                          label: '₪${estimatedFine.toStringAsFixed(0)}',
                          color: const Color(0xFF6B7280)),
                  ]),
                ],
              ),
            ),
            Column(
              children: [
                _IconBtn(
                    icon: Icons.edit_outlined,
                    color: _kRulePurple,
                    tooltip: 'Edit',
                    onTap: onEdit),
                const Gap(2),
                _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    tooltip: 'Delete',
                    onTap: onDelete),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
        duration: 300.ms,
        delay: (index * 40).ms,
        curve: Curves.easeOut);
  }
}

// ── Signal Dialog ─────────────────────────────────────────────
class _SignalDialog extends StatefulWidget {
  final Dio dio;
  final String workflowId;
  final Map<String, String> optionLabels;
  final List<_QuestionGroup> optionGroups;
  final Map<String, dynamic>? initial;
  final VoidCallback onSaved;

  const _SignalDialog({
    required this.dio,
    required this.workflowId,
    required this.optionLabels,
    required this.optionGroups,
    required this.initial,
    required this.onSaved,
  });

  @override
  State<_SignalDialog> createState() => _SignalDialogState();
}

class _SignalDialogState extends State<_SignalDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late Set<String> _required;
  late Set<String> _excluded;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl.text = init?['signalName'] as String? ?? '';
    _descCtrl.text = init?['description'] as String? ?? '';
    _required = Set<String>.from(
        (init?['requiredOptionIds'] as List?)?.cast<String>() ?? []);
    _excluded = Set<String>.from(
        (init?['excludedOptionIds'] as List?)?.cast<String>() ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Signal name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'signalName': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'requiredOptionIds': _required.toList(),
      'excludedOptionIds': _excluded.toList(),
    };
    try {
      if (_isEdit) {
        await widget.dio.put<dynamic>(
          '/workflows/${widget.workflowId}/signals/${widget.initial!['id']}',
          data: body,
        );
      } else {
        await widget.dio.post<dynamic>(
          '/workflows/${widget.workflowId}/signals',
          data: body,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kGrad1, _kGrad2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensors_rounded,
                      color: Colors.white, size: 20),
                  const Gap(10),
                  Expanded(
                    child: Text(_isEdit ? 'Edit Signal' : 'New Signal',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Signal Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const Gap(12),
                    TextField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const Gap(20),
                    // Option picker
                    _buildOptionPicker(
                      title: 'Required options (must be selected)',
                      color: AppColors.success,
                      selected: _required,
                      blocked: _excluded,
                      onToggle: (id, on) => setState(() =>
                          on ? _required.add(id) : _required.remove(id)),
                    ),
                    const Gap(16),
                    _buildOptionPicker(
                      title: 'Excluded options (must NOT be selected)',
                      color: AppColors.danger,
                      selected: _excluded,
                      blocked: _required,
                      onToggle: (id, on) => setState(() =>
                          on ? _excluded.add(id) : _excluded.remove(id)),
                    ),
                    if (_error != null) ...[
                      const Gap(12),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const Gap(8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: _kGrad1),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_isEdit ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionPicker({
    required String title,
    required Color color,
    required Set<String> selected,
    required Set<String> blocked,
    required void Function(String, bool) onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
        const Gap(8),
        if (widget.optionGroups.isEmpty)
          Text('No pick-type questions in this workflow.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))
        else
          ...widget.optionGroups.map((g) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Q${g.questionNumber}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                    const Gap(6),
                    Expanded(
                      child: Text(g.questionText,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: g.options.map((opt) {
                    final id = opt['id'] as String;
                    final label = opt['optionText'] as String;
                    final isSelected = selected.contains(id);
                    final isBlocked = blocked.contains(id);
                    return FilterChip(
                      label: Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : null)),
                      selected: isSelected,
                      onSelected: isBlocked ? null : (v) => onToggle(id, v),
                      backgroundColor: isBlocked
                          ? const Color(0xFFF3F4F6)
                          : null,
                      selectedColor: color,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                          color: isBlocked
                              ? const Color(0xFFE5E7EB)
                              : color.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
                const Gap(10),
              ],
            );
          }),
      ],
    );
  }
}

// ── Rule Dialog ───────────────────────────────────────────────
class _RuleDialog extends StatefulWidget {
  final Dio dio;
  final String workflowId;
  final List<Map<String, dynamic>> signals;
  final Map<String, dynamic>? initial;
  final VoidCallback onSaved;

  const _RuleDialog({
    required this.dio,
    required this.workflowId,
    required this.signals,
    required this.initial,
    required this.onSaved,
  });

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _priorityCtrl = TextEditingController();
  final _taskNameCtrl = TextEditingController();
  final _whatToDoCtrl = TextEditingController();
  final _dueDaysCtrl = TextEditingController();
  final _fineCtrl = TextEditingController();
  bool _isRequired = false;
  bool _saving = false;
  String? _error;

  // Condition builder state: top-level operator + list of term nodes
  String _topOperator = 'AND';
  // Each term is either a signal leaf {'signal': name} or a group
  // {'terms': [...], 'operator': 'AND'|'OR'}
  final List<_TermNode> _terms = [];

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _priorityCtrl.text = (init?['priority'] as int?)?.toString() ?? '';
    _taskNameCtrl.text = init?['taskName'] as String? ?? '';
    _whatToDoCtrl.text = init?['whatToDo'] as String? ?? '';
    _dueDaysCtrl.text = (init?['dueDays'] as int?)?.toString() ?? '';
    _fineCtrl.text = (init?['estimatedFine'] as num?)?.toString() ?? '';
    _isRequired = init?['isRequired'] as bool? ?? false;
    if (init != null) {
      final cond = init['condition'] as Map<String, dynamic>?;
      if (cond != null) {
        _topOperator = cond['operator'] as String? ?? 'AND';
        final rawTerms = cond['terms'] as List? ?? [];
        for (final t in rawTerms) {
          _terms.add(_TermNode.fromJson(t as Map<String, dynamic>));
        }
      }
    }
  }

  @override
  void dispose() {
    _priorityCtrl.dispose();
    _taskNameCtrl.dispose();
    _whatToDoCtrl.dispose();
    _dueDaysCtrl.dispose();
    _fineCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildCondition() {
    return {
      'operator': _topOperator,
      'terms': _terms.map((t) => t.toJson()).toList(),
    };
  }

  Future<void> _save() async {
    if (_priorityCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Priority is required');
      return;
    }
    if (_taskNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Task name is required');
      return;
    }
    if (_terms.isEmpty) {
      setState(() => _error = 'Add at least one condition term');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'priority': int.parse(_priorityCtrl.text.trim()),
      'taskName': _taskNameCtrl.text.trim(),
      'whatToDo': _whatToDoCtrl.text.trim().isEmpty
          ? null
          : _whatToDoCtrl.text.trim(),
      'condition': _buildCondition(),
      'dueDays': _dueDaysCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_dueDaysCtrl.text.trim()),
      'isRequired': _isRequired,
      'estimatedFine': _fineCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_fineCtrl.text.trim()),
    };
    try {
      if (_isEdit) {
        await widget.dio.put<dynamic>(
          '/workflows/${widget.workflowId}/task-rules/${widget.initial!['id']}',
          data: body,
        );
      } else {
        await widget.dio.post<dynamic>(
          '/workflows/${widget.workflowId}/task-rules',
          data: body,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF4C1D95), _kRulePurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.task_alt_rounded,
                      color: Colors.white, size: 20),
                  const Gap(10),
                  Expanded(
                    child: Text(_isEdit ? 'Edit Task Rule' : 'New Task Rule',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Task fields ───────────────────────────────
                    Row(children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _priorityCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Priority *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: TextField(
                          controller: _taskNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Task Name *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ]),
                    const Gap(12),
                    TextField(
                      controller: _whatToDoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'What To Do',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const Gap(12),
                    Row(children: [
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: _dueDaysCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Due (days)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const Gap(12),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _fineCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Est. Fine (₪)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Row(children: [
                        Checkbox(
                          value: _isRequired,
                          onChanged: (v) =>
                              setState(() => _isRequired = v ?? false),
                        ),
                        const Text('Required',
                            style: TextStyle(fontSize: 13)),
                      ]),
                    ]),
                    const Gap(20),
                    const Divider(),
                    const Gap(8),
                    // ── Condition builder ─────────────────────────
                    Row(
                      children: [
                        const Text('Condition',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        const Gap(12),
                        _OperatorToggle(
                          value: _topOperator,
                          onChanged: (v) =>
                              setState(() => _topOperator = v),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _terms.add(_TermNode.signal(''))),
                          icon: const Icon(Icons.add_rounded, size: 14),
                          label: const Text('Add Signal',
                              style: TextStyle(fontSize: 12)),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _terms.add(
                              _TermNode.group(
                                  [_TermNode.signal('')], 'OR'))),
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 14),
                          label: const Text('Add Group',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const Gap(8),
                    ..._terms.asMap().entries.map((e) => _buildTermRow(
                        e.key, e.value, null, _terms)),
                    if (_error != null) ...[
                      const Gap(12),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const Gap(8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: _kRulePurple),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_isEdit ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermRow(
      int idx, _TermNode node, _TermNode? parent, List<_TermNode> siblings) {
    if (node.isSignal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sensors_rounded,
                size: 14, color: Color(0xFF6B7280)),
            const Gap(8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: node.signal!.isEmpty ? null : node.signal,
                  hint: const Text('Select signal…',
                      style: TextStyle(fontSize: 12)),
                  isExpanded: true,
                  items: widget.signals
                      .map((s) => DropdownMenuItem<String>(
                            value: s['signalName'] as String,
                            child: Text(s['signalName'] as String,
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => node.signal = v ?? ''),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 14, color: Color(0xFF9CA3AF)),
              onPressed: () => setState(() => siblings.removeAt(idx)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    // Group node
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OperatorToggle(
                value: node.groupOperator!,
                onChanged: (v) =>
                    setState(() => node.groupOperator = v),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(
                    () => node.groupTerms!.add(_TermNode.signal(''))),
                icon: const Icon(Icons.add_rounded, size: 12),
                label: const Text('Add', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 14, color: Color(0xFF9CA3AF)),
                onPressed: () => setState(() => siblings.removeAt(idx)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Gap(4),
          ...node.groupTerms!.asMap().entries.map((e) =>
              _buildTermRow(e.key, e.value, node, node.groupTerms!)),
        ],
      ),
    );
  }
}

// ── Condition term node ───────────────────────────────────────
class _TermNode {
  String? signal; // non-null → leaf
  String? groupOperator; // non-null → group
  List<_TermNode>? groupTerms;

  bool get isSignal => signal != null;

  _TermNode.signal(this.signal);
  _TermNode.group(this.groupTerms, this.groupOperator);

  factory _TermNode.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('signal')) {
      return _TermNode.signal(j['signal'] as String);
    }
    final terms =
        (j['terms'] as List? ?? []).map((t) => _TermNode.fromJson(t as Map<String, dynamic>)).toList();
    return _TermNode.group(terms, j['operator'] as String? ?? 'OR');
  }

  Map<String, dynamic> toJson() {
    if (isSignal) return {'signal': signal ?? ''};
    return {
      'operator': groupOperator ?? 'OR',
      'terms': groupTerms!.map((t) => t.toJson()).toList(),
    };
  }
}

// ── Operator Toggle ───────────────────────────────────────────
class _OperatorToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _OperatorToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['AND', 'OR'].map((op) {
        final selected = value == op;
        return GestureDetector(
          onTap: () => onChanged(op),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: selected ? _kRulePurple : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(op,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF6B7280))),
          ),
        );
      }).toList(),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────
class _OptionChips extends StatelessWidget {
  final List<String> ids;
  final Map<String, String> labels;
  final Color color;
  final String prefix;

  const _OptionChips({
    required this.ids,
    required this.labels,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: ids.map((id) {
        final label = labels[id] ?? id.substring(0, 8);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text('$prefix$label',
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        );
      }).toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
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

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
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
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 40),
          const Gap(12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const Gap(16),
          FilledButton(
              onPressed: onRetry,
              child: const Text('Retry')),
        ],
      ),
    );
  }
}
