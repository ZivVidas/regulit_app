import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = Color(0xFF1A3C6B);
const _kGrad2 = Color(0xFF2D6BB0);

// ── State ─────────────────────────────────────────────────────
class _QuizzesState {
  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int pages;
  final bool isLoading;
  final String? error;
  final String search;

  const _QuizzesState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    this.isLoading = true,
    this.error,
    this.search = '',
  });

  _QuizzesState copyWith({
    List<Map<String, dynamic>>? items,
    int? total,
    int? page,
    int? pages,
    bool? isLoading,
    String? error,
    String? search,
  }) =>
      _QuizzesState(
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        search: search ?? this.search,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _QuizzesNotifier extends StateNotifier<_QuizzesState> {
  final Dio _dio;
  _QuizzesNotifier(this._dio) : super(const _QuizzesState()) {
    load();
  }

  Future<void> load({String? search, int? page}) async {
    final s = search ?? state.search;
    final p = page ?? state.page;
    state = state.copyWith(isLoading: true, error: null, search: s, page: p);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/quizzes',
        queryParameters: {'search': s, 'page': p, 'page_size': 20},
      );
      final data = res.data!;
      state = state.copyWith(
        isLoading: false,
        items: (data['items'] as List).cast<Map<String, dynamic>>(),
        total: data['total'] as int,
        pages: data['pages'] as int,
        page: data['page'] as int,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createQuiz(Map<String, dynamic> body) async {
    await _dio.post<dynamic>('/quizzes', data: body);
    await load();
  }

  Future<void> updateQuiz(String id, Map<String, dynamic> body) async {
    await _dio.put<dynamic>('/quizzes/$id', data: body);
    await load();
  }

  Future<void> deactivateQuiz(String id) async {
    await _dio.delete<dynamic>('/quizzes/$id');
    await load();
  }
}

final _quizzesProvider =
    StateNotifierProvider.autoDispose<_QuizzesNotifier, _QuizzesState>(
        (ref) => _QuizzesNotifier(ref.watch(dioProvider)));

// ── Screen ────────────────────────────────────────────────────
class QuizzesScreen extends ConsumerStatefulWidget {
  const QuizzesScreen({super.key});
  @override
  ConsumerState<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends ConsumerState<QuizzesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) =>
      ref.read(_quizzesProvider.notifier).load(search: q, page: 1);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_quizzesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Gradient Header ──────────────────────────────────
          _GradientHeader(
            title: 'Quizzes',
            subtitle: s.isLoading
                ? 'Loading…'
                : '${s.total} quiz${s.total == 1 ? '' : 'zes'} in the system',
            icon: Icons.quiz_rounded,
            onAdd: () => _showQuizForm(context, null),
            addLabel: 'Add Quiz',
            searchCtrl: _searchCtrl,
            searchHint: 'Search by name…',
            onSearch: _search,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),

          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: s.isLoading
                ? const _ShimmerList()
                : s.error != null
                    ? _ErrorView(
                        message: s.error!,
                        onRetry: () =>
                            ref.read(_quizzesProvider.notifier).load(),
                      )
                    : s.items.isEmpty
                        ? _EmptyView(
                            icon: Icons.quiz_outlined,
                            message: s.search.isEmpty
                                ? 'No quizzes yet.\nCreate the first one!'
                                : 'No results for "${s.search}".',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: s.items.length,
                            itemBuilder: (_, i) {
                              final q = s.items[i];
                              return _QuizCard(
                                quiz: q,
                                index: i,
                                onSteps: () => context.push(
                                  '/admin/quizzes/${q['id']}/steps?name=${Uri.encodeComponent(q['name'] as String? ?? '')}',
                                ),
                                onEdit: () => _showQuizForm(context, q),
                                onDeactivate: q['isActive'] == true
                                    ? () => _confirmDeactivate(
                                          context,
                                          q['id'] as String,
                                          q['name'] as String,
                                        )
                                    : null,
                              );
                            },
                          ),
          ),

          // ── Pagination ───────────────────────────────────────
          if (!s.isLoading && s.error == null && s.pages > 1)
            _PaginationBar(
              page: s.page,
              pages: s.pages,
              onPrev: s.page > 1
                  ? () => ref
                      .read(_quizzesProvider.notifier)
                      .load(page: s.page - 1)
                  : null,
              onNext: s.page < s.pages
                  ? () => ref
                      .read(_quizzesProvider.notifier)
                      .load(page: s.page + 1)
                  : null,
            ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  void _showQuizForm(BuildContext context, Map<String, dynamic>? quiz) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuizFormDialog(
        initialQuiz: quiz,
        onSave: (body) async {
          final n = ref.read(_quizzesProvider.notifier);
          if (quiz == null) {
            await n.createQuiz(body);
          } else {
            await n.updateQuiz(quiz['id'] as String, body);
          }
        },
      ),
    );
  }

  Future<void> _confirmDeactivate(
      BuildContext context, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate quiz'),
        content: Text('"$name" will be marked as inactive. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(_quizzesProvider.notifier).deactivateQuiz(id);
      } catch (e) {
        if (mounted) {
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
class _GradientHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onAdd;
  final String addLabel;
  final TextEditingController searchCtrl;
  final String searchHint;
  final ValueChanged<String> onSearch;

  const _GradientHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onAdd,
    required this.addLabel,
    required this.searchCtrl,
    required this.searchHint,
    required this.onSearch,
  });

  @override
  State<_GradientHeader> createState() => _GradientHeaderState();
}

class _GradientHeaderState extends State<_GradientHeader> {
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
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            )),
                        Text(widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                  _AnimatedAddButton(
                    label: widget.addLabel,
                    onTap: widget.onAdd,
                  ),
                ],
              ),
              const Gap(14),
              // Search bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: TextField(
                  controller: widget.searchCtrl,
                  onChanged: widget.onSearch,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.55), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.7), size: 18),
                    suffixIcon: widget.searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close,
                                color: Colors.white.withOpacity(0.7), size: 16),
                            onPressed: () {
                              widget.searchCtrl.clear();
                              widget.onSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated Add Button ───────────────────────────────────────
class _AnimatedAddButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AnimatedAddButton({required this.label, required this.onTap});

  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton> {
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
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, size: 16, color: _kGrad1),
            const Gap(6),
            Text(
              widget.label,
              style: const TextStyle(
                color: _kGrad1,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 2200.ms,
          delay: 1500.ms,
          color: Colors.white.withOpacity(0.6),
        );
  }
}

// ── Quiz Card ─────────────────────────────────────────────────
class _QuizCard extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onSteps;
  final VoidCallback? onDeactivate;

  const _QuizCard({
    required this.quiz,
    required this.index,
    required this.onEdit,
    required this.onSteps,
    this.onDeactivate,
  });

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.quiz;
    final isActive = q['isActive'] as bool? ?? true;
    final accentColor = isActive ? _kGrad1 : AppColors.muted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
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
              // Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kGrad1, _kGrad1.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _hovered
                      ? [BoxShadow(
                          color: _kGrad1.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3))]
                      : [],
                ),
                child: const Icon(Icons.quiz_rounded,
                    color: Colors.white, size: 20),
              ),
              const Gap(14),

              // Name + description + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        q['name'] as String? ?? '—',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (!isActive) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Inactive',
                              style: AppTextStyles.tag
                                  .copyWith(color: AppColors.danger)),
                        ),
                      ],
                    ]),
                    if ((q['description'] as String?)?.isNotEmpty ?? false) ...[
                      const Gap(2),
                      Text(
                        q['description'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if ((q['quizResult'] as String?)?.isNotEmpty ?? false) ...[
                      const Gap(4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.fact_check_outlined,
                              size: 12, color: _kGrad2.withOpacity(0.7)),
                          const Gap(4),
                          Expanded(
                            child: Text(
                              q['quizResult'] as String,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _kGrad2.withOpacity(0.8),
                                  fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((q['quizAlgorithmResult'] as String?)?.isNotEmpty ?? false) ...[
                      const Gap(4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.smart_toy_outlined,
                              size: 12, color: const Color(0xFF7C3AED).withOpacity(0.7)),
                          const Gap(4),
                          Expanded(
                            child: Text(
                              q['quizAlgorithmResult'] as String,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7C3AED),
                                  fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Gap(4),
                    Text(
                      'Created by ${q['createdBy'] ?? '—'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),

              // Actions
              _ActionIcon(
                icon: Icons.list_alt_rounded,
                color: const Color(0xFF059669),
                tooltip: 'Manage Steps',
                onTap: widget.onSteps,
              ),
              const Gap(4),
              _ActionIcon(
                icon: Icons.edit_outlined,
                color: _kGrad2,
                tooltip: 'Edit',
                onTap: widget.onEdit,
              ),
              if (widget.onDeactivate != null) ...[
                const Gap(4),
                _ActionIcon(
                  icon: Icons.archive_outlined,
                  color: AppColors.danger,
                  tooltip: 'Deactivate',
                  onTap: widget.onDeactivate!,
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 380.ms,
          delay: (widget.index * 55).ms,
          curve: Curves.easeOut,
        )
        .slideX(
          begin: 0.12,
          end: 0,
          duration: 380.ms,
          delay: (widget.index * 55).ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ── Action Icon Button ────────────────────────────────────────
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
                size: 17, color: _hov ? widget.color : Colors.grey[400]),
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
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 76,
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

// ── Pagination Bar ────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int page;
  final int pages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.pages,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageBtn(
              icon: Icons.chevron_left_rounded,
              onTap: onPrev,
              enabled: onPrev != null),
          const Gap(16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _kGrad1.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Page $page of $pages',
              style: const TextStyle(
                color: _kGrad1,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Gap(16),
          _PageBtn(
              icon: Icons.chevron_right_rounded,
              onTap: onNext,
              enabled: onNext != null),
        ],
      ),
    );
  }
}

class _PageBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  const _PageBtn(
      {required this.icon, required this.onTap, required this.enabled});

  @override
  State<_PageBtn> createState() => _PageBtnState();
}

class _PageBtnState extends State<_PageBtn> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hov && widget.enabled
                ? _kGrad1.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.enabled
                  ? _kGrad1.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.enabled ? _kGrad1 : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}

// ── Empty View ────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

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
          child: Icon(icon, size: 48, color: _kGrad1.withOpacity(0.5)),
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

// ── Quiz Form Dialog ──────────────────────────────────────────
class _QuizFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialQuiz;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  const _QuizFormDialog({this.initialQuiz, required this.onSave});

  @override
  State<_QuizFormDialog> createState() => _QuizFormDialogState();
}

class _QuizFormDialogState extends State<_QuizFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _resultCtrl;
  late final TextEditingController _algoResultCtrl;
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialQuiz != null;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuiz;
    _nameCtrl = TextEditingController(text: q?['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: q?['description'] as String? ?? '');
    _resultCtrl = TextEditingController(text: q?['quizResult'] as String? ?? '');
    _algoResultCtrl = TextEditingController(text: q?['quizAlgorithmResult'] as String? ?? '');
    _isActive = q?['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _resultCtrl.dispose();
    _algoResultCtrl.dispose();
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
      'quizResult':
          _resultCtrl.text.trim().isEmpty ? null : _resultCtrl.text.trim(),
      'quizAlgorithmResult':
          _algoResultCtrl.text.trim().isEmpty ? null : _algoResultCtrl.text.trim(),
      'is_active': _isActive,
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
          mainAxisSize: MainAxisSize.max,
          children: [
            // Dialog header
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
                  _isEdit ? Icons.edit_rounded : Icons.quiz_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const Gap(10),
                Text(
                  _isEdit ? 'Edit Quiz' : 'New Quiz',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),

            // Form body
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
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
                        label: 'Quiz Name',
                        ctrl: _nameCtrl,
                        required: true,
                      ),
                      const Gap(12),
                      _Field(
                        label: 'Description (optional)',
                        ctrl: _descCtrl,
                        maxLines: 3,
                      ),
                      const Gap(12),
                      _Field(
                        label: 'Quiz Result (optional)',
                        ctrl: _resultCtrl,
                        maxLines: 6,
                        hint: 'Describe the outcome or result text shown after completing this quiz…',
                      ),
                      const Gap(12),
                      _Field(
                        label: 'Algorithm Result (optional)',
                        ctrl: _algoResultCtrl,
                        maxLines: 6,
                        hint: 'Algorithm-generated result or scoring logic description…',
                      ),
                      const Gap(12),
                      Row(children: [
                        Switch(
                          value: _isActive,
                          activeColor: AppColors.orange,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                        const Gap(8),
                        Text(_isActive ? 'Active' : 'Inactive',
                            style: AppTextStyles.body),
                      ]),
                    ],
                  ),
                ),
              ),
            )),

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
                        : Text(_isEdit ? 'Save Changes' : 'Create Quiz'),
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
  final String? hint;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.ctrl,
    this.required = false,
    this.maxLines = 1,
    this.hint,
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
