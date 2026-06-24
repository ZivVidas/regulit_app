import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_localizations.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = AppColors.blue;
const _kGrad2 = Color(0xFF2D6BB0);

// ── QType helpers ─────────────────────────────────────────────
const _kQTypes = [
  ('yes_no',        'Yes / No'),
  ('one_pick',      'One Pick'),
  ('multiple_pick', 'Multiple Pick'),
  ('text',          'Free Text'),
  ('numeric',       'Numeric'),
];

// ── Step 42: per-question fine aggregation config ─────────────
// Mirrors `quiz_questions.fine_aggregation_strategy` JSONB shape
// (see gap_group_fine_aggregation_design.md §3.2).
class _FineAggregationRule {
  final String signal;     // workflow_signals.signal_name (free text in v1)
  final String strategy;   // 'sum' | 'max' | 'min'
  _FineAggregationRule({required this.signal, required this.strategy});

  factory _FineAggregationRule.fromJson(Map<String, dynamic> j) =>
      _FineAggregationRule(
        signal: j['signal'] as String? ?? '',
        strategy: j['strategy'] as String? ?? 'max',
      );

  Map<String, dynamic> toJson() => {'signal': signal, 'strategy': strategy};
}

class _FineAggregationConfig {
  final List<_FineAggregationRule> rules;
  final String? defaultStrategy;  // 'sum' | 'max' | 'min' | null
  _FineAggregationConfig({this.rules = const [], this.defaultStrategy});

  /// Empty = no rules AND no default. Caller should send `null` for the
  /// whole field so the DB column stays NULL and the calculator falls
  /// through to the is_data_environment_question default.
  bool get isEmpty => rules.isEmpty && defaultStrategy == null;

  factory _FineAggregationConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return _FineAggregationConfig();
    return _FineAggregationConfig(
      rules: ((j['rules'] ?? const []) as List)
          .map((e) => _FineAggregationRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultStrategy: j['default'] as String?,
    );
  }

  /// Returns null when empty so the API payload omits the column.
  Map<String, dynamic>? toJson() {
    if (isEmpty) return null;
    return {
      'rules': rules.map((r) => r.toJson()).toList(),
      if (defaultStrategy != null) 'default': defaultStrategy,
    };
  }
}

// ── Step 45: per-question fine cap (Stage 2 of group fine calculator) ─
// Mirrors `quiz_questions.fine_cap` JSONB shape (see
// gap_group_fine_aggregation_design.md §3.4). A rule's `limit: null` is
// an explicit exemption — that rule "matches" and disables capping for
// the question (does NOT fall through to the next rule).
class _FineCapRule {
  final String signal;
  final num? limit;
  _FineCapRule({required this.signal, this.limit});

  factory _FineCapRule.fromJson(Map<String, dynamic> j) => _FineCapRule(
        signal: j['signal'] as String? ?? '',
        limit: j['limit'] as num?,
      );

  /// We always include the `limit` key — `null` is meaningful (exemption),
  /// distinct from "absent" (which would be ambiguous on the wire).
  Map<String, dynamic> toJson() => {'signal': signal, 'limit': limit};
}

class _FineCapConfig {
  final List<_FineCapRule> rules;
  final num? defaultLimit;   // null = no cap when no rule matches
  _FineCapConfig({this.rules = const [], this.defaultLimit});

  /// Empty = no rules AND no default. Caller should send `null` so the
  /// JSONB column stays NULL and Stage 2 stays a no-op for this question.
  bool get isEmpty => rules.isEmpty && defaultLimit == null;

  factory _FineCapConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return _FineCapConfig();
    return _FineCapConfig(
      rules: ((j['rules'] ?? const []) as List)
          .map((e) => _FineCapRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultLimit: j['default'] as num?,
    );
  }

  Map<String, dynamic>? toJson() {
    if (isEmpty) return null;
    return {
      'rules': rules.map((r) => r.toJson()).toList(),
      if (defaultLimit != null) 'default': defaultLimit,
    };
  }
}

bool _isPickType(String? t) => t == 'one_pick' || t == 'multiple_pick';

String _qtypeLabel(String? v) =>
    _kQTypes.firstWhere((t) => t.$1 == v, orElse: () => (v ?? '', v ?? '')).$2;

Color _qtypeColor(String? v) => switch (v) {
      'yes_no'        => const Color(0xFF059669),
      'one_pick'      => const Color(0xFF2563EB),
      'multiple_pick' => const Color(0xFF7C3AED),
      'text'          => const Color(0xFFEA580C),
      'numeric'       => const Color(0xFF0891B2), // cyan
      _               => AppColors.muted,
    };

// ── State ─────────────────────────────────────────────────────
class _QState {
  final List<Map<String, dynamic>> items;
  final int total;
  final bool isLoading;
  final String? error;

  const _QState({
    this.items = const [],
    this.total = 0,
    this.isLoading = true,
    this.error,
  });

  _QState copyWith({
    List<Map<String, dynamic>>? items,
    int? total,
    bool? isLoading,
    String? error,
  }) =>
      _QState(
        items: items ?? this.items,
        total: total ?? this.total,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _QNotifier extends StateNotifier<_QState> {
  final Dio _dio;
  final String quizId;
  final String stepId;

  _QNotifier(this._dio, this.quizId, this.stepId) : super(const _QState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/quizzes/$quizId/steps/$stepId/questions',
        queryParameters: {'page': 1, 'page_size': 200},
      );
      final data = res.data!;
      state = state.copyWith(
        isLoading: false,
        items: (data['items'] as List).cast<Map<String, dynamic>>(),
        total: data['total'] as int,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteQuestion(
      String qId, List<Map<String, dynamic>> options) async {
    final base = '/quizzes/$quizId/steps/$stepId/questions';
    // Delete each option (embedded in the already-loaded question object)
    for (final opt in options) {
      try {
        await _dio.delete<dynamic>('$base/$qId/options/${opt['id']}');
      } catch (_) {}
    }
    await _dio.delete<dynamic>('$base/$qId');
    await load();
  }

  Future<void> toggleActive(String qId, bool currentlyActive) async {
    await _dio.patch<dynamic>(
      '/quizzes/$quizId/steps/$stepId/questions/$qId',
      data: {'is_active': !currentlyActive},
    );
    await load();
  }
}

// Provider keyed by (quizId, stepId)
final _qProviderFamily = StateNotifierProvider.autoDispose
    .family<_QNotifier, _QState, (String, String)>(
  (ref, ids) => _QNotifier(ref.watch(dioProvider), ids.$1, ids.$2),
);

// ── Screen ────────────────────────────────────────────────────
class QuizQuestionsScreen extends ConsumerWidget {
  final String quizId;
  final String stepId;
  final String stepName;
  final String quizName;

  const QuizQuestionsScreen({
    super.key,
    required this.quizId,
    required this.stepId,
    required this.stepName,
    required this.quizName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = (quizId, stepId);
    final s = ref.watch(_qProviderFamily(ids));
    final dio = ref.read(dioProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────
          _Header(
            stepName: stepName,
            quizName: quizName,
            questionCount: s.isLoading ? null : s.total,
            onBack: () => context.pop(),
            onAdd: () => _showForm(
              context, ref, dio, ids, s.total + 1, null),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),

          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: s.isLoading
                ? const _ShimmerList()
                : s.error != null
                    ? _ErrorView(
                        message: s.error!,
                        onRetry: () =>
                            ref.read(_qProviderFamily(ids).notifier).load(),
                      )
                    : s.items.isEmpty
                        ? _EmptyView(stepName: stepName)
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: s.items.length,
                            itemBuilder: (_, i) {
                              final q = s.items[i];
                              return _QuestionCard(
                                question: q,
                                index: i,
                                onEdit: () => _showForm(
                                    context, ref, dio, ids, i + 1, q),
                                onDelete: () => _confirmDelete(
                                    context, ref, dio, ids,
                                    q['id'] as String,
                                    q['questionNumber'].toString(),
                                    (q['options'] as List?)
                                            ?.cast<Map<String, dynamic>>() ??
                                        []),
                                onToggleActive: () => ref
                                    .read(_qProviderFamily(ids).notifier)
                                    .toggleActive(
                                      q['id'] as String,
                                      q['isActive'] as bool? ?? true,
                                    ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Dio dio,
      (String, String) ids, int nextNum, Map<String, dynamic>? q) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuestionFormDialog(
        dio: dio,
        quizId: quizId,
        stepId: stepId,
        initialQuestion: q,
        nextNumber: nextNum,
        onSaved: () => ref.read(_qProviderFamily(ids).notifier).load(),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Dio dio,
    (String, String) ids,
    String qId,
    String num,
    List<Map<String, dynamic>> options,
  ) async {
    // ── 1. Check if any answers exist for this question ──────────
    bool hasAnswers = false;
    try {
      final res = await dio.get<Map<String, dynamic>>(
        '/answers',
        queryParameters: {
          'quiz_id': quizId,
          'question_id': qId,
          'page_size': 1,
        },
      );
      final total = res.data?['total'] as int? ?? 0;
      hasAnswers = total > 0;
    } catch (_) {
      // If the check fails, fall through to the normal confirmation.
    }

    if (!context.mounted) return;

    // ── 2a. Answers exist — block deletion ───────────────────────
    if (hasAnswers) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.lock_outline_rounded,
                color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            const Text('Cannot delete'),
          ]),
          content: Text(
            'Question #$num has recorded answers from customers '
            'and cannot be deleted.\n\n'
            'You can deactivate it instead to hide it from future audits.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // ── 2b. No answers — show regular confirmation ───────────────
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete question'),
        content: Text('Question #$num will be permanently deleted.'),
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
    if (ok == true) {
      try {
        await ref
            .read(_qProviderFamily(ids).notifier)
            .deleteQuestion(qId, options);
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

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String stepName;
  final String quizName;
  final int? questionCount;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  const _Header({
    required this.stepName,
    required this.quizName,
    required this.questionCount,
    required this.onBack,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = questionCount == null
        ? 'Loading…'
        : '$questionCount question${questionCount == 1 ? '' : 's'} · $quizName';

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
                tooltip: 'Back to Steps',
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.help_outline_rounded,
                    color: Colors.white, size: 22),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stepName,
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
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
              _AddButton(onTap: onAdd),
            ],
          ),
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
            const Text('Add Question',
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

// ── Question Card ─────────────────────────────────────────────
class _QuestionCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final isActive = q['isActive'] as bool? ?? true;
    final qtype = q['qType'] as String? ?? '';
    final color = isActive ? _qtypeColor(qtype) : AppColors.muted;
    final hasEvidence = (q['evidenceCondition'] as String?)?.isNotEmpty ?? false;
    final requiresEvidence = q['requiresEvidence'] as bool? ?? false;
    final evidencePrompt = q['evidencePrompt'] as String?;
    final options = (q['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isPickType = _isPickType(qtype);
    final conditionLabels =
        (q['conditionToShowQuestion'] as List?)?.cast<String>() ?? [];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? color.withOpacity(0.14)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _hovered ? 20 : 6,
              offset: Offset(0, _hovered ? 6 : 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question number badge
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${q['questionNumber'] ?? widget.index + 1}',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const Gap(12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((q['title'] as String?)?.isNotEmpty ?? false) ...[
                      Text(
                        q['title'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color.withOpacity(0.75),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const Gap(2),
                    ],
                    Text(
                      q['questionText'] as String? ?? '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        height: 1.4,
                      ),
                    ),
                    const Gap(6),
                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // QType badge
                        _Badge(
                          label: _qtypeLabel(qtype),
                          color: color,
                          icon: null,
                        ),
                        // Inactive badge
                        if (!isActive)
                          _Badge(
                            label: 'INACTIVE',
                            color: AppColors.muted,
                            bgColor: const Color(0xFFF1F5F9),
                            borderColor: const Color(0xFFCBD5E1),
                            icon: Icons.pause_circle_outline_rounded,
                          ),
                        // Evidence condition badge
                        if (hasEvidence)
                          _Badge(
                            label: 'Evidence if "${q['evidenceCondition']}"',
                            color: const Color(0xFFD97706),
                            bgColor: const Color(0xFFFEF3C7),
                            borderColor: const Color(0xFFF59E0B),
                            icon: Icons.attach_file_rounded,
                          ),
                        // Requires evidence badge
                        if (requiresEvidence)
                          _Badge(
                            label: 'Evidence required',
                            color: const Color(0xFFD97706),
                            bgColor: const Color(0xFFFEF3C7),
                            borderColor: const Color(0xFFF59E0B),
                            icon: Icons.upload_file_rounded,
                          ),
                        // Condition labels badge
                        if (conditionLabels.isNotEmpty)
                          _Badge(
                            label: 'Show if: ${conditionLabels.join(' / ')}',
                            color: const Color(0xFF2563EB),
                            bgColor: const Color(0xFFDBEAFE),
                            borderColor: const Color(0xFF3B82F6),
                            icon: Icons.visibility_rounded,
                          ),
                        // Options count badge for pick types
                        if (isPickType && options.isNotEmpty)
                          _Badge(
                            label: '${options.length} option${options.length == 1 ? '' : 's'}',
                            color: color,
                            icon: Icons.list_rounded,
                          ),
                      ],
                    ),
                    // Evidence prompt text
                    if (requiresEvidence &&
                        evidencePrompt != null &&
                        evidencePrompt.isNotEmpty) ...[
                      const Gap(4),
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 11, color: Color(0xFFD97706)),
                          const Gap(4),
                          Expanded(
                            child: Text(
                              evidencePrompt,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFD97706),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Inline options chips (collapsed by default, shown when hovered)
                    if (isPickType && options.isNotEmpty) ...[
                      const Gap(6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: options.asMap().entries.map((e) {
                          final idx = e.key;
                          final opt = e.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: color.withOpacity(0.2)),
                            ),
                            child: Text(
                              '${idx + 1}. ${opt['optionText']}',
                              style: TextStyle(
                                color: color.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
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
                    tooltip: 'Edit',
                    onTap: widget.onEdit,
                  ),
                  const Gap(2),
                  _ActionIcon(
                    icon: isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    color: isActive
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
                    tooltip: isActive ? 'Deactivate' : 'Activate',
                    onTap: widget.onToggleActive,
                  ),
                  const Gap(2),
                  _ActionIcon(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    tooltip: 'Delete',
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 350.ms,
          delay: (widget.index * 50).ms,
          curve: Curves.easeOut,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 350.ms,
          delay: (widget.index * 50).ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ── Reusable badge ────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;
  final Color? borderColor;
  final IconData? icon;

  const _Badge({
    required this.label,
    required this.color,
    this.bgColor,
    this.borderColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor ?? color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: borderColor ?? color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const Gap(3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          height: 80,
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
  final String stepName;
  const _EmptyView({required this.stepName});

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
          child: Icon(Icons.help_outline_rounded,
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
          'No questions yet.\nAdd the first question for "$stepName".',
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
        )
            .animate(onPlay: (c) => c.repeat())
            .shake(duration: 600.ms, delay: 1000.ms, hz: 3),
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

// ── Question Form Dialog ──────────────────────────────────────
// Handles both question fields and pick options (add/remove inline).
// After saving the question, syncs options via the options API.
class _QuestionFormDialog extends StatefulWidget {
  final Dio dio;
  final String quizId;
  final String stepId;
  final Map<String, dynamic>? initialQuestion;
  final int nextNumber;
  final VoidCallback onSaved; // called after everything is saved → triggers reload

  const _QuestionFormDialog({
    required this.dio,
    required this.quizId,
    required this.stepId,
    this.initialQuestion,
    required this.nextNumber,
    required this.onSaved,
  });

  @override
  State<_QuestionFormDialog> createState() => _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<_QuestionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _numCtrl;
  late final TextEditingController _evidCtrl;
  late final TextEditingController _evidPromptCtrl;
  // Gap-report fields (step 34)
  late final TextEditingController _legalBasisCtrl;
  late final TextEditingController _dueDaysCtrl;
  String? _severity;   // null | 'critical' | 'high' | 'medium' | 'low'
  // Step 36: per-environment question flag. When true the survey UI
  // renders one card with N rows (one per customer_data_environment).
  bool _isDataEnvQuestion = false;
  // Step 42: per-question fine aggregation rules. Default-empty config →
  // calculator falls through to is_data_environment_question default.
  _FineAggregationConfig _fineAgg = _FineAggregationConfig();
  // Step 44: per-question fine by classification label. Map of label → fine
  // in NIS. Empty map → JSONB column stays NULL and the resolver returns
  // None for tasks tied to this question.
  Map<String, num> _fineByLabel = {};
  // Step 45: per-question Stage-2 cap. Empty config → JSONB column stays
  // NULL and Stage 2 is a no-op for this question.
  _FineCapConfig _fineCap = _FineCapConfig();
  late String _qtype;
  late bool _requiresEvidence;

  // Condition-to-show labels (e.g. ["MEDIUM", "HIGH"])
  late final List<String> _conditionLabels;
  final TextEditingController _conditionInputCtrl = TextEditingController();

  // Pick options — parallel lists: controller + existing server ID (null = new)
  final List<TextEditingController> _optionCtrls = [];
  final List<String?> _optionIds = [];

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialQuestion != null;
  String get _baseUrl =>
      '/quizzes/${widget.quizId}/steps/${widget.stepId}/questions';

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    _textCtrl = TextEditingController(text: q?['questionText'] as String? ?? '');
    _titleCtrl = TextEditingController(text: q?['title'] as String? ?? '');
    _numCtrl = TextEditingController(
        text: (q?['questionNumber'] ?? widget.nextNumber).toString());
    _evidCtrl =
        TextEditingController(text: q?['evidenceCondition'] as String? ?? '');
    _requiresEvidence = q?['requiresEvidence'] as bool? ?? false;
    _evidPromptCtrl =
        TextEditingController(text: q?['evidencePrompt'] as String? ?? '');
    _qtype = q?['qType'] as String? ?? 'yes_no';
    _conditionLabels = List<String>.from(
        (q?['conditionToShowQuestion'] as List?)?.cast<String>() ?? []);
    _legalBasisCtrl =
        TextEditingController(text: q?['legalBasis'] as String? ?? '');
    _dueDaysCtrl = TextEditingController(
        text: q?['dueDays'] != null ? '${q!['dueDays']}' : '');
    _severity = q?['severity'] as String?;
    _isDataEnvQuestion =
        (q?['isDataEnvironmentQuestion'] as bool?) ?? false;
    // Step 42 — pre-fill the config from the saved JSON (null-safe).
    _fineAgg = _FineAggregationConfig.fromJson(
      q?['fineAggregationStrategy'] as Map<String, dynamic>?,
    );
    // Step 44 — pre-fill the label → fine map from the saved JSON.
    final fbl = q?['fineByResultLabel'] as Map<String, dynamic>?;
    if (fbl != null) {
      _fineByLabel = {
        for (final e in fbl.entries)
          if (e.value is num) e.key: e.value as num,
      };
    }
    // Step 45 — pre-fill the cap config from the saved JSON (null-safe).
    _fineCap = _FineCapConfig.fromJson(
      q?['fineCap'] as Map<String, dynamic>?,
    );

    // Pre-populate options from existing question data
    final existingOptions =
        (q?['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final opt in existingOptions) {
      _optionCtrls.add(
          TextEditingController(text: opt['optionText'] as String? ?? ''));
      _optionIds.add(opt['id'] as String?);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _titleCtrl.dispose();
    _numCtrl.dispose();
    _evidCtrl.dispose();
    _evidPromptCtrl.dispose();
    _legalBasisCtrl.dispose();
    _dueDaysCtrl.dispose();
    _conditionInputCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addConditionLabel() {
    final label = _conditionInputCtrl.text.trim().toUpperCase();
    if (label.isEmpty || _conditionLabels.contains(label)) {
      _conditionInputCtrl.clear();
      return;
    }
    setState(() {
      _conditionLabels.add(label);
      _conditionInputCtrl.clear();
    });
  }

  void _addOption() {
    setState(() {
      _optionCtrls.add(TextEditingController());
      _optionIds.add(null);
    });
  }

  Future<void> _removeOption(int index) async {
    final existingId = _optionIds[index];

    // If the option is already saved on the server, delete it via API first
    if (existingId != null && _isEdit) {
      final qId = widget.initialQuestion!['id'] as String;
      final optionsBase =
          '/quizzes/${widget.quizId}/steps/${widget.stepId}/questions/$qId/options';
      try {
        await widget.dio.delete<dynamic>('$optionsBase/$existingId');
      } catch (e) {
        if (mounted) {
          setState(() =>
              _error = e.toString().replaceFirst('Exception: ', ''));
        }
        return; // abort removal — option is in use
      }
    }

    final ctrl = _optionCtrls.removeAt(index);
    ctrl.dispose();
    _optionIds.removeAt(index);
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate options for pick types
    if (_isPickType(_qtype)) {
      final nonEmpty = _optionCtrls.where((c) => c.text.trim().isNotEmpty);
      if (nonEmpty.length < 2) {
        setState(() => _error = 'Add at least 2 options for pick questions.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'questionNumber': int.tryParse(_numCtrl.text.trim()) ?? widget.nextNumber,
      'title': _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      'questionText': _textCtrl.text.trim(),
      'qType': _qtype,
      'evidenceCondition': _evidCtrl.text.trim().isEmpty
          ? null
          : _evidCtrl.text.trim(),
      'requiresEvidence': _requiresEvidence,
      'evidencePrompt': _evidPromptCtrl.text.trim().isEmpty
          ? null
          : _evidPromptCtrl.text.trim(),
      'conditionToShowQuestion':
          _conditionLabels.isEmpty ? null : _conditionLabels,
      'legalBasis': _legalBasisCtrl.text.trim().isEmpty
          ? null
          : _legalBasisCtrl.text.trim(),
      'severity': _severity,
      'dueDays': _dueDaysCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_dueDaysCtrl.text.trim()),
      // Step 36
      'isDataEnvironmentQuestion': _isDataEnvQuestion,
      // Step 42 — empty config sends as null → DB column stays NULL.
      'fineAggregationStrategy': _fineAgg.toJson(),
      // Step 44 — empty map sends as null so the JSONB column stays NULL.
      'fineByResultLabel': _fineByLabel.isEmpty ? null : _fineByLabel,
      // Step 45 — empty config sends as null → DB column stays NULL.
      'fineCap': _fineCap.toJson(),
    };

    try {
      // 1. Save question (create or update)
      late String questionId;
      if (_isEdit) {
        final qId = widget.initialQuestion!['id'] as String;
        await widget.dio.put<dynamic>('$_baseUrl/$qId', data: body);
        questionId = qId;
      } else {
        final res =
            await widget.dio.post<Map<String, dynamic>>(_baseUrl, data: body);
        questionId = res.data!['id'] as String;
      }

      // 2. Sync pick options — PUT existing, POST new (no delete-all)
      final optionsBase = '$_baseUrl/$questionId/options';

      if (_isPickType(_qtype)) {
        int order = 0;
        for (int i = 0; i < _optionCtrls.length; i++) {
          final text = _optionCtrls[i].text.trim();
          if (text.isEmpty) continue;
          final id = i < _optionIds.length ? _optionIds[i] : null;
          if (id != null) {
            // Update existing option
            await widget.dio.put<dynamic>('$optionsBase/$id', data: {
              'optionText': text,
              'optionOrder': order,
            });
          } else {
            // Create new option
            await widget.dio.post<dynamic>(optionsBase, data: {
              'optionText': text,
              'optionOrder': order,
            });
          }
          order++;
        }
      }

      widget.onSaved();
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
    final showOptions = _isPickType(_qtype);
    final optionColor = _qtypeColor(_qtype);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // ── Dialog Header ─────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_kGrad1, _kGrad2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Row(children: [
                Icon(
                  _isEdit ? Icons.edit_rounded : Icons.help_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const Gap(10),
                Text(
                  _isEdit ? 'Edit Question' : 'New Question',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),

            // ── Form Body ─────────────────────────────────────
            Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error banner
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

                      // Q# + Type row
                      Row(children: [
                        SizedBox(
                          width: 90,
                          child: _Field(
                            label: 'Q#',
                            ctrl: _numCtrl,
                            required: true,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (int.tryParse(v) == null) return 'Number';
                              return null;
                            },
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Question Type', style: AppTextStyles.label),
                              const Gap(4),
                              DropdownButtonFormField<String>(
                                value: _qtype,
                                decoration:
                                    const InputDecoration(isDense: true),
                                items: _kQTypes
                                    .map((t) => DropdownMenuItem(
                                          value: t.$1,
                                          child: Text(t.$2,
                                              style: AppTextStyles.body),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _qtype = v);
                                },
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const Gap(12),

                      // Title
                      _Field(
                        label: 'Title (optional)',
                        ctrl: _titleCtrl,
                        hint: 'Short heading displayed above the question',
                      ),
                      const Gap(12),

                      // Question text
                      _Field(
                        label: 'Question Text',
                        ctrl: _textCtrl,
                        required: true,
                        maxLines: 3,
                      ),
                      const Gap(12),

                      // Evidence condition
                      _Field(
                        label: 'Evidence Condition (optional)',
                        ctrl: _evidCtrl,
                        hint:
                            'e.g. "yes" — answer that requires evidence upload',
                      ),
                      const Gap(12),

                      // ── Evidence fields ────────────────────────
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Toggle row
                            Row(
                              children: [
                                const Icon(Icons.attach_file_rounded,
                                    size: 14, color: Color(0xFFD97706)),
                                const Gap(6),
                                Expanded(
                                  child: Text(
                                    'Requires Evidence',
                                    style: AppTextStyles.label.copyWith(
                                        color: const Color(0xFFD97706)),
                                  ),
                                ),
                                Switch(
                                  value: _requiresEvidence,
                                  activeColor: const Color(0xFFD97706),
                                  onChanged: (v) =>
                                      setState(() => _requiresEvidence = v),
                                ),
                              ],
                            ),
                            // Prompt field (only when toggled on)
                            if (_requiresEvidence) ...[
                              const Gap(8),
                              _Field(
                                label: 'Evidence Prompt',
                                ctrl: _evidPromptCtrl,
                                hint:
                                    'Instructions shown to user when uploading evidence',
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ── Gap Report Metadata (step 34) ──────────
                      const Gap(12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF7C3AED).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.gavel_rounded,
                                  size: 14, color: Color(0xFF7C3AED)),
                              const Gap(6),
                              Text(
                                'Gap Report Metadata',
                                style: AppTextStyles.label.copyWith(
                                    color: const Color(0xFF7C3AED)),
                              ),
                            ]),
                            const Gap(8),
                            _Field(
                              label: 'Legal basis',
                              ctrl: _legalBasisCtrl,
                              hint:
                                  'e.g. תקנות אבטחת מידע, סעיף 3 — shown in the gap table',
                              maxLines: 2,
                            ),
                            const Gap(8),
                            Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Severity',
                                        style: AppTextStyles.label),
                                    const Gap(4),
                                    DropdownButtonFormField<String?>(
                                      value: _severity,
                                      decoration: const InputDecoration(
                                          isDense: true),
                                      items: const [
                                        DropdownMenuItem(
                                            value: null,
                                            child: Text('— (none)',
                                                style:
                                                    TextStyle(fontSize: 13))),
                                        DropdownMenuItem(
                                            value: 'critical',
                                            child: Text('🔴 critical',
                                                style:
                                                    TextStyle(fontSize: 13))),
                                        DropdownMenuItem(
                                            value: 'high',
                                            child: Text('🟠 high',
                                                style:
                                                    TextStyle(fontSize: 13))),
                                        DropdownMenuItem(
                                            value: 'medium',
                                            child: Text('🟡 medium',
                                                style:
                                                    TextStyle(fontSize: 13))),
                                        DropdownMenuItem(
                                            value: 'low',
                                            child: Text('🟢 low',
                                                style:
                                                    TextStyle(fontSize: 13))),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _severity = v),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(12),
                              SizedBox(
                                width: 130,
                                child: _Field(
                                  label: 'Due days (optional)',
                                  ctrl: _dueDaysCtrl,
                                  hint: '30 / 90 / 180',
                                ),
                              ),
                            ]),
                            // Step 36: per-environment question toggle.
                            // When ON, the survey UI renders this question
                            // once with N rows (one per env), and each
                            // "no" answer spawns its own remediation task
                            // tagged with the env id.
                            const Gap(4),
                            SwitchListTile.adaptive(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: _isDataEnvQuestion,
                              onChanged: (v) =>
                                  setState(() => _isDataEnvQuestion = v),
                              title: Text(
                                AppLocalizations.of(context)
                                    .isDataEnvironmentQuestion,
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              activeThumbColor: const Color(0xFF7C3AED),
                            ),
                            // ── Step 42: fine aggregation across envs ───
                            const Gap(12),
                            _FineAggregationSection(
                              config: _fineAgg,
                              isDataEnvQuestion: _isDataEnvQuestion,
                              onChanged: (next) =>
                                  setState(() => _fineAgg = next),
                            ),
                            // ── Step 44: per-question fine by label ───
                            const Gap(12),
                            _FineByLabelSection(
                              initial: _fineByLabel,
                              onChanged: (next) =>
                                  setState(() => _fineByLabel = next),
                            ),
                            // ── Step 45: Stage-2 per-question cap ──────
                            const Gap(12),
                            _FineCapSection(
                              config: _fineCap,
                              onChanged: (next) =>
                                  setState(() => _fineCap = next),
                            ),
                          ],
                        ),
                      ),

                      // ── Condition to show question ─────────────
                      const Gap(12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF3B82F6).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.visibility_rounded,
                                  size: 14, color: Color(0xFF2563EB)),
                              const Gap(6),
                              Text('Show only when quiz result is',
                                  style: AppTextStyles.label.copyWith(
                                      color: const Color(0xFF2563EB))),
                            ]),
                            const Gap(4),
                            const Text(
                              'Leave empty to always show. Add result labels (e.g. HIGH, MEDIUM) — question is shown only when any quiz result in this session matches one of these labels.',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.muted),
                            ),
                            const Gap(8),
                            // Chip list of current labels
                            if (_conditionLabels.isNotEmpty) ...[
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: _conditionLabels
                                    .asMap()
                                    .entries
                                    .map((e) => Chip(
                                          label: Text(e.value,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1E40AF))),
                                          backgroundColor:
                                              const Color(0xFFDBEAFE),
                                          side: BorderSide.none,
                                          deleteIcon: const Icon(
                                              Icons.close_rounded,
                                              size: 13),
                                          deleteIconColor:
                                              const Color(0xFF3B82F6),
                                          onDeleted: () => setState(() =>
                                              _conditionLabels
                                                  .removeAt(e.key)),
                                          visualDensity:
                                              VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6),
                                        ))
                                    .toList(),
                              ),
                              const Gap(8),
                            ],
                            // Input row to add a new label
                            Row(children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _conditionInputCtrl,
                                  style: AppTextStyles.body.copyWith(
                                      fontSize: 12),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Label (e.g. HIGH)',
                                    hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12),
                                  ),
                                  onFieldSubmitted: (_) =>
                                      _addConditionLabel(),
                                ),
                              ),
                              const Gap(6),
                              IconButton(
                                icon: const Icon(Icons.add_circle_rounded,
                                    size: 20,
                                    color: Color(0xFF2563EB)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                tooltip: 'Add label',
                                onPressed: _addConditionLabel,
                              ),
                            ]),
                          ],
                        ),
                      ),

                      // ── Pick Options section ───────────────────
                      if (showOptions) ...[
                        const Gap(16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: optionColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: optionColor.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.list_rounded,
                                    size: 14, color: optionColor),
                                const Gap(6),
                                Text(
                                  'Answer Options',
                                  style: AppTextStyles.label.copyWith(
                                      color: optionColor),
                                ),
                              ]),
                              const Gap(8),

                              // Option rows
                              ..._optionCtrls.asMap().entries.map((e) {
                                final i = e.key;
                                final ctrl = e.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      // Order badge
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color:
                                              optionColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              color: optionColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Gap(8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: ctrl,
                                          style: AppTextStyles.body,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText: 'Option text…',
                                            hintStyle: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 12),
                                          ),
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                                  ? 'Required'
                                                  : null,
                                        ),
                                      ),
                                      // Remove button
                                      IconButton(
                                        icon: Icon(Icons.close_rounded,
                                            size: 16,
                                            color: Colors.grey[400]),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 28, minHeight: 28),
                                        tooltip: 'Remove option',
                                        onPressed: () => _removeOption(i),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              // Add option button
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: optionColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                                onPressed: _addOption,
                                icon: const Icon(Icons.add_rounded, size: 14),
                                label: const Text('Add option',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            ),

            // ── Actions ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
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
                        : Text(_isEdit ? 'Save Changes' : 'Add Question'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
        begin: const Offset(0.93, 0.93),
        duration: 250.ms,
        curve: Curves.easeOutBack);
  }
}

// ── Reusable field ────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  final int maxLines;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.ctrl,
    this.required = false,
    this.maxLines = 1,
    this.hint,
    this.keyboardType,
    this.validator,
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
          keyboardType: keyboardType,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          validator: validator ??
              (required
                  ? (v) => (v == null || v.isEmpty) ? 'Required' : null
                  : null),
        ),
      ],
    );
  }
}


// ── Step 42 — Fine aggregation editor widget ─────────────────────────
// Default dropdown + dynamic list of (signal text field, strategy
// dropdown, delete button). Free-text signal input in v1; an upgrade to
// a dropdown of the workflow's signals is a future enhancement (needs a
// new backend endpoint since a quiz can belong to multiple workflows).
class _FineAggregationSection extends StatelessWidget {
  final _FineAggregationConfig config;
  final bool isDataEnvQuestion;
  final ValueChanged<_FineAggregationConfig> onChanged;

  const _FineAggregationSection({
    required this.config,
    required this.isDataEnvQuestion,
    required this.onChanged,
  });

  /// Helper text under "Auto" — spells out the effective fallback so the
  /// admin knows what they get without configuration. Resolves via the
  /// context's AppLocalizations (passed in build).
  String _autoHint(AppLocalizations l10n) => isDataEnvQuestion
      ? l10n.fineAggregationAutoSum
      : l10n.fineAggregationAutoMax;

  void _updateRule(int i, {String? signal, String? strategy}) {
    final newRules = [
      for (var j = 0; j < config.rules.length; j++)
        if (j == i)
          _FineAggregationRule(
            signal: signal ?? config.rules[j].signal,
            strategy: strategy ?? config.rules[j].strategy,
          )
        else
          config.rules[j],
    ];
    onChanged(_FineAggregationConfig(
      rules: newRules,
      defaultStrategy: config.defaultStrategy,
    ));
  }

  void _removeRule(int i) {
    final newRules = [...config.rules]..removeAt(i);
    onChanged(_FineAggregationConfig(
      rules: newRules,
      defaultStrategy: config.defaultStrategy,
    ));
  }

  void _addRule() {
    onChanged(_FineAggregationConfig(
      rules: [
        ...config.rules,
        _FineAggregationRule(signal: '', strategy: 'max'),
      ],
      defaultStrategy: config.defaultStrategy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),  // warm amber tint
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFB923C).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fineAggregationLabel,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(2),
          Text(
            l10n.fineAggregationRulesHint,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
          ),
          const Gap(12),

          // ── Default dropdown ──────────────────────────────────
          DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: config.defaultStrategy,
            decoration: InputDecoration(
              labelText: l10n.fineAggregationDefaultLabel,
              helperText: _autoHint(l10n),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: null,  child: Text(l10n.fineAggregationAuto)),
              DropdownMenuItem(value: 'sum', child: Text(l10n.fineAggregationSum)),
              DropdownMenuItem(value: 'max', child: Text(l10n.fineAggregationMax)),
              DropdownMenuItem(value: 'min', child: Text(l10n.fineAggregationMin)),
            ],
            onChanged: (v) => onChanged(_FineAggregationConfig(
              rules: config.rules,
              defaultStrategy: v,
            )),
          ),

          // ── Rule list ─────────────────────────────────────────
          if (config.rules.isNotEmpty) ...[
            const Gap(12),
            Text(
              l10n.fineAggregationRulesLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const Gap(6),
            for (var i = 0; i < config.rules.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: TextFormField(
                    initialValue: config.rules[i].signal,
                    decoration: const InputDecoration(
                      labelText: 'Signal',
                      hintText: 'e.g. small_business',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => _updateRule(i, signal: v),
                  )),
                  const Gap(8),
                  SizedBox(width: 120, child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: config.rules[i].strategy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'sum', child: Text('Sum')),
                      DropdownMenuItem(value: 'max', child: Text('Max')),
                      DropdownMenuItem(value: 'min', child: Text('Min')),
                    ],
                    onChanged: (v) => _updateRule(i, strategy: v),
                  )),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeRule(i),
                  ),
                ]),
              ),
          ],
          const Gap(4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.fineAggregationAddRule),
              onPressed: _addRule,
            ),
          ),
        ],
      ),
    );
  }
}


// ── Step 44 — Per-question fine by classification label editor ────────
// Two-column table of (label, fine in NIS). When the workflow has a
// classification quiz set, each violation task uses the env's label to
// look up its fine here. Empty table → JSONB column stays NULL and the
// resolver returns None (legacy override or rule/LLM takes over).
class _FineByLabelSection extends StatefulWidget {
  final Map<String, num> initial;
  final ValueChanged<Map<String, num>> onChanged;

  const _FineByLabelSection({
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_FineByLabelSection> createState() => _FineByLabelSectionState();
}

class _FineByLabelSectionState extends State<_FineByLabelSection> {
  late List<_FineByLabelRowCtrls> _rows;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final e in widget.initial.entries)
        _FineByLabelRowCtrls(label: e.key, fine: e.value),
    ];
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.labelCtrl.dispose();
      r.fineCtrl.dispose();
    }
    super.dispose();
  }

  /// Convert the current rows back into a Map and notify the parent.
  /// Skips rows with blank label or non-numeric / blank fine. Duplicate
  /// labels collapse — last entry wins (admin sees a duplicate-error
  /// chip but we don't block the parent's setState).
  void _emit() {
    final m = <String, num>{};
    for (final r in _rows) {
      final label = r.labelCtrl.text.trim();
      final fineText = r.fineCtrl.text.trim();
      if (label.isEmpty || fineText.isEmpty) continue;
      final n = num.tryParse(fineText);
      if (n == null || n < 0) continue;
      m[label] = n;
    }
    widget.onChanged(m);
  }

  void _addRow() {
    setState(() => _rows.add(_FineByLabelRowCtrls()));
    _emit();
  }

  void _removeRow(int i) {
    final r = _rows[i];
    r.labelCtrl.dispose();
    r.fineCtrl.dispose();
    setState(() => _rows.removeAt(i));
    _emit();
  }

  /// Returns the indexes whose label appears more than once across rows
  /// (so we can paint them with an error border).
  Set<int> _duplicateIndexes() {
    final seen = <String, int>{};
    final dups = <int>{};
    for (var i = 0; i < _rows.length; i++) {
      final label = _rows[i].labelCtrl.text.trim();
      if (label.isEmpty) continue;
      final prev = seen[label];
      if (prev != null) {
        dups.add(prev);
        dups.add(i);
      } else {
        seen[label] = i;
      }
    }
    return dups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dups = _duplicateIndexes();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // soft green tint to distinguish from Step 42's amber
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fineByResultLabelLabel,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(2),
          Text(
            l10n.fineByResultLabelHint,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
          ),
          const Gap(10),

          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                l10n.fineByResultLabelEmptyHint,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...[
            // Header row
            Row(children: [
              Expanded(
                flex: 3,
                child: Text(
                  l10n.fineByResultLabelLabelCol,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              const Gap(8),
              SizedBox(
                width: 140,
                child: Text(
                  l10n.fineByResultLabelFineCol,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              const SizedBox(width: 40),
            ]),
            const Gap(4),
            for (var i = 0; i < _rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _rows[i].labelCtrl,
                      decoration: InputDecoration(
                        hintText: 'BASIC',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        errorText: dups.contains(i)
                            ? l10n.fineByResultLabelDuplicateError
                            : null,
                      ),
                      onChanged: (_) {
                        setState(() {});  // re-evaluate duplicates
                        _emit();
                      },
                    ),
                  ),
                  const Gap(8),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      controller: _rows[i].fineCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: '2000',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = num.tryParse(v.trim());
                        if (n == null) return null;
                        if (n < 0) return l10n.fineByResultLabelNegativeError;
                        return null;
                      },
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeRow(i),
                  ),
                ]),
              ),
          ],
          const Gap(4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.fineByResultLabelAddRow),
              onPressed: _addRow,
            ),
          ),
        ],
      ),
    );
  }
}

class _FineByLabelRowCtrls {
  final TextEditingController labelCtrl;
  final TextEditingController fineCtrl;
  _FineByLabelRowCtrls({String label = '', num? fine})
      : labelCtrl = TextEditingController(text: label),
        fineCtrl = TextEditingController(text: fine?.toString() ?? '');
}


// ── Step 45 — Fine cap editor widget ─────────────────────────────────
// Stage 2 of the group fine calculator. Per-question, signal-conditional
// cap applied AFTER the sum/max/min aggregation. Same shape as Step 42's
// _FineAggregationSection: default value + ordered list of {signal,
// limit} rules. A blank limit field means "explicit exemption" — that
// rule still matches and explicitly disables capping.
class _FineCapSection extends StatelessWidget {
  final _FineCapConfig config;
  final ValueChanged<_FineCapConfig> onChanged;

  const _FineCapSection({
    required this.config,
    required this.onChanged,
  });

  void _addRule() {
    onChanged(_FineCapConfig(
      rules: [...config.rules, _FineCapRule(signal: '', limit: null)],
      defaultLimit: config.defaultLimit,
    ));
  }

  void _updateRule(int i, {String? signal, num? limit, bool clearLimit = false}) {
    final newRules = [
      for (var j = 0; j < config.rules.length; j++)
        if (j == i)
          _FineCapRule(
            signal: signal ?? config.rules[j].signal,
            limit: clearLimit ? null : (limit ?? config.rules[j].limit),
          )
        else
          config.rules[j],
    ];
    onChanged(_FineCapConfig(
      rules: newRules,
      defaultLimit: config.defaultLimit,
    ));
  }

  void _removeRule(int i) {
    final newRules = [...config.rules]..removeAt(i);
    onChanged(_FineCapConfig(
      rules: newRules,
      defaultLimit: config.defaultLimit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Soft red tint — distinct from Step 42's amber and Step 44's green.
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fineCapSectionTitle,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(2),
          Text(
            l10n.fineCapHint,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
          ),
          const Gap(10),

          // ── Default cap (applied when no rule fires) ──────────
          TextFormField(
            initialValue: config.defaultLimit?.toString() ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.fineCapDefaultLabel,
              helperText: l10n.fineCapDefaultHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              final t = v.trim();
              onChanged(_FineCapConfig(
                rules: config.rules,
                defaultLimit: t.isEmpty ? null : num.tryParse(t),
              ));
            },
          ),

          // ── Conditional rule list ─────────────────────────────
          if (config.rules.isNotEmpty) ...[
            const Gap(12),
            Text(
              l10n.fineCapRulesLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const Gap(6),
            for (var i = 0; i < config.rules.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: config.rules[i].signal,
                      decoration: InputDecoration(
                        labelText: l10n.fineCapSignalCol,
                        hintText: 'tiny_org',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => _updateRule(i, signal: v),
                    ),
                  ),
                  const Gap(8),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      initialValue: config.rules[i].limit?.toString() ?? '',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.fineCapLimitCol,
                        hintText: config.rules[i].limit == null
                            ? l10n.fineCapLimitExempt
                            : '70000',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final t = v.trim();
                        if (t.isEmpty) {
                          _updateRule(i, clearLimit: true);
                        } else {
                          final n = num.tryParse(t);
                          if (n != null) _updateRule(i, limit: n);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeRule(i),
                  ),
                ]),
              ),
          ],
          const Gap(4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.fineCapAddRule),
              onPressed: _addRule,
            ),
          ),
        ],
      ),
    );
  }
}
