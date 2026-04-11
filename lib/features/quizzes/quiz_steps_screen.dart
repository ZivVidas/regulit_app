import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = AppColors.blue;
const _kGrad2 = Color(0xFF2D6BB0);

// ── State ─────────────────────────────────────────────────────
class _StepsState {
  final List<Map<String, dynamic>> items;
  final int total;
  final bool isLoading;
  final String? error;

  const _StepsState({
    this.items = const [],
    this.total = 0,
    this.isLoading = true,
    this.error,
  });

  _StepsState copyWith({
    List<Map<String, dynamic>>? items,
    int? total,
    bool? isLoading,
    String? error,
  }) =>
      _StepsState(
        items: items ?? this.items,
        total: total ?? this.total,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _StepsNotifier extends StateNotifier<_StepsState> {
  final Dio _dio;
  final String quizId;

  _StepsNotifier(this._dio, this.quizId) : super(const _StepsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/quizzes/$quizId/steps',
        queryParameters: {'page': 1, 'page_size': 100},
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

  Future<void> createStep(Map<String, dynamic> body) async {
    await _dio.post<dynamic>('/quizzes/$quizId/steps', data: body);
    await load();
  }

  Future<void> updateStep(String stepId, Map<String, dynamic> body) async {
    await _dio.put<dynamic>('/quizzes/$quizId/steps/$stepId', data: body);
    await load();
  }

  Future<void> deleteStep(String stepId) async {
    await _dio.delete<dynamic>('/quizzes/$quizId/steps/$stepId');
    await load();
  }
}

// Provider is keyed by quizId so each quiz gets its own notifier.
final _stepsProviderFamily = StateNotifierProvider.autoDispose
    .family<_StepsNotifier, _StepsState, String>(
  (ref, quizId) => _StepsNotifier(ref.watch(dioProvider), quizId),
);

// ── Screen ────────────────────────────────────────────────────
class QuizStepsScreen extends ConsumerWidget {
  final String quizId;
  final String quizName;

  const QuizStepsScreen({
    super.key,
    required this.quizId,
    required this.quizName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_stepsProviderFamily(quizId));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Gradient Header ──────────────────────────────────
          _Header(
            quizName: quizName,
            stepCount: s.isLoading ? null : s.total,
            onBack: () => context.pop(),
            onAdd: () => _showStepForm(context, ref, null),
            onResultEngine: () {
              final name = Uri.encodeComponent(quizName);
              context.push('/admin/quizzes/$quizId/result-engine?name=$name');
            },
            onNumericEngine: () {
              final name = Uri.encodeComponent(quizName);
              context.push('/admin/quizzes/$quizId/numeric-engine?name=$name');
            },
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),

          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: s.isLoading
                ? const _ShimmerList()
                : s.error != null
                    ? _ErrorView(
                        message: s.error!,
                        onRetry: () =>
                            ref.read(_stepsProviderFamily(quizId).notifier).load(),
                      )
                    : s.items.isEmpty
                        ? _EmptyView(
                            message:
                                'No steps yet.\nAdd the first step for "$quizName".',
                          )
                        : ReorderableListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: s.items.length,
                            onReorder: (_, __) {}, // ordering is by created_at
                            itemBuilder: (_, i) {
                              final step = s.items[i];
                              return _StepCard(
                                key: ValueKey(step['id']),
                                step: step,
                                index: i,
                                onQuestions: () {
                                  final stepId = step['id'] as String;
                                  final stepName =
                                      Uri.encodeComponent(step['name'] as String? ?? 'Step');
                                  final qn =
                                      Uri.encodeComponent(quizName);
                                  context.push(
                                    '/admin/quizzes/$quizId/steps/$stepId/questions'
                                    '?stepName=$stepName&quizName=$qn',
                                  );
                                },
                                onEdit: () =>
                                    _showStepForm(context, ref, step),
                                onDelete: () => _confirmDelete(
                                    context, ref, step['id'] as String,
                                    step['name'] as String),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showStepForm(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? step) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StepFormDialog(
        initialStep: step,
        onSave: (body) async {
          final n = ref.read(_stepsProviderFamily(quizId).notifier);
          if (step == null) {
            await n.createStep(body);
          } else {
            await n.updateStep(step['id'] as String, body);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete step'),
        content: Text('"$name" will be permanently deleted. Continue?'),
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
        await ref.read(_stepsProviderFamily(quizId).notifier).deleteStep(id);
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
  final int? stepCount;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final VoidCallback onResultEngine;
  final VoidCallback onNumericEngine;

  const _Header({
    required this.quizName,
    required this.stepCount,
    required this.onBack,
    required this.onAdd,
    required this.onResultEngine,
    required this.onNumericEngine,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = stepCount == null
        ? 'Loading…'
        : '$stepCount step${stepCount == 1 ? '' : 's'}';

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
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                tooltip: 'Back to Quizzes',
              ),
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.list_alt_rounded,
                    color: Colors.white, size: 22),
              ),
              const Gap(12),
              // Titles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quizName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Result Engine button
              IconButton(
                onPressed: onResultEngine,
                icon: const Icon(Icons.account_tree_rounded,
                    color: Colors.white, size: 20),
                tooltip: 'Label Result Engine',
              ),
              // Numeric Engine button
              IconButton(
                onPressed: onNumericEngine,
                icon: const Icon(Icons.calculate_rounded,
                    color: Colors.white, size: 20),
                tooltip: 'Numeric Engine',
              ),
              // Add button
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
                  color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, size: 16, color: _kGrad1),
            const Gap(6),
            const Text('Add Step',
                style: TextStyle(
                    color: _kGrad1, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ── Step Card ─────────────────────────────────────────────────
class _StepCard extends StatefulWidget {
  final Map<String, dynamic> step;
  final int index;
  final VoidCallback onQuestions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StepCard({
    super.key,
    required this.step,
    required this.index,
    required this.onQuestions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.step;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
            left: BorderSide(color: _kGrad1, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? _kGrad1.withOpacity(0.14)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _hovered ? 20 : 6,
              offset: Offset(0, _hovered ? 6 : 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Step number badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kGrad1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: _kGrad1,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const Gap(14),

              // Name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['name'] as String? ?? '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if ((s['description'] as String?)?.isNotEmpty ?? false) ...[
                      const Gap(2),
                      Text(
                        s['description'] as String,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              _ActionIcon(
                icon: Icons.help_outline_rounded,
                color: const Color(0xFF7C3AED),
                tooltip: 'Questions',
                onTap: widget.onQuestions,
              ),
              const Gap(4),
              _ActionIcon(
                icon: Icons.edit_outlined,
                color: _kGrad2,
                tooltip: 'Edit',
                onTap: widget.onEdit,
              ),
              const Gap(4),
              _ActionIcon(
                icon: Icons.delete_outline_rounded,
                color: AppColors.danger,
                tooltip: 'Delete',
                onTap: widget.onDelete,
              ),
              // Drag handle
              const Gap(4),
              Icon(Icons.drag_handle_rounded,
                  size: 20, color: Colors.grey[300]),
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
              color: _hov ? widget.color.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon,
                size: 17,
                color: _hov ? widget.color : Colors.grey[400]),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer Loading ───────────────────────────────────────────
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
          height: 68,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Empty View ────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

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
          child: Icon(Icons.list_alt_outlined,
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
        Text(
          message,
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
            color: AppColors.dangerLight,
            shape: BoxShape.circle,
          ),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

// ── Step Form Dialog ──────────────────────────────────────────
class _StepFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialStep;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  const _StepFormDialog({this.initialStep, required this.onSave});

  @override
  State<_StepFormDialog> createState() => _StepFormDialogState();
}

class _StepFormDialogState extends State<_StepFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialStep != null;

  @override
  void initState() {
    super.initState();
    final s = widget.initialStep;
    _nameCtrl = TextEditingController(text: s?['name'] as String? ?? '');
    _descCtrl =
        TextEditingController(text: s?['description'] as String? ?? '');
  }

  @override
  void dispose() {
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
      'name': _nameCtrl.text.trim(),
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
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
                Icon(
                  _isEdit
                      ? Icons.edit_rounded
                      : Icons.playlist_add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const Gap(10),
                Text(
                  _isEdit ? 'Edit Step' : 'New Step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),

            // Form body
            SizedBox(
              width: 440,
              child: Padding(
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
                      _Field(
                        label: 'Step Name',
                        ctrl: _nameCtrl,
                        required: true,
                      ),
                      const Gap(12),
                      _Field(
                        label: 'Description (optional)',
                        ctrl: _descCtrl,
                        maxLines: 3,
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
                        : Text(_isEdit ? 'Save Changes' : 'Add Step'),
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

// ── Reusable form field ───────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  final int maxLines;

  const _Field({
    required this.label,
    required this.ctrl,
    this.required = false,
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
          style: AppTextStyles.body,
          decoration: const InputDecoration(isDense: true),
          validator: required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null,
        ),
      ],
    );
  }
}
