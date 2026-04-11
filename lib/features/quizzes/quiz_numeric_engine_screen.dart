import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = Color(0xFF059669); // emerald
const _kGrad2 = Color(0xFF047857);

// ── Step-type info ────────────────────────────────────────────
const _stepTypes = [
  'set_base',
  'add',
  'multiply',
  'discount_pct',
  'cap_pct',
];

String _stepTypeLabel(String t) => switch (t) {
      'set_base'     => 'Set Base',
      'add'          => 'Add',
      'multiply'     => 'Multiply',
      'discount_pct' => 'Discount %',
      'cap_pct'      => 'Cap %',
      _              => t,
    };

Color _stepTypeColor(String t) => switch (t) {
      'set_base'     => const Color(0xFF2563EB),
      'add'          => const Color(0xFF059669),
      'multiply'     => const Color(0xFF7C3AED),
      'discount_pct' => const Color(0xFFD97706),
      'cap_pct'      => const Color(0xFFDC2626),
      _              => AppColors.muted,
    };

// ── State ─────────────────────────────────────────────────────
class _NumericState {
  final List<Map<String, dynamic>> steps;
  final List<Map<String, dynamic>> signals;
  final bool isLoading;
  final String? error;

  const _NumericState({
    this.steps = const [],
    this.signals = const [],
    this.isLoading = true,
    this.error,
  });

  _NumericState copyWith({
    List<Map<String, dynamic>>? steps,
    List<Map<String, dynamic>>? signals,
    bool? isLoading,
    String? error,
  }) =>
      _NumericState(
        steps: steps ?? this.steps,
        signals: signals ?? this.signals,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _NumericNotifier extends StateNotifier<_NumericState> {
  final Dio _dio;
  final String quizId;

  _NumericNotifier(this._dio, this.quizId) : super(const _NumericState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _dio.get<List<dynamic>>('/quizzes/$quizId/numeric-steps'),
        _dio.get<List<dynamic>>('/quizzes/$quizId/signals'),
      ]);
      state = state.copyWith(
        isLoading: false,
        steps: (results[0].data as List).cast<Map<String, dynamic>>(),
        signals: (results[1].data as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createStep(Map<String, dynamic> body) async {
    await _dio.post<dynamic>('/quizzes/$quizId/numeric-steps', data: body);
    await load();
  }

  Future<void> updateStep(String stepId, Map<String, dynamic> body) async {
    await _dio.put<dynamic>('/quizzes/$quizId/numeric-steps/$stepId', data: body);
    await load();
  }

  Future<void> deleteStep(String stepId) async {
    try {
      await _dio.delete<dynamic>('/quizzes/$quizId/numeric-steps/$stepId');
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> createRule(String stepId, Map<String, dynamic> body) async {
    await _dio.post<dynamic>(
        '/quizzes/$quizId/numeric-steps/$stepId/rules', data: body);
    await load();
  }

  Future<void> updateRule(
      String stepId, String ruleId, Map<String, dynamic> body) async {
    await _dio.put<dynamic>(
        '/quizzes/$quizId/numeric-steps/$stepId/rules/$ruleId', data: body);
    await load();
  }

  Future<void> deleteRule(String stepId, String ruleId) async {
    try {
      await _dio.delete<dynamic>(
          '/quizzes/$quizId/numeric-steps/$stepId/rules/$ruleId');
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final _numericProvider = StateNotifierProvider.autoDispose
    .family<_NumericNotifier, _NumericState, String>(
  (ref, quizId) => _NumericNotifier(ref.watch(dioProvider), quizId),
);

// ── Screen ────────────────────────────────────────────────────
class QuizNumericEngineScreen extends ConsumerWidget {
  final String quizId;
  final String quizName;

  const QuizNumericEngineScreen({
    super.key,
    required this.quizId,
    required this.quizName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_numericProvider(quizId));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _Header(
            quizName: quizName,
            onBack: () => context.pop(),
            onAdd: () => _showStepDialog(context, ref, null),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),
          if (s.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (s.error != null)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(s.error!,
                      style: const TextStyle(color: AppColors.danger)),
                  const Gap(12),
                  FilledButton(
                    onPressed: () =>
                        ref.read(_numericProvider(quizId).notifier).load(),
                    child: const Text('Retry'),
                  ),
                ]),
              ),
            )
          else
            Expanded(
              child: s.steps.isEmpty
                  ? _EmptyView(
                      onAdd: () => _showStepDialog(context, ref, null))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: s.steps.length,
                      itemBuilder: (_, i) {
                        final step = s.steps[i];
                        return _StepCard(
                          key: ValueKey(step['id']),
                          step: step,
                          index: i,
                          signals: s.signals,
                          onEdit: () => _showStepDialog(context, ref, step),
                          onDelete: () => _confirmDeleteStep(
                              context, ref, step['id'] as String,
                              step['stepName'] as String? ?? ''),
                          onAddRule: () =>
                              _showRuleDialog(context, ref, step, s.signals, null),
                          onEditRule: (rule) =>
                              _showRuleDialog(context, ref, step, s.signals, rule),
                          onDeleteRule: (rule) => _confirmDeleteRule(
                              context, ref,
                              step['id'] as String,
                              rule['id'] as String,
                              rule['label'] as String? ?? ''),
                        ).animate().fadeIn(
                              duration: 350.ms,
                              delay: (i * 50).ms,
                              curve: Curves.easeOut,
                            );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  void _showStepDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? step) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StepDialog(
        initialStep: step,
        onSave: (body) async {
          final n = ref.read(_numericProvider(quizId).notifier);
          if (step == null) {
            await n.createStep(body);
          } else {
            await n.updateStep(step['id'] as String, body);
          }
        },
      ),
    );
  }

  void _showRuleDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> step,
    List<Map<String, dynamic>> signals,
    Map<String, dynamic>? rule,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RuleDialog(
        stepId: step['id'] as String,
        stepType: step['stepType'] as String? ?? 'add',
        signals: signals,
        initialRule: rule,
        onSave: (body) async {
          final n = ref.read(_numericProvider(quizId).notifier);
          final stepId = step['id'] as String;
          if (rule == null) {
            await n.createRule(stepId, body);
          } else {
            await n.updateRule(stepId, rule['id'] as String, body);
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteStep(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete step'),
        content: Text('"$name" and all its rules will be deleted. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(_numericProvider(quizId).notifier).deleteStep(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    }
  }

  Future<void> _confirmDeleteRule(
    BuildContext context,
    WidgetRef ref,
    String stepId,
    String ruleId,
    String label,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete rule'),
        content: Text('"$label" will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref
            .read(_numericProvider(quizId).notifier)
            .deleteRule(stepId, ruleId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    }
  }
}

// ── Gradient Header ───────────────────────────────────────────
class _Header extends StatelessWidget {
  final String quizName;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  const _Header(
      {required this.quizName, required this.onBack, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad1, _kGrad2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x331A3C6B),
              blurRadius: 20,
              offset: Offset(0, 6))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
          child: Row(children: [
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
              child: const Icon(Icons.calculate_rounded,
                  color: Colors.white, size: 22),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quizName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Text('Numeric Engine',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            _AddBtn(onTap: onAdd),
          ]),
        ),
      ),
    );
  }
}

class _AddBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _AddBtn({required this.onTap});

  @override
  State<_AddBtn> createState() => _AddBtnState();
}

class _AddBtnState extends State<_AddBtn> {
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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, size: 16, color: _kGrad1),
            const Gap(6),
            const Text('Add Step',
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

// ── Step Card (expandable) ────────────────────────────────────
class _StepCard extends StatefulWidget {
  final Map<String, dynamic> step;
  final int index;
  final List<Map<String, dynamic>> signals;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddRule;
  final void Function(Map<String, dynamic>) onEditRule;
  final void Function(Map<String, dynamic>) onDeleteRule;

  const _StepCard({
    super.key,
    required this.step,
    required this.index,
    required this.signals,
    required this.onEdit,
    required this.onDelete,
    required this.onAddRule,
    required this.onEditRule,
    required this.onDeleteRule,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final stepType = step['stepType'] as String? ?? '';
    final rules =
        (step['rules'] as List? ?? []).cast<Map<String, dynamic>>();
    final color = _stepTypeColor(stepType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // ── Step header ──────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                // Step order badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${step['stepOrder'] ?? widget.index + 1}',
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['stepName'] as String? ?? '—',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827)),
                      ),
                      const Gap(2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _stepTypeLabel(stepType),
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                // Add rule
                _ActionIcon(
                  icon: Icons.add_rounded,
                  color: _kGrad1,
                  tooltip: 'Add Rule',
                  onTap: widget.onAddRule,
                ),
                _ActionIcon(
                  icon: Icons.edit_outlined,
                  color: _kGrad2,
                  tooltip: 'Edit Step',
                  onTap: widget.onEdit,
                ),
                _ActionIcon(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  tooltip: 'Delete Step',
                  onTap: widget.onDelete,
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ]),
            ),
          ),
          // ── Rules list ───────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            if (rules.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No rules yet — tap + to add.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              )
            else
              ...rules.asMap().entries.map((e) {
                final rule = e.value;
                return _RuleRow(
                  rule: rule,
                  index: e.key,
                  stepType: stepType,
                  onEdit: () => widget.onEditRule(rule),
                  onDelete: () => widget.onDeleteRule(rule),
                );
              }),
            const Gap(4),
          ],
        ],
      ),
    );
  }
}

// ── Rule Row ──────────────────────────────────────────────────
class _RuleRow extends StatelessWidget {
  final Map<String, dynamic> rule;
  final int index;
  final String stepType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleRow({
    required this.rule,
    required this.index,
    required this.stepType,
    required this.onEdit,
    required this.onDelete,
  });

  String _conditionSummary(dynamic condition) {
    if (condition == null) return '?';
    final c = condition as Map<String, dynamic>;
    if (c.containsKey('always')) return 'Always';
    if (c.containsKey('signal')) return '${c['signal']}';
    if (c.containsKey('not')) return 'NOT (${_conditionSummary(c['not'])})';
    final op = c['operator'] as String? ?? 'AND';
    final terms = (c['terms'] as List? ?? []);
    if (terms.isEmpty) return op;
    return terms.map((t) => _conditionSummary(t)).join(' $op ');
  }

  String _valueLabel(double value) {
    return switch (stepType) {
      'discount_pct' => '-${value.toStringAsFixed(1)}%',
      'cap_pct'      => 'cap ${value.toStringAsFixed(1)}%',
      'multiply'     => '× ${value.toStringAsFixed(2)}',
      _              => '+${value.toStringAsFixed(2)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final value = (rule['value'] as num?)?.toDouble() ?? 0.0;
    final color = _stepTypeColor(stepType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(children: [
        // Order badge
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '${(rule['ruleOrder'] as int? ?? index + 1)}',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rule['label'] as String? ?? '—',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827)),
              ),
              Text(
                _conditionSummary(rule['condition']),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Gap(8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _valueLabel(value),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const Gap(4),
        _ActionIcon(
            icon: Icons.edit_outlined,
            color: _kGrad2,
            tooltip: 'Edit',
            onTap: onEdit),
        _ActionIcon(
            icon: Icons.delete_outline_rounded,
            color: AppColors.danger,
            tooltip: 'Delete',
            onTap: onDelete),
      ]),
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
            padding: const EdgeInsets.all(7),
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

// ── Empty View ────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kGrad1.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.calculate_outlined,
              size: 48, color: _kGrad1.withOpacity(0.5)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.06, 1.06),
              duration: 1800.ms,
              curve: Curves.easeInOut,
            ),
        const Gap(20),
        const Text(
          'No numeric steps yet.\nAdd the first accumulator step.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const Gap(16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _kGrad1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Step'),
        ),
      ]),
    );
  }
}

// ── Step Dialog ───────────────────────────────────────────────
class _StepDialog extends StatefulWidget {
  final Map<String, dynamic>? initialStep;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _StepDialog({this.initialStep, required this.onSave});

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _orderCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _selectedType;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialStep != null;

  @override
  void initState() {
    super.initState();
    final s = widget.initialStep;
    _orderCtrl = TextEditingController(
        text: s?['stepOrder']?.toString() ?? '');
    _nameCtrl =
        TextEditingController(text: s?['stepName'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: s?['description'] as String? ?? '');
    _selectedType = s?['stepType'] as String? ?? 'add';
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'stepOrder': int.parse(_orderCtrl.text.trim()),
      'stepName': _nameCtrl.text.trim(),
      'stepType': _selectedType,
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
    };
    try {
      await widget.onSave(body);
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
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                const Icon(Icons.calculate_rounded,
                    color: Colors.white, size: 20),
                const Gap(10),
                Text(
                  _isEdit ? 'Edit Step' : 'New Accumulator Step',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ]),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13)),
                        ),
                        const Gap(12),
                      ],
                      Row(children: [
                        SizedBox(
                          width: 80,
                          child: _Field(
                              label: 'Order',
                              ctrl: _orderCtrl,
                              required: true,
                              numeric: true),
                        ),
                        const Gap(12),
                        Expanded(
                            child: _Field(
                                label: 'Step Name',
                                ctrl: _nameCtrl,
                                required: true)),
                      ]),
                      const Gap(12),
                      // Type selector
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Step Type', style: AppTextStyles.label),
                          const Gap(4),
                          DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration:
                                const InputDecoration(isDense: true),
                            items: _stepTypes
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Row(children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                              color: _stepTypeColor(t),
                                              shape: BoxShape.circle),
                                        ),
                                        const Gap(8),
                                        Text(_stepTypeLabel(t)),
                                      ]),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedType = v!),
                          ),
                        ],
                      ),
                      const Gap(12),
                      _Field(
                          label: 'Description (optional)',
                          ctrl: _descCtrl,
                          maxLines: 2),
                    ]),
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
                        child: const Text('Cancel')),
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
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Text(_isEdit ? 'Save Changes' : 'Add Step'),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
        begin: const Offset(0.93, 0.93),
        duration: 250.ms,
        curve: Curves.easeOutBack);
  }
}

// ── Rule Dialog ───────────────────────────────────────────────
class _RuleDialog extends StatefulWidget {
  final String stepId;
  final String stepType;
  final List<Map<String, dynamic>> signals;
  final Map<String, dynamic>? initialRule;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _RuleDialog({
    required this.stepId,
    required this.stepType,
    required this.signals,
    this.initialRule,
    required this.onSave,
  });

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _orderCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _valueCtrl;
  late _TermNode _root;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialRule != null;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRule;
    _orderCtrl =
        TextEditingController(text: r?['ruleOrder']?.toString() ?? '');
    _labelCtrl =
        TextEditingController(text: r?['label'] as String? ?? '');
    _valueCtrl =
        TextEditingController(text: r?['value']?.toString() ?? '');
    _root = r != null
        ? _TermNode.fromJson(r['condition'] as Map<String, dynamic>? ?? {'always': true})
        : _TermNode.always();
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _labelCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  String _valueSuffix() => switch (widget.stepType) {
        'discount_pct' => '% discount',
        'cap_pct'      => '% of base',
        'multiply'     => '× multiplier',
        _              => 'amount',
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'ruleOrder': int.parse(_orderCtrl.text.trim()),
      'label': _labelCtrl.text.trim(),
      'condition': _root.toJson(),
      'value': double.parse(_valueCtrl.text.trim()),
    };
    try {
      await widget.onSave(body);
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
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                const Icon(Icons.rule_rounded,
                    color: Colors.white, size: 20),
                const Gap(10),
                Text(
                  _isEdit ? 'Edit Rule' : 'New Rule',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                const Gap(6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _stepTypeLabel(widget.stepType),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),

            // Body — scrollable in case condition tree is large
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13)),
                          ),
                          const Gap(12),
                        ],

                        Row(children: [
                          SizedBox(
                            width: 80,
                            child: _Field(
                                label: 'Order',
                                ctrl: _orderCtrl,
                                required: true,
                                numeric: true),
                          ),
                          const Gap(12),
                          Expanded(
                              child: _Field(
                                  label: 'Label',
                                  ctrl: _labelCtrl,
                                  required: true)),
                          const Gap(12),
                          SizedBox(
                            width: 110,
                            child: _Field(
                              label: _valueSuffix(),
                              ctrl: _valueCtrl,
                              required: true,
                              numeric: true,
                            ),
                          ),
                        ]),

                        const Gap(16),
                        Text('Condition',
                            style: AppTextStyles.label),
                        const Gap(8),

                        // ── Condition builder ──────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0)),
                          ),
                          child: _ConditionNode(
                            node: _root,
                            signals: widget.signals,
                            depth: 0,
                            onChanged: (n) =>
                                setState(() => _root = n),
                          ),
                        ),
                      ]),
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
                        child: const Text('Cancel')),
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
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Text(_isEdit ? 'Save Changes' : 'Add Rule'),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
        begin: const Offset(0.93, 0.93),
        duration: 250.ms,
        curve: Curves.easeOutBack);
  }
}

// ── Condition Tree Node (data model) ─────────────────────────
class _TermNode {
  /// 'signal' | 'group' | 'not' | 'always'
  final String type;
  final String signalName; // when type == 'signal'
  final String operator; // 'AND' | 'OR' when type == 'group'
  final List<_TermNode> children; // when type == 'group' or 'not'

  const _TermNode({
    required this.type,
    this.signalName = '',
    this.operator = 'AND',
    this.children = const [],
  });

  factory _TermNode.always() => const _TermNode(type: 'always');

  factory _TermNode.signal(String name) =>
      _TermNode(type: 'signal', signalName: name);

  factory _TermNode.group({String op = 'AND', List<_TermNode>? children}) =>
      _TermNode(
          type: 'group',
          operator: op,
          children: children ?? [_TermNode.always()]);

  factory _TermNode.not(_TermNode child) =>
      _TermNode(type: 'not', children: [child]);

  factory _TermNode.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('always')) return _TermNode.always();
    if (json.containsKey('signal')) {
      return _TermNode.signal(json['signal'] as String);
    }
    if (json.containsKey('not')) {
      return _TermNode.not(
          _TermNode.fromJson(json['not'] as Map<String, dynamic>));
    }
    final op = json['operator'] as String? ?? 'AND';
    final terms = (json['terms'] as List? ?? [])
        .map((t) => _TermNode.fromJson(t as Map<String, dynamic>))
        .toList();
    return _TermNode(type: 'group', operator: op, children: terms);
  }

  Map<String, dynamic> toJson() {
    switch (type) {
      case 'always':
        return {'always': true};
      case 'signal':
        return {'signal': signalName};
      case 'not':
        return {'not': children.first.toJson()};
      default: // group
        return {
          'operator': operator,
          'terms': children.map((c) => c.toJson()).toList(),
        };
    }
  }

  _TermNode copyWith({
    String? type,
    String? signalName,
    String? operator,
    List<_TermNode>? children,
  }) =>
      _TermNode(
        type: type ?? this.type,
        signalName: signalName ?? this.signalName,
        operator: operator ?? this.operator,
        children: children ?? this.children,
      );
}

// ── Condition Node Widget ─────────────────────────────────────
class _ConditionNode extends StatelessWidget {
  final _TermNode node;
  final List<Map<String, dynamic>> signals;
  final int depth;
  final void Function(_TermNode) onChanged;

  const _ConditionNode({
    required this.node,
    required this.signals,
    required this.depth,
    required this.onChanged,
  });

  static const _depthColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
  ];

  Color get _color => _depthColors[depth % _depthColors.length];

  @override
  Widget build(BuildContext context) {
    return switch (node.type) {
      'always' => _buildLeaf(context),
      'signal' => _buildSignalLeaf(context),
      'not'    => _buildNot(context),
      _        => _buildGroup(context),
    };
  }

  // ── shared popup menu items ───────────────────────────────────
  List<PopupMenuEntry<String>> get _typeMenuItems => [
        const PopupMenuItem(
            value: 'always',
            child: Row(children: [
              Icon(Icons.all_inclusive_rounded, size: 16),
              Gap(8),
              Text('Always (matches all)'),
            ])),
        const PopupMenuItem(
            value: 'signal',
            child: Row(children: [
              Icon(Icons.sensors_rounded, size: 16),
              Gap(8),
              Text('Signal'),
            ])),
        const PopupMenuItem(
            value: 'group',
            child: Row(children: [
              Icon(Icons.account_tree_rounded, size: 16),
              Gap(8),
              Text('Group (AND / OR)'),
            ])),
        const PopupMenuItem(
            value: 'not',
            child: Row(children: [
              Icon(Icons.block_rounded, size: 16),
              Gap(8),
              Text('NOT'),
            ])),
      ];

  void _handleTypeSelect(String value) {
    switch (value) {
      case 'always':
        onChanged(_TermNode.always());
      case 'signal':
        onChanged(_TermNode.signal(
            signals.isNotEmpty ? signals.first['signalName'] as String : ''));
      case 'group':
        onChanged(_TermNode.group());
      case 'not':
        onChanged(_TermNode.not(_TermNode.always()));
    }
  }

  Widget _buildLeaf(BuildContext context) {
    return Row(children: [
      _NodeTypeButton(
        label: 'ALWAYS',
        color: Colors.grey,
        items: _typeMenuItems,
        onSelected: _handleTypeSelect,
      ),
    ]);
  }

  Widget _buildSignalLeaf(BuildContext context) {
    final signalNames = signals.map((s) => s['signalName'] as String).toList();
    final currentName =
        signalNames.contains(node.signalName) ? node.signalName : null;
    return Row(children: [
      _NodeTypeButton(
          label: 'SIGNAL',
          color: _color,
          items: _typeMenuItems,
          onSelected: _handleTypeSelect),
      const Gap(6),
      Expanded(
        child: DropdownButton<String>(
          value: currentName,
          isExpanded: true,
          hint: const Text('Select signal'),
          isDense: true,
          items: signalNames
              .map((n) =>
                  DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) =>
              onChanged(node.copyWith(signalName: v ?? '')),
        ),
      ),
    ]);
  }

  Widget _buildNot(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _NodeTypeButton(
            label: 'NOT',
            color: AppColors.danger,
            items: _typeMenuItems,
            onSelected: _handleTypeSelect),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 16, top: 6),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: AppColors.danger.withOpacity(0.3), width: 2)),
          ),
          padding: const EdgeInsets.only(left: 10),
          child: _ConditionNode(
            node: node.children.first,
            signals: signals,
            depth: depth + 1,
            onChanged: (child) =>
                onChanged(node.copyWith(children: [child])),
          ),
        ),
      ),
    ]);
  }

  Widget _buildGroup(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _NodeTypeButton(
            label: 'GROUP',
            color: _color,
            items: _typeMenuItems,
            onSelected: _handleTypeSelect),
        const Gap(6),
        _OperatorToggle(
          value: node.operator,
          onChanged: (op) => onChanged(node.copyWith(operator: op)),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => onChanged(node.copyWith(
            children: [...node.children, _TermNode.always()],
          )),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: const Text('Add term', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: _color,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]),
      const Gap(4),
      ...node.children.asMap().entries.map((e) {
        final i = e.key;
        final child = e.value;
        return Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(color: _color.withOpacity(0.3), width: 2)),
            ),
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ConditionNode(
                    node: child,
                    signals: signals,
                    depth: depth + 1,
                    onChanged: (updated) {
                      final newChildren = [...node.children];
                      newChildren[i] = updated;
                      onChanged(node.copyWith(children: newChildren));
                    },
                  ),
                ),
                if (node.children.length > 1)
                  GestureDetector(
                    onTap: () {
                      final newChildren = [...node.children]..removeAt(i);
                      onChanged(node.copyWith(children: newChildren));
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: Colors.grey[400]),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    ]);
  }

}

// ── Operator Toggle ───────────────────────────────────────────
class _OperatorToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
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
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? _kGrad1 : Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              op,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Node Type Button ──────────────────────────────────────────
// Uses PopupMenuButton so the menu appears directly below the button,
// not at a hardcoded screen position.
class _NodeTypeButton extends StatelessWidget {
  final String label;
  final Color color;
  final List<PopupMenuEntry<String>> items;
  final void Function(String) onSelected;

  const _NodeTypeButton({
    required this.label,
    required this.color,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      tooltip: 'Change type',
      itemBuilder: (_) => items,
      offset: const Offset(0, 28), // drop down below the button
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const Gap(4),
          Icon(Icons.arrow_drop_down_rounded, size: 14, color: color),
        ]),
      ),
    );
  }
}

// ── Reusable Field ────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  final bool numeric;
  final int maxLines;

  const _Field({
    required this.label,
    required this.ctrl,
    this.required = false,
    this.numeric = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const Gap(4),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType:
              numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
          style: AppTextStyles.body,
          decoration: const InputDecoration(isDense: true),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      ],
    );
  }
}
