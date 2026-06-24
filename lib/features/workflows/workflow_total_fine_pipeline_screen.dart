// Step 46 — Total Fine Pipeline editor.
//
// Lets the admin manage the per-workflow Stage-3 pipeline:
// ordered, signal-conditional operations applied to the group total
// after Stages 1+2. See gap_total_fine_pipeline_design.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/condition_builder.dart';

const _kGrad1 = Color(0xFF1B4D3E);
const _kGrad2 = Color(0xFF2E7D5C);

// ── Operation enum ─────────────────────────────────────────────────
const List<String> _kOps = [
  'multiply',
  'percent_discount',
  'add',
  'subtract',
  'cap',
  'floor',
];

String _opLabel(BuildContext context, String op) {
  final l10n = AppLocalizations.of(context);
  switch (op) {
    case 'multiply':         return l10n.tfpOpMultiply;
    case 'percent_discount': return l10n.tfpOpPercentDiscount;
    case 'add':              return l10n.tfpOpAdd;
    case 'subtract':         return l10n.tfpOpSubtract;
    case 'cap':              return l10n.tfpOpCap;
    case 'floor':            return l10n.tfpOpFloor;
  }
  return op;
}

// ── Rule model (server JSON ↔ Dart) ────────────────────────────────
class _Rule {
  final String? id;
  int priority;
  String name;
  String operation;
  Map<String, dynamic>? condition;
  num? valueLiteral;
  String? valueSourceQuestionId;
  num? valueSourceMultiplier;
  bool isActive;

  _Rule({
    this.id,
    required this.priority,
    required this.name,
    required this.operation,
    this.condition,
    this.valueLiteral,
    this.valueSourceQuestionId,
    this.valueSourceMultiplier,
    this.isActive = true,
  });

  factory _Rule.fromJson(Map<String, dynamic> j) => _Rule(
        id: j['id'] as String?,
        priority: j['priority'] as int,
        name: j['name'] as String,
        operation: j['operation'] as String,
        condition: (j['condition'] as Map?)?.cast<String, dynamic>(),
        valueLiteral: j['valueLiteral'] as num?,
        valueSourceQuestionId: j['valueSourceQuestionId'] as String?,
        valueSourceMultiplier: j['valueSourceMultiplier'] as num?,
        isActive: j['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toSavePayload() => {
        'priority': priority,
        'name': name,
        'operation': operation,
        'condition': condition,
        'valueLiteral': valueLiteral,
        'valueSourceQuestionId': valueSourceQuestionId,
        'valueSourceMultiplier': valueSourceMultiplier,
        'isActive': isActive,
      };
}

// ── Screen ─────────────────────────────────────────────────────────
class WorkflowTotalFinePipelineScreen extends ConsumerStatefulWidget {
  final String workflowId;
  final String workflowName;
  const WorkflowTotalFinePipelineScreen({
    super.key,
    required this.workflowId,
    required this.workflowName,
  });

  @override
  ConsumerState<WorkflowTotalFinePipelineScreen> createState() =>
      _WorkflowTotalFinePipelineScreenState();
}

class _WorkflowTotalFinePipelineScreenState
    extends ConsumerState<WorkflowTotalFinePipelineScreen> {
  List<_Rule> _rules = [];
  List<Map<String, String>> _numericQuestions = [];
  // Workflow signals fed to the shared ConditionBuilder so admins pick from a
  // dropdown instead of typing JSON. Same shape as /workflows/{wf}/signals.
  List<Map<String, dynamic>> _signals = [];
  bool _loading = true;
  String? _error;

  Dio get _dio => ref.read(dioProvider);
  String get _base => '/workflows/${widget.workflowId}/total-fine-rules';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get<List<dynamic>>(_base),
        _dio.get<List<dynamic>>(
          '/workflows/${widget.workflowId}/signals/numeric-questions',
        ),
        _dio.get<List<dynamic>>('/workflows/${widget.workflowId}/signals'),
      ]);
      setState(() {
        _rules = (results[0].data ?? [])
            .map((e) => _Rule.fromJson(e as Map<String, dynamic>))
            .toList();
        _numericQuestions = ((results[1].data ?? [])
                .cast<Map<String, dynamic>>())
            .map((q) => {
                  'id': q['id'] as String,
                  'text': (q['questionText'] as String?) ?? '(no text)',
                })
            .toList();
        _signals = (results[2].data ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _createOrEdit({_Rule? existing}) async {
    final next = await showDialog<_Rule>(
      context: context,
      builder: (_) => _EditRuleDialog(
        initial: existing,
        numericQuestions: _numericQuestions,
        signals: _signals,
        nextPriority:
            existing?.priority ?? ((_rules.length + 1) * 10),
      ),
    );
    if (next == null) return;
    try {
      if (existing?.id == null) {
        await _dio.post(_base, data: next.toSavePayload());
      } else {
        await _dio.put('$_base/${existing!.id}', data: next.toSavePayload());
      }
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(_Rule r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('"${r.name}" — this cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || r.id == null) return;
    try {
      await _dio.delete('$_base/${r.id}');
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final r = _rules.removeAt(oldIndex);
      _rules.insert(newIndex, r);
    });
    try {
      await _dio.post('$_base/reorder', data: {
        'orderedIds': _rules
            .where((r) => r.id != null)
            .map((r) => r.id)
            .toList(),
      });
      await _load();
    } catch (e) {
      _showError(e);
      await _load();
    }
  }

  void _showError(Object e) {
    final msg = e is DioException
        ? (e.response?.data?.toString() ?? e.message ?? 'Error')
        : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, maxLines: 4),
      backgroundColor: Colors.red.shade700,
    ));
  }

  /// Compact human description of the condition: "always" if null,
  /// otherwise a stringified version of the operator/terms tree.
  String _conditionDesc(Map<String, dynamic>? cond) {
    if (cond == null) return 'always';
    return _stringifyCondition(cond);
  }

  String _stringifyCondition(dynamic node) {
    if (node is! Map) return node.toString();
    if (node.containsKey('signal')) return node['signal'].toString();
    final op = (node['operator'] as String?)?.toUpperCase() ?? 'AND';
    final terms = (node['terms'] as List?) ?? const [];
    if (op == 'NOT') {
      return terms.isEmpty ? 'true' : 'NOT ${_stringifyCondition(terms.first)}';
    }
    return terms.map(_stringifyCondition).join(' $op ');
  }

  /// Compact value chip — e.g. "−20%", "× 0.8", "+₪5,000", "≤ ₪250,000",
  /// "≤ Q × 5%". Uses U+2212 (real minus) so subtract/percent_discount
  /// don't render as a tiny hyphen.
  String _valueBadge(_Rule r) {
    final num? v = r.valueLiteral;
    final hasSource = r.valueSourceQuestionId != null;
    if (!hasSource && v == null) return '?';

    String numStr(num n) {
      if (n == n.truncateToDouble()) return n.toInt().toString();
      return n.toString();
    }

    String moneyStr(num n) {
      final whole = n.toInt();
      final s = whole.toString();
      final parts = <String>[];
      for (var i = s.length; i > 0; i -= 3) {
        parts.insert(0, s.substring((i - 3).clamp(0, s.length), i));
      }
      final formatted = parts.join(',');
      return '₪$formatted';
    }

    String valuePiece() {
      if (hasSource) {
        final m = r.valueSourceMultiplier;
        if (m == null || m == 1) return 'Q';
        // Render small fractions as percentages (e.g. 0.05 → "5%").
        if (m > 0 && m < 1) {
          final pct = (m * 100);
          final pctStr = pct == pct.truncateToDouble()
              ? pct.toInt().toString()
              : pct.toString();
          return 'Q × $pctStr%';
        }
        return 'Q × ${numStr(m)}';
      }
      return moneyStr(v!);
    }

    switch (r.operation) {
      case 'multiply':
        // For literal: prefer "× 0.8". For sourced: "× Q × 5%" reads odd; just "× <piece>".
        if (!hasSource && v != null) return '× ${numStr(v)}';
        return '× ${valuePiece()}';
      case 'percent_discount':
        if (!hasSource && v != null) return '−${numStr(v)}%';
        return '−${valuePiece()}%';
      case 'add':
        return '+${valuePiece()}';
      case 'subtract':
        return '−${valuePiece()}';
      case 'cap':
        return '≤ ${valuePiece()}';
      case 'floor':
        return '≥ ${valuePiece()}';
    }
    return valuePiece();
  }

  /// Subtle background tint per op family — keeps the row visually
  /// scannable without screaming.
  Color _opTint(String op) {
    switch (op) {
      case 'percent_discount':
      case 'subtract':
        return const Color(0xFF059669); // emerald = reduces fine
      case 'add':
        return const Color(0xFFDC2626); // red = surcharge
      case 'multiply':
        return const Color(0xFF6B7280); // gray = generic factor
      case 'cap':
        return const Color(0xFFD97706); // amber = ceiling
      case 'floor':
        return const Color(0xFF2563EB); // blue = floor
    }
    return _kGrad1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.totalFinePipelineTitle} — ${widget.workflowName}'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kGrad1, _kGrad2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        // ── "Add Rule" pill in the top bar (matches the quiz numeric
        //    engine's "Add Step +" style) ─────────────────────────────
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _loading ? null : () => _createOrEdit(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.totalFinePipelineAddRule.replaceFirst('+ ', ''),
                        style: const TextStyle(
                          color: _kGrad1,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(4),
                      const Icon(Icons.add_rounded,
                          size: 18, color: _kGrad1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const Gap(8),
                        Text(_error!),
                        const Gap(12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (_rules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 48, color: AppColors.muted),
              const Gap(12),
              Text(l10n.totalFinePipelineEmpty,
                  style: AppTextStyles.bodySmall),
              const Gap(8),
              Text(l10n.totalFinePipelineHint,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.muted)),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(l10n.totalFinePipelineHint,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: _reorder,
          buildDefaultDragHandles: false,
          children: [
            for (var i = 0; i < _rules.length; i++)
              _ruleCard(_rules[i], i, key: ValueKey(_rules[i].id ?? i)),
          ],
        ),
      ],
    );
  }

  Widget _ruleCard(_Rule r, int index, {required Key key}) {
    final tint = _opTint(r.operation);
    final badge = _valueBadge(r);
    final conditionDesc = _conditionDesc(r.condition);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _kGrad1.withValues(alpha: 0.8), width: 3),
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        child: Row(
          children: [
            // ── Drag handle + action icons (left cluster) ──────
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.drag_indicator,
                    size: 16, color: AppColors.muted),
              ),
            ),
            _TfpIconBtn(
              icon: Icons.delete_outline_rounded,
              color: AppColors.danger,
              tooltip: 'Delete',
              onTap: () => _delete(r),
            ),
            _TfpIconBtn(
              icon: Icons.edit_outlined,
              color: _kGrad1,
              tooltip: 'Edit',
              onTap: () => _createOrEdit(existing: r),
            ),
            const Gap(8),

            // ── Operation value chip ──────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tint.withValues(alpha: 0.35)),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: tint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(10),

            // ── Name + condition (right side, fills) ──────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!r.isActive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.muted.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('inactive',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.muted)),
                        ),
                        const Gap(6),
                      ],
                      Flexible(
                        child: Text(
                          r.name,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Gap(2),
                  Text(
                    conditionDesc,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Gap(10),

            // ── Priority badge (far right) ────────────────────
            Container(
              width: 32,
              height: 30,
              decoration: BoxDecoration(
                color: _kGrad1.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${r.priority}',
                  style: const TextStyle(
                    color: _kGrad1,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hover-tinted icon button (mirrors workflow_rule_engine_screen's
//    _IconBtn) ─────────────────────────────────────────────────────
class _TfpIconBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _TfpIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_TfpIconBtn> createState() => _TfpIconBtnState();
}

class _TfpIconBtnState extends State<_TfpIconBtn> {
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
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon,
                size: 15, color: _hov ? widget.color : Colors.grey[400]),
          ),
        ),
      ),
    );
  }
}

// ── Edit dialog (matches quiz_numeric_engine_screen's rule editor) ─
class _EditRuleDialog extends StatefulWidget {
  final _Rule? initial;
  final List<Map<String, String>> numericQuestions;
  final List<Map<String, dynamic>> signals;
  final int nextPriority;

  const _EditRuleDialog({
    required this.initial,
    required this.numericQuestions,
    required this.signals,
    required this.nextPriority,
  });

  @override
  State<_EditRuleDialog> createState() => _EditRuleDialogState();
}

class _EditRuleDialogState extends State<_EditRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priorityCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _literalCtrl;
  late final TextEditingController _multiplierCtrl;
  late String _operation;
  late String _valueMode; // 'literal' | 'sourced'
  String? _sourceQuestionId;
  late bool _isActive;
  late TermNode _root;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _priorityCtrl = TextEditingController(
      text: (r?.priority ?? widget.nextPriority).toString(),
    );
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _literalCtrl = TextEditingController(
      text: r?.valueLiteral?.toString() ?? '',
    );
    _multiplierCtrl = TextEditingController(
      text: r?.valueSourceMultiplier?.toString() ?? '',
    );
    _operation = r?.operation ?? 'multiply';
    _valueMode = (r?.valueSourceQuestionId != null) ? 'sourced' : 'literal';
    _sourceQuestionId = r?.valueSourceQuestionId;
    _isActive = r?.isActive ?? true;
    _root = r?.condition != null
        ? TermNode.fromJson(r!.condition!)
        : TermNode.always();
  }

  @override
  void dispose() {
    _priorityCtrl.dispose();
    _nameCtrl.dispose();
    _literalCtrl.dispose();
    _multiplierCtrl.dispose();
    super.dispose();
  }

  /// `{"always": true}` is the "no condition" marker — strip it on save so
  /// the backend stores NULL (`always = no condition` is the same as no row).
  Map<String, dynamic>? _conditionJson() {
    final j = _root.toJson();
    if (j.length == 1 && j['always'] == true) return null;
    return j;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final priority = int.tryParse(_priorityCtrl.text.trim());
    if (priority == null || priority < 0) {
      setState(() => _error = 'Priority must be a non-negative integer.');
      return;
    }

    num? literal;
    String? sourceQ;
    num? multiplier;
    if (_valueMode == 'literal') {
      final t = _literalCtrl.text.trim();
      literal = num.tryParse(t);
      if (literal == null) {
        setState(() => _error = 'Value must be a number.');
        return;
      }
    } else {
      if (_sourceQuestionId == null) {
        setState(() => _error = 'Pick a numeric question for the value source.');
        return;
      }
      sourceQ = _sourceQuestionId;
      final mt = _multiplierCtrl.text.trim();
      if (mt.isNotEmpty) {
        final m = num.tryParse(mt);
        if (m == null || m <= 0) {
          setState(() => _error = 'Multiplier must be a positive number.');
          return;
        }
        multiplier = m;
      }
    }

    final r = _Rule(
      id: widget.initial?.id,
      priority: priority,
      name: _nameCtrl.text.trim(),
      operation: _operation,
      condition: _conditionJson(),
      valueLiteral: literal,
      valueSourceQuestionId: sourceQ,
      valueSourceMultiplier: multiplier,
      isActive: _isActive,
    );
    Navigator.pop(context, r);
  }

  String _valueHint() {
    switch (_operation) {
      case 'percent_discount':
        return '20';
      case 'multiply':
        return '0.8';
      case 'cap':
      case 'floor':
      case 'add':
      case 'subtract':
        return '20000';
    }
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLiteral = _valueMode == 'literal';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header (gradient + op-type pill + title + ×) ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kGrad1, _kGrad2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
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
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _opLabel(context, _operation),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ),

              // ── Body ────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row — Order / Name / Value (matches the screenshot)
                      Row(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _priorityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Order',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.tfpRuleName,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? l10n.required
                                : null,
                          ),
                        ),
                        const Gap(12),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _literalCtrl,
                            enabled: isLiteral,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.tfpRuleValueLiteral,
                              hintText: isLiteral ? _valueHint() : '(sourced)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              filled: !isLiteral,
                              fillColor: const Color(0xFFF3F4F6),
                            ),
                          ),
                        ),
                      ]),
                      const Gap(14),

                      // Operation
                      DropdownButtonFormField<String>(
                        initialValue: _operation,
                        decoration: InputDecoration(
                          labelText: l10n.tfpRuleOperation,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _kOps
                            .map((o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(_opLabel(context, o)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _operation = v ?? 'multiply'),
                      ),
                      const Gap(14),

                      // Active toggle (compact)
                      Row(children: [
                        Checkbox(
                          value: _isActive,
                          onChanged: (v) =>
                              setState(() => _isActive = v ?? true),
                        ),
                        Text(l10n.tfpRuleActive,
                            style: const TextStyle(fontSize: 13)),
                      ]),
                      const Gap(8),

                      // Value source
                      Text(l10n.tfpRuleValueMode,
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w600)),
                      const Gap(6),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                              value: 'literal',
                              label: Text(l10n.tfpRuleValueLiteral)),
                          ButtonSegment(
                              value: 'sourced',
                              label: Text(l10n.tfpRuleValueSourced)),
                        ],
                        selected: {_valueMode},
                        onSelectionChanged: (s) =>
                            setState(() => _valueMode = s.first),
                      ),
                      if (!isLiteral) ...[
                        const Gap(12),
                        DropdownButtonFormField<String?>(
                          initialValue: _sourceQuestionId,
                          decoration: InputDecoration(
                            labelText: l10n.tfpRuleValueQuestion,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: widget.numericQuestions
                              .map((q) => DropdownMenuItem<String?>(
                                    value: q['id'],
                                    child: Text(
                                      q['text']!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _sourceQuestionId = v),
                        ),
                        const Gap(8),
                        TextFormField(
                          controller: _multiplierCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.tfpRuleValueMultiplier,
                            hintText: '0.05',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                      const Gap(20),
                      const Divider(),
                      const Gap(8),

                      // Condition section — shared ConditionBuilder
                      Text('Condition', style: AppTextStyles.label),
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ConditionBuilder(
                          node: _root,
                          signals: widget.signals,
                          primaryColor: _kGrad1,
                          onChanged: (n) => setState(() => _root = n),
                        ),
                      ),

                      if (_error != null) ...[
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Colors.red.shade900, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Footer ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    const Gap(8),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGrad1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: Text(_isEdit ? 'Save Changes' : 'Add Rule'),
                    ),
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
