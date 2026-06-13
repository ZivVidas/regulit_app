import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = AppColors.blue;
const _kGrad2 = Color(0xFF2D6BB0);

// ── Result label colors ───────────────────────────────────────
Color _labelColor(String label) => switch (label.toUpperCase()) {
      'HIGH'       => const Color(0xFFDC2626),
      'MEDIUM'     => const Color(0xFFD97706),
      'BASIC'      => AppColors.muted,
      'INDIVIDUAL' => const Color(0xFF2563EB),
      _            => const Color(0xFF7C3AED),
    };

Color _labelBg(String label) => switch (label.toUpperCase()) {
      'HIGH'       => const Color(0xFFFEE2E2),
      'MEDIUM'     => const Color(0xFFFEF3C7),
      'BASIC'      => const Color(0xFFF3F4F6),
      'INDIVIDUAL' => const Color(0xFFDBEAFE),
      _            => const Color(0xFFF3E8FF),
    };

// ── Question group (options grouped by their parent question) ──
class _QuestionGroup {
  final int questionNumber;
  final String questionText;
  final List<String> optionIds;
  const _QuestionGroup({
    required this.questionNumber,
    required this.questionText,
    required this.optionIds,
  });
}

// ── State ─────────────────────────────────────────────────────
class _EngineState {
  final List<Map<String, dynamic>> signals;
  final List<Map<String, dynamic>> rules;
  final Map<String, String> optionLabels;
  final List<_QuestionGroup> optionGroups;
  // Step 38 — numeric-eligible questions (q_type IN numeric|yes_no)
  // reachable from this quiz via shared workflows. Source: the new
  // GET /quizzes/{id}/signals/numeric-questions endpoint.
  final List<Map<String, dynamic>> numericQuestions;
  final bool isLoading;
  final String? error;

  const _EngineState({
    this.signals = const [],
    this.rules = const [],
    this.optionLabels = const {},
    this.optionGroups = const [],
    this.numericQuestions = const [],
    this.isLoading = true,
    this.error,
  });

  _EngineState copyWith({
    List<Map<String, dynamic>>? signals,
    List<Map<String, dynamic>>? rules,
    Map<String, String>? optionLabels,
    List<_QuestionGroup>? optionGroups,
    List<Map<String, dynamic>>? numericQuestions,
    bool? isLoading,
    String? error,
  }) =>
      _EngineState(
        signals: signals ?? this.signals,
        rules: rules ?? this.rules,
        optionLabels: optionLabels ?? this.optionLabels,
        optionGroups: optionGroups ?? this.optionGroups,
        numericQuestions: numericQuestions ?? this.numericQuestions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _EngineNotifier extends StateNotifier<_EngineState> {
  final Dio _dio;
  final String quizId;

  _EngineNotifier(this._dio, this.quizId) : super(const _EngineState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Phase 1: signals, rules, option-labels, steps — all parallel
      final results = await Future.wait([
        _dio.get<List<dynamic>>('/quizzes/$quizId/signals'),
        _dio.get<List<dynamic>>('/quizzes/$quizId/result-rules'),
        _dio.get<Map<String, dynamic>>('/quizzes/$quizId/signals/option-labels'),
        _dio.get<Map<String, dynamic>>(
          '/quizzes/$quizId/steps',
          queryParameters: {'page': 1, 'page_size': 100},
        ),
        // Step 38 — numeric-eligible questions reachable from this quiz
        // via shared workflows.
        _dio.get<List<dynamic>>(
            '/quizzes/$quizId/signals/numeric-questions'),
      ]);

      final optionLabels = (results[2].data as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
      final numericQs =
          (results[4].data as List).cast<Map<String, dynamic>>();

      // Phase 2: fetch questions for each step in parallel, build groups
      final stepsData = results[3].data as Map<String, dynamic>;
      final steps = (stepsData['items'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      final groupLists = await Future.wait(steps.map((step) async {
        final stepId = step['id'] as String;
        try {
          final qRes = await _dio.get<Map<String, dynamic>>(
            '/quizzes/$quizId/steps/$stepId/questions',
            queryParameters: {'page': 1, 'page_size': 200},
          );
          final qs = (qRes.data!['items'] as List)
              .cast<Map<String, dynamic>>();
          return qs
              .map((q) {
                final opts =
                    (q['options'] as List?)?.cast<Map<String, dynamic>>() ??
                        [];
                final ids = opts
                    .map((o) => o['id'] as String)
                    .where((id) => optionLabels.containsKey(id))
                    .toList();
                if (ids.isEmpty) return null;
                return _QuestionGroup(
                  questionNumber: q['questionNumber'] as int? ?? 0,
                  questionText: q['questionText'] as String? ?? '',
                  optionIds: ids,
                );
              })
              .whereType<_QuestionGroup>()
              .toList();
        } catch (_) {
          return <_QuestionGroup>[];
        }
      }));

      final optionGroups = groupLists.expand((g) => g).toList()
        ..sort((a, b) => a.questionNumber.compareTo(b.questionNumber));

      state = state.copyWith(
        isLoading: false,
        signals: (results[0].data as List).cast<Map<String, dynamic>>(),
        rules: (results[1].data as List).cast<Map<String, dynamic>>(),
        optionLabels: optionLabels,
        optionGroups: optionGroups,
        numericQuestions: numericQs,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteSignal(String id) async {
    try {
      await _dio.delete<dynamic>('/quizzes/$quizId/signals/$id');
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteRule(String id) async {
    try {
      await _dio.delete<dynamic>('/quizzes/$quizId/result-rules/$id');
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow; // let _confirmDelete show the SnackBar
    }
  }
}

final _engineProvider = StateNotifierProvider.autoDispose
    .family<_EngineNotifier, _EngineState, String>(
  (ref, quizId) => _EngineNotifier(ref.watch(dioProvider), quizId),
);

// ── Screen ────────────────────────────────────────────────────
class QuizResultEngineScreen extends ConsumerWidget {
  final String quizId;
  final String quizName;

  const QuizResultEngineScreen({
    super.key,
    required this.quizId,
    required this.quizName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_engineProvider(quizId));
    final dio = ref.read(dioProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _Header(quizName: quizName, onBack: () => context.pop()),

          if (s.isLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (s.error != null)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(s.error!,
                      style: const TextStyle(color: AppColors.danger)),
                  const Gap(12),
                  FilledButton(
                    onPressed: () =>
                        ref.read(_engineProvider(quizId).notifier).load(),
                    child: const Text('Retry'),
                  ),
                ]),
              ),
            )
          else
            Expanded(
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
                        context, ref, dio, quizId, s.optionLabels,
                        s.optionGroups, s.numericQuestions, null),
                  ),
                  const Gap(8),
                  ...s.signals.asMap().entries.map((e) => _SignalCard(
                        signal: e.value,
                        index: e.key,
                        optionLabels: s.optionLabels,
                        onEdit: () => _showSignalDialog(
                            context, ref, dio, quizId, s.optionLabels,
                            s.optionGroups, s.numericQuestions, e.value),
                        onDelete: () => _confirmDelete(
                          context,
                          'signal "${e.value['signalName']}"',
                          () => ref
                              .read(_engineProvider(quizId).notifier)
                              .deleteSignal(e.value['id'] as String),
                        ),
                      )),
                  if (s.signals.isEmpty)
                    const _EmptyHint(
                        message: 'No signals yet. Add the first signal.'),
                  const Gap(24),

                  // ── Rules section ────────────────────────────
                  _SectionHeader(
                    title: 'Result Rules',
                    subtitle: '${s.rules.length} rules · evaluated in priority order',
                    icon: Icons.rule_rounded,
                    color: const Color(0xFF7C3AED),
                    onAdd: () => _showRuleDialog(
                        context, ref, dio, quizId, s.signals, s.optionLabels, null),
                  ),
                  const Gap(8),
                  ...s.rules.asMap().entries.map((e) => _RuleCard(
                        rule: e.value,
                        index: e.key,
                        onEdit: () => _showRuleDialog(
                            context, ref, dio, quizId, s.signals, s.optionLabels, e.value),
                        onDelete: () => _confirmDelete(
                          context,
                          'rule priority ${e.value['priority']}',
                          () => ref
                              .read(_engineProvider(quizId).notifier)
                              .deleteRule(e.value['id'] as String),
                        ),
                      )),
                  if (s.rules.isEmpty)
                    const _EmptyHint(message: 'No rules yet. Add the first rule.'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSignalDialog(
    BuildContext context,
    WidgetRef ref,
    Dio dio,
    String quizId,
    Map<String, String> optionLabels,
    List<_QuestionGroup> optionGroups,
    List<Map<String, dynamic>> numericQuestions,
    Map<String, dynamic>? initial,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SignalDialog(
        dio: dio,
        quizId: quizId,
        optionLabels: optionLabels,
        optionGroups: optionGroups,
        numericQuestions: numericQuestions,
        initial: initial,
        onSaved: () =>
            ref.read(_engineProvider(quizId).notifier).load(),
      ),
    );
  }

  void _showRuleDialog(BuildContext context, WidgetRef ref, Dio dio,
      String quizId, List<Map<String, dynamic>> signals,
      Map<String, String> optionLabels,
      Map<String, dynamic>? initial) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RuleDialog(
        dio: dio,
        quizId: quizId,
        signals: signals,
        optionLabels: optionLabels,
        initial: initial,
        onSaved: () =>
            ref.read(_engineProvider(quizId).notifier).load(),
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
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String quizName;
  final VoidCallback onBack;

  const _Header({required this.quizName, required this.onBack});

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
              color: Color(0x331A3C6B), blurRadius: 20, offset: Offset(0, 6)),
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
                child: const Icon(Icons.rule_rounded,
                    color: Colors.white, size: 22),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Result Engine',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        )),
                    Text(quizName,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12)),
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

// ── Section header ────────────────────────────────────────────
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: Icon(Icons.add_rounded, size: 16, color: color),
          label: Text('Add', style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }
}

// ── Signal card ───────────────────────────────────────────────
class _SignalCard extends StatefulWidget {
  final Map<String, dynamic> signal;
  final int index;
  final Map<String, String> optionLabels;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _SignalCard({
    required this.signal,
    required this.index,
    required this.optionLabels,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<_SignalCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.signal;
    final required =
        (s['requiredOptionIds'] as List?)?.cast<String>() ?? [];
    final excluded =
        (s['excludedOptionIds'] as List?)?.cast<String>() ?? [];
    final labels = widget.optionLabels;

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(
              left: BorderSide(color: _kGrad1.withOpacity(0.4), width: 3)),
          boxShadow: [
            BoxShadow(
              color: _hov
                  ? _kGrad1.withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
              blurRadius: _hov ? 16 : 4,
              offset: const Offset(0, 2),
            ),
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
                    Text(
                      s['signalName'] as String? ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if ((s['description'] as String?)?.isNotEmpty ?? false) ...[
                      const Gap(2),
                      Text(s['description'] as String,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                    ],
                    const Gap(6),
                    // Required chips
                    if (required.isNotEmpty) ...[
                      const Text('Required (any):',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151))),
                      const Gap(3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: required
                            .map((id) => _OptionChip(
                                  id: id,
                                  label: labels[id],
                                  color: const Color(0xFF2563EB),
                                ))
                            .toList(),
                      ),
                      const Gap(4),
                    ],
                    // Excluded chips
                    if (excluded.isNotEmpty) ...[
                      const Text('Excluded (none allowed):',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626))),
                      const Gap(3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: excluded
                            .map((id) => _OptionChip(
                                  id: id,
                                  label: labels[id],
                                  color: const Color(0xFFDC2626),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: _kGrad2,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit',
                    onPressed: widget.onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    color: AppColors.danger,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete',
                    onPressed: () => widget.onDelete(),
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

// ── Rule card ─────────────────────────────────────────────────
class _RuleCard extends StatefulWidget {
  final Map<String, dynamic> rule;
  final int index;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _RuleCard({
    required this.rule,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.rule;
    final label = r['resultLabel'] as String? ?? '';
    final color = _labelColor(label);
    final bg = _labelBg(label);
    final priority = r['priority'] as int? ?? 0;
    final condition = r['condition'] as Map<String, dynamic>?;

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: [
            BoxShadow(
              color: _hov
                  ? color.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: _hov ? 16 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority badge
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10, top: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('$priority',
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if ((r['description'] as String?)?.isNotEmpty ?? false) ...[
                          const Gap(8),
                          Expanded(
                            child: Text(r['description'] as String,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.muted),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                    if (condition != null) ...[
                      const Gap(6),
                      Text(
                        _conditionSummary(condition),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: _kGrad2,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit',
                    onPressed: widget.onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    color: AppColors.danger,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete',
                    onPressed: () => widget.onDelete(),
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

String _conditionSummary(Map<String, dynamic> c, [int depth = 0]) {
  if (c.containsKey('always')) return 'always true';
  if (c.containsKey('signal')) return c['signal'] as String;
  if (c.containsKey('not')) {
    return 'NOT ${_conditionSummary(c['not'] as Map<String, dynamic>, depth)}';
  }
  final op = c['operator'] as String? ?? 'AND';
  final terms = (c['terms'] as List?)
          ?.map((t) => _conditionSummary(t as Map<String, dynamic>, depth + 1))
          .join(' $op ') ??
      '';
  return depth > 0 ? '($terms)' : terms;
}

// ── Option chip ────────────────────────────────────────────────
// Shows option_text if available; falls back to truncated UUID.
// UUID is always shown as a tooltip.
class _OptionChip extends StatelessWidget {
  final String id;
  final String? label;
  final Color color;

  const _OptionChip({required this.id, required this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final display = label ?? (id.length > 8 ? '${id.substring(0, 8)}…' : id);
    return Tooltip(
      message: id,
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          display,
          style: TextStyle(
            fontSize: label != null ? 11 : 10,
            fontFamily: label != null ? null : 'monospace',
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Empty hint ────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(message,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF94A3B8))),
      ),
    );
  }
}

// ── Action icon ───────────────────────────────────────────────
class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  const _ActionIcon(
      {required this.icon, required this.color, required this.onTap});

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:
                _hov ? widget.color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon,
              size: 16,
              color: _hov ? widget.color : Colors.grey[400]),
        ),
      ),
    );
  }
}

// ── Signal Dialog ──────────────────────────────────────────────
// Option IDs are selected via 3-state toggle chips when optionLabels is
// non-empty. Otherwise falls back to raw UUID textarea input.
//
// Tap cycle: neutral (grey) → required (blue) → excluded (red) → neutral
class _SignalDialog extends StatefulWidget {
  final Dio dio;
  final String quizId;
  final Map<String, String> optionLabels;
  final List<_QuestionGroup> optionGroups;
  // Step 38 — numeric-eligible questions for the Numeric-condition block.
  final List<Map<String, dynamic>> numericQuestions;
  final Map<String, dynamic>? initial;
  final VoidCallback onSaved;

  const _SignalDialog({
    required this.dio,
    required this.quizId,
    required this.optionLabels,
    required this.optionGroups,
    required this.numericQuestions,
    this.initial,
    required this.onSaved,
  });

  @override
  State<_SignalDialog> createState() => _SignalDialogState();
}

class _SignalDialogState extends State<_SignalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  // Used only when optionLabels is empty (raw UUID fallback)
  late final TextEditingController _requiredCtrl;
  late final TextEditingController _excludedCtrl;

  // Used when optionLabels is non-empty (chip picker)
  late Set<String> _required;
  late Set<String> _excluded;
  String _search = '';

  // Step 38 — numeric block state. All three nullable; backend enforces
  // all-or-none. Errors surface via [_error].
  String? _numericQuestionId;
  String? _numericOp;
  final _numericValueCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initial != null;
  bool get _hasOptions => widget.optionLabels.isNotEmpty;
  bool get _anyNumericFieldSet =>
      _numericQuestionId != null ||
      _numericOp != null ||
      _numericValueCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _nameCtrl = TextEditingController(text: s?['signalName'] as String? ?? '');
    _descCtrl =
        TextEditingController(text: s?['description'] as String? ?? '');

    final reqList = (s?['requiredOptionIds'] as List?)?.cast<String>() ?? [];
    final excList = (s?['excludedOptionIds'] as List?)?.cast<String>() ?? [];
    _required = Set.from(reqList);
    _excluded = Set.from(excList);
    _requiredCtrl = TextEditingController(text: reqList.join('\n'));
    _excludedCtrl = TextEditingController(text: excList.join('\n'));

    // Step 38 — load existing numeric block (null on legacy signals).
    _numericQuestionId = s?['numericQuestionId'] as String?;
    _numericOp = s?['numericOp'] as String?;
    final nv = s?['numericValue'];
    _numericValueCtrl.text = nv == null ? '' : nv.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _requiredCtrl.dispose();
    _excludedCtrl.dispose();
    _numericValueCtrl.dispose();
    super.dispose();
  }

  void _toggleOption(String id) {
    setState(() {
      if (_required.contains(id)) {
        _required.remove(id);
        _excluded.add(id);
      } else if (_excluded.contains(id)) {
        _excluded.remove(id);
      } else {
        _required.add(id);
      }
    });
  }

  List<String> _parseIds(String text) => text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'signalName': _nameCtrl.text.trim(),
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'requiredOptionIds': _hasOptions
          ? _required.toList()
          : _parseIds(_requiredCtrl.text),
      'excludedOptionIds': _hasOptions
          ? _excluded.toList()
          : _parseIds(_excludedCtrl.text),
      // Step 38 — always send all 3 numeric fields when ANY is touched OR
      // we're editing an existing signal (so we can clear a previously-
      // configured numeric block by leaving the inputs blank).
      // Sending partial values lets the backend 422 with a precise
      // all-or-none error, which surfaces in [_error].
      if (_anyNumericFieldSet || _isEdit) ...{
        'numericQuestionId': _numericQuestionId,
        'numericOp': _numericOp,
        'numericValue': _numericValueCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_numericValueCtrl.text.trim()),
      },
    };

    try {
      if (_isEdit) {
        await widget.dio.put<dynamic>(
          '/quizzes/${widget.quizId}/signals/${widget.initial!['id']}',
          data: body,
        );
      } else {
        await widget.dio.post<dynamic>(
          '/quizzes/${widget.quizId}/signals',
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEdit ? 'Edit Signal' : 'New Signal'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Signal name *',
                    hintText: 'e.g. is_public_body',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
                const Gap(12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const Gap(16),

                if (_hasOptions) ...[
                  // ── Chip picker ──────────────────────────────
                  _buildLegend(),
                  const Gap(8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search options…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                    ),
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  ),
                  const Gap(8),
                  _buildOptionChips(),
                  const Gap(8),
                  _buildSelectionSummary(),
                ] else ...[
                  // ── Fallback: raw UUID textareas ─────────────
                  const Text('Required option IDs (any must be selected)',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const Gap(4),
                  TextFormField(
                    controller: _requiredCtrl,
                    decoration: const InputDecoration(
                      hintText: 'One UUID per line',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                    maxLines: 5,
                  ),
                  const Gap(12),
                  const Text('Excluded option IDs (none must be selected)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626))),
                  const Gap(4),
                  TextFormField(
                    controller: _excludedCtrl,
                    decoration: const InputDecoration(
                      hintText: 'One UUID per line (optional)',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                    maxLines: 5,
                  ),
                ],
                const Gap(12),
                // ── Step 38: Numeric condition (optional) ──────────────
                _buildNumericBlock(),
                if (_error != null) ...[
                  const Gap(8),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendDot(AppColors.muted, 'Neutral'),
        const Gap(12),
        _legendDot(const Color(0xFF2563EB), 'Required (tap once)'),
        const Gap(12),
        _legendDot(const Color(0xFFDC2626), 'Excluded (tap twice)'),
      ],
    );
  }

  // Step 38: optional numeric-condition block. Collapsed by default for
  // new signals, auto-expanded when editing a signal that already has a
  // numeric block configured. Backend enforces all-or-none.
  //
  // Dropdown filtering note: the backend endpoint returns numeric AND
  // yes_no questions (yes_no is a documented edge case in
  // numeric_signals_design.md §4 — admins can compare answer_number 0/1
  // against a literal via curl/SQL). The UI deliberately shows ONLY
  // numeric questions to keep the form unambiguous — yes_no comparisons
  // are an advanced workaround, not something we want to surface in the
  // primary admin flow.
  Widget _buildNumericBlock() {
    // Filter to numeric-type questions only (see note above).
    final numericOnly = widget.numericQuestions
        .where((q) => (q['qType'] as String?) == 'numeric')
        .toList();

    return ExpansionTile(
      initiallyExpanded: _anyNumericFieldSet,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(vertical: 6),
      title: const Row(children: [
        Icon(Icons.functions_rounded, size: 16, color: Color(0xFF7C3AED)),
        Gap(6),
        Text('Numeric condition (optional)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
      children: [
        if (numericOnly.isEmpty)
          const Text(
            'No numeric questions reachable from this quiz through a '
            'shared workflow. Add a numeric-type question to a workflow '
            'that also includes this quiz.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          )
        else ...[
          DropdownButtonFormField<String?>(
            // CAUTION: do NOT use `initialValue:` here. In current Flutter,
            // `initialValue` is a one-shot — it's only applied when the
            // widget is first constructed, so subsequent setState updates
            // to _numericQuestionId don't refresh the visible selection.
            // The deprecated-but-functional `value:` parameter acts as a
            // controlled value that re-syncs on every rebuild, which is
            // what we want here (and what the rest of this file uses —
            // see _RuleDialogState's signal dropdown). Worth swapping for
            // a Key-based pattern when Flutter drops `value:` entirely.
            // ignore: deprecated_member_use
            value: _numericQuestionId,
            decoration: const InputDecoration(
              labelText: 'Numeric question',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('—', style: TextStyle(fontSize: 13)),
              ),
              ...numericOnly.map((q) {
                final qNum = q['questionNumber'] as int;
                final qText = q['questionText'] as String;
                return DropdownMenuItem<String?>(
                  value: q['id'] as String,
                  child: Text(
                    'Q$qNum  $qText',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (v) => setState(() => _numericQuestionId = v),
          ),
          const Gap(10),
          Row(children: [
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<String?>(
                // Same controlled-value pattern as the question dropdown
                // above. `initialValue:` would lock the displayed op to
                // its construction-time value; `value:` re-syncs on
                // every rebuild.
                // ignore: deprecated_member_use
                value: _numericOp,
                decoration: const InputDecoration(
                  labelText: 'Op',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                // `selectedItemBuilder` lets the COLLAPSED field show
                // just the compact symbol (so the narrow 110-pt slot
                // keeps fitting alongside the wider Value field), while
                // the OPEN menu shows the full descriptive label so
                // admins know what each symbol means without memorising.
                selectedItemBuilder: (context) => const [
                  Align(alignment: AlignmentDirectional.centerStart,
                      child: Text('—')),
                  Align(alignment: AlignmentDirectional.centerStart,
                      child: Text('<',  style: TextStyle(fontWeight: FontWeight.w700))),
                  Align(alignment: AlignmentDirectional.centerStart,
                      child: Text('≤',  style: TextStyle(fontWeight: FontWeight.w700))),
                  Align(alignment: AlignmentDirectional.centerStart,
                      child: Text('=',  style: TextStyle(fontWeight: FontWeight.w700))),
                  Align(alignment: AlignmentDirectional.centerStart,
                      child: Text('≠',  style: TextStyle(fontWeight: FontWeight.w700))),
                  Align(alignment: AlignmentDirectional.centerStart,
                      child: Text('≥',  style: TextStyle(fontWeight: FontWeight.w700))),
                  Align(alignment: AlignmentDirectional.centerStart,
                      child: Text('>',  style: TextStyle(fontWeight: FontWeight.w700))),
                ],
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— (no operator)',
                        style: TextStyle(color: Color(0xFF6B7280))),
                  ),
                  DropdownMenuItem<String?>(
                    value: '<',
                    child: _OpItem(symbol: '<',  label: 'less than'),
                  ),
                  DropdownMenuItem<String?>(
                    value: '<=',
                    child: _OpItem(symbol: '≤',  label: 'less than or equal'),
                  ),
                  DropdownMenuItem<String?>(
                    value: '=',
                    child: _OpItem(symbol: '=',  label: 'equals'),
                  ),
                  DropdownMenuItem<String?>(
                    value: '!=',
                    child: _OpItem(symbol: '≠',  label: 'not equal'),
                  ),
                  DropdownMenuItem<String?>(
                    value: '>=',
                    child: _OpItem(symbol: '≥',  label: 'greater than or equal'),
                  ),
                  DropdownMenuItem<String?>(
                    value: '>',
                    child: _OpItem(symbol: '>',  label: 'greater than'),
                  ),
                ],
                onChanged: (v) => setState(() => _numericOp = v),
              ),
            ),
            const Gap(10),
            Expanded(
              child: TextField(
                controller: _numericValueCtrl,
                decoration: const InputDecoration(
                  labelText: 'Value',
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'e.g. 10000000',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const Gap(6),
          const Text(
            'When set, the signal additionally requires the user\'s answer '
            'to satisfy "answer  op  value". Leave all three blank for a '
            'pick-only signal.',
            style: TextStyle(
                fontSize: 10.5, color: Color(0xFF6B7280), height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const Gap(4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
      ],
    );
  }

  Widget _buildOptionChips() {
    // If no group data, fall back to flat alphabetical list
    if (widget.optionGroups.isEmpty) {
      final entries = widget.optionLabels.entries
          .where((e) =>
              _search.isEmpty ||
              e.value.toLowerCase().contains(_search) ||
              e.key.toLowerCase().contains(_search))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      if (entries.isEmpty) {
        return const Text('No options match.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)));
      }
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: entries.map((e) => _buildChip(e.key, e.value)).toList(),
      );
    }

    // Grouped display — one section per question
    final sections = <Widget>[];
    for (final group in widget.optionGroups) {
      final filteredIds = group.optionIds.where((id) {
        if (_search.isEmpty) return true;
        final label = widget.optionLabels[id] ?? '';
        return label.toLowerCase().contains(_search) ||
            id.toLowerCase().contains(_search);
      }).toList();
      if (filteredIds.isEmpty) continue;

      sections.addAll([
        // ── Group header ─────────────────────────────────
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.blue.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Q${group.questionNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  group.questionText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // ── Chips for this question ───────────────────────
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: filteredIds
              .map((id) =>
                  _buildChip(id, widget.optionLabels[id] ?? id.substring(0, 8)))
              .toList(),
        ),
      ]);
    }

    if (sections.isEmpty) {
      return const Text('No options match.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _buildChip(String id, String label) {
    final isReq = _required.contains(id);
    final isExc = _excluded.contains(id);
    final color = isReq
        ? const Color(0xFF2563EB)
        : isExc
            ? const Color(0xFFDC2626)
            : AppColors.muted;
    final bg = isReq
        ? const Color(0xFFDBEAFE)
        : isExc
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFF3F4F6);
    return Tooltip(
      message: id,
      waitDuration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: () => _toggleOption(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isReq || isExc) ...[
                Icon(
                  isReq
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 12,
                  color: color,
                ),
                const Gap(4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight:
                      (isReq || isExc) ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSummary() {
    if (_required.isEmpty && _excluded.isEmpty) {
      return const Text('No options selected yet.',
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_required.isNotEmpty)
          Text(
            'Required (${_required.length}): ${_required.map((id) => widget.optionLabels[id] ?? id.substring(0, 8)).join(', ')}',
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w600),
          ),
        if (_excluded.isNotEmpty)
          Text(
            'Excluded (${_excluded.length}): ${_excluded.map((id) => widget.optionLabels[id] ?? id.substring(0, 8)).join(', ')}',
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

// ── Rule Dialog ───────────────────────────────────────────────
class _RuleDialog extends StatefulWidget {
  final Dio dio;
  final String quizId;
  final List<Map<String, dynamic>> signals;
  final Map<String, String> optionLabels;
  final Map<String, dynamic>? initial;
  final VoidCallback onSaved;

  const _RuleDialog({
    required this.dio,
    required this.quizId,
    required this.signals,
    required this.optionLabels,
    this.initial,
    required this.onSaved,
  });

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priorityCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _conditionCtrl;

  bool _saving = false;
  bool _jsonViewMode = true;
  String? _error;

  bool get _isEdit => widget.initial != null;

  // Quick-pick suggestions for the Result label field. The field itself
  // accepts ANY string — these are just one-tap shortcuts. Admins can
  // type custom labels (e.g. SMALL_BUSINESS for the severity engine,
  // DPO_REQUIRED, CRITICAL_BREACH, etc.) without needing a code change.
  // Order is the order the chips render in.
  static const _kLabels = [
    'INDIVIDUAL', 'HIGH', 'MEDIUM', 'BASIC', 'SMALL_BUSINESS',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _priorityCtrl =
        TextEditingController(text: r?['priority']?.toString() ?? '');
    _labelCtrl =
        TextEditingController(text: r?['resultLabel'] as String? ?? 'BASIC');
    _descCtrl =
        TextEditingController(text: r?['description'] as String? ?? '');
    final cond = r?['condition'];
    _conditionCtrl = TextEditingController(
      text: cond != null
          ? const JsonEncoder.withIndent('  ').convert(cond)
          : '{\n  "always": true\n}',
    );
  }

  @override
  void dispose() {
    _priorityCtrl.dispose();
    _labelCtrl.dispose();
    _descCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  /// Quick-pick chip strip under the Result-label field. The field accepts
  /// any string; these are just one-tap shortcuts to common labels.
  Widget _buildLabelSuggestions() {
    final current = _labelCtrl.text.trim().toUpperCase();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: _kLabels.map((l) {
        final selected = current == l.toUpperCase();
        return ChoiceChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _labelColor(l), shape: BoxShape.circle,
              ),
            ),
            const Gap(6),
            Text(l, style: const TextStyle(
                fontSize: 11, fontFamily: 'monospace')),
          ]),
          selected: selected,
          onSelected: (_) => setState(() {
            _labelCtrl.text = l;
            _labelCtrl.selection = TextSelection.collapsed(
                offset: _labelCtrl.text.length);
          }),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> condition;
    try {
      condition = json.decode(_conditionCtrl.text) as Map<String, dynamic>;
    } catch (_) {
      setState(() => _error = 'Condition is not valid JSON.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final body = {
      'priority': int.parse(_priorityCtrl.text.trim()),
      'resultLabel': _labelCtrl.text.trim(),
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'condition': condition,
    };

    try {
      if (_isEdit) {
        await widget.dio.put<dynamic>(
          '/quizzes/${widget.quizId}/result-rules/${widget.initial!['id']}',
          data: body,
        );
      } else {
        await widget.dio.post<dynamic>(
          '/quizzes/${widget.quizId}/result-rules',
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEdit ? 'Edit Rule' : 'New Rule'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _priorityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Priority *',
                          hintText: '10, 20, 30…',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Required';
                          if (int.tryParse(v!.trim()) == null) return 'Number';
                          return null;
                        },
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 3,
                      // Free-text result label. The dropdown restriction was
                      // a UI-only limit — the backend has always accepted any
                      // string. Common labels are shown as quick-pick chips
                      // below (see _buildLabelSuggestions). Custom labels
                      // render with a purple fallback in _labelColor/_labelBg.
                      child: TextFormField(
                        controller: _labelCtrl,
                        decoration: InputDecoration(
                          labelText: 'Result label *',
                          border: const OutlineInputBorder(),
                          // Live color dot reflects what the user typed.
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 4),
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: _labelColor(_labelCtrl.text.trim()),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                              minWidth: 0, minHeight: 0),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                        // Rebuild so the color dot refreshes as the user types.
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                // Quick-pick chips for common labels — tap to fill the field.
                _buildLabelSuggestions(),
                const Gap(12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const Gap(12),
                // Available signals reference
                if (widget.signals.isNotEmpty) ...[
                  const Text('Available signals (tap to insert):',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const Gap(4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: widget.signals.map((s) {
                      final name = s['signalName'] as String;
                      return GestureDetector(
                        onTap: () {
                          final insert = '{ "signal": "$name" }';
                          _conditionCtrl.text = insert;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kGrad1.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: _kGrad1.withOpacity(0.2)),
                          ),
                          child: Text(name,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: _kGrad1,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                  const Gap(8),
                ],
                Row(
                  children: [
                    const Text('Condition (JSON) *',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: Icon(
                        _jsonViewMode
                            ? Icons.edit_outlined
                            : Icons.account_tree_outlined,
                        size: 14,
                      ),
                      label: Text(_jsonViewMode ? 'Edit JSON' : 'JSON View'),
                      onPressed: () {
                        if (!_jsonViewMode) {
                          // switching TO view — validate first
                          try {
                            json.decode(_conditionCtrl.text);
                            setState(() => _jsonViewMode = true);
                          } catch (_) {
                            setState(() => _error =
                                'Fix JSON errors before switching to view.');
                          }
                        } else {
                          setState(() => _jsonViewMode = false);
                        }
                      },
                    ),
                  ],
                ),
                const Gap(4),
                if (_jsonViewMode)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: _JsonTreeView(
                      jsonText: _conditionCtrl.text,
                      signals: widget.signals,
                      optionLabels: widget.optionLabels,
                    ),
                  )
                else
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextFormField(
                      controller: _conditionCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '{ "signal": "is_public_body" }',
                      ),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      maxLines: 10,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        try {
                          json.decode(v!);
                        } catch (_) {
                          return 'Invalid JSON';
                        }
                        return null;
                      },
                    ),
                  ),
                if (_error != null) ...[
                  const Gap(8),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ── JSON Tree View ─────────────────────────────────────────────
class _JsonTreeView extends StatefulWidget {
  final String jsonText;
  final List<Map<String, dynamic>> signals;
  final Map<String, String> optionLabels;

  const _JsonTreeView({
    required this.jsonText,
    this.signals = const [],
    this.optionLabels = const {},
  });

  @override
  State<_JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<_JsonTreeView> {
  late dynamic _parsed;
  final Set<String> _expanded = {'root'};

  @override
  void initState() {
    super.initState();
    try {
      _parsed = json.decode(widget.jsonText);
    } catch (_) {
      _parsed = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parsed == null) {
      return const Text('Invalid JSON',
          style: TextStyle(color: AppColors.danger, fontSize: 12));
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _buildValue(_parsed, 'root', 0),
      ),
    );
  }

  Widget _buildValue(dynamic value, String path, int depth,
      {String? parentKey}) {
    if (value is Map<String, dynamic>) return _buildObject(value, path, depth);
    if (value is List) return _buildArray(value, path, depth);
    return _buildLeaf(value, parentKey: parentKey);
  }

  Widget _buildObject(Map<String, dynamic> obj, String path, int depth) {
    if (obj.isEmpty) return _codeText('{}', AppColors.muted);
    final isExpanded = _expanded.contains(path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) _expanded.remove(path);
            else _expanded.add(path);
          }),
          borderRadius: BorderRadius.circular(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 16,
                color: AppColors.muted,
              ),
              _codeText(
                isExpanded
                    ? '{'
                    : '{ ${obj.length} key${obj.length != 1 ? 's' : ''} }',
                AppColors.muted,
              ),
            ],
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...obj.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: [
                          _codeText('"${e.key}": ', AppColors.blue,
                              bold: true),
                          _buildValue(e.value, '$path.${e.key}', depth + 1,
                              parentKey: e.key),
                        ],
                      ),
                    )),
                _codeText('}', AppColors.muted),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildArray(List<dynamic> arr, String path, int depth) {
    if (arr.isEmpty) return _codeText('[]', AppColors.muted);
    final isExpanded = _expanded.contains(path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) _expanded.remove(path);
            else _expanded.add(path);
          }),
          borderRadius: BorderRadius.circular(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 16,
                color: AppColors.muted,
              ),
              _codeText(
                isExpanded
                    ? '['
                    : '[ ${arr.length} item${arr.length != 1 ? 's' : ''} ]',
                AppColors.muted,
              ),
            ],
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...arr.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: [
                          _codeText('${e.key}: ', AppColors.muted),
                          _buildValue(e.value, '$path[${e.key}]', depth + 1),
                        ],
                      ),
                    )),
                _codeText(']', AppColors.muted),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLeaf(dynamic value, {String? parentKey}) {
    if (value == null) {
      return _codeText('null', const Color(0xFF9CA3AF), italic: true);
    } else if (value is bool) {
      return _codeText('$value', const Color(0xFF7C3AED));
    } else if (value is num) {
      return _codeText('$value', const Color(0xFF2563EB));
    }

    // String leaf
    final strVal = '$value';

    // If this is a signal value, show tooltip with required/excluded options
    if (parentKey == 'signal' && widget.signals.isNotEmpty) {
      final sig = widget.signals.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s?['signalName'] == strVal,
            orElse: () => null,
          );
      if (sig != null) {
        final required = (sig['requiredOptionIds'] as List? ?? [])
            .cast<String>()
            .map((id) => widget.optionLabels[id] ?? id)
            .toList();
        final excluded = (sig['excludedOptionIds'] as List? ?? [])
            .cast<String>()
            .map((id) => widget.optionLabels[id] ?? id)
            .toList();

        final tooltipLines = <String>[];
        if (required.isNotEmpty) {
          tooltipLines.add('Required:');
          tooltipLines.add('─────────────');
          for (var i = 0; i < required.length; i++) {
            tooltipLines.add('${i + 1}. ${required[i]}');
          }
        }
        if (excluded.isNotEmpty) {
          if (tooltipLines.isNotEmpty) tooltipLines.add('');
          tooltipLines.add('Excluded:');
          for (var i = 0; i < excluded.length; i++) {
            tooltipLines.add('${i + 1}. ${excluded[i]}');
          }
        }
        if (tooltipLines.isEmpty) {
          tooltipLines.add('No required or excluded options defined.');
        }

        return Tooltip(
          message: tooltipLines.join('\n'),
          preferBelow: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                  color: const Color(0xFF16A34A).withOpacity(0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _codeText('"$strVal"', const Color(0xFF16A34A)),
                const SizedBox(width: 4),
                const Icon(Icons.info_outline_rounded,
                    size: 11, color: Color(0xFF16A34A)),
              ],
            ),
          ),
        );
      }
    }

    return _codeText('"$strVal"', const Color(0xFF16A34A));
  }

  Widget _codeText(String text, Color color,
      {bool bold = false, bool italic = false}) =>
      Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: color,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      );
}

// ── Step 38: Operator dropdown item ──────────────────────────────────────
// Used inside the numeric-signal form's "Op" dropdown to render each open-
// menu item as `<bold-symbol>   <plain-description>`. The COLLAPSED field
// shows only the symbol via `selectedItemBuilder` so the narrow Op slot
// keeps fitting next to the wider Value field.
class _OpItem extends StatelessWidget {
  final String symbol;
  final String label;
  const _OpItem({required this.symbol, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 22,
        child: Text(symbol,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      Text(label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
    ]);
  }
}
