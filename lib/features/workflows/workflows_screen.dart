import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = Color(0xFF1B4D3E); // deep teal
const _kGrad2 = Color(0xFF2E7D5C); // mid teal

// ── State ─────────────────────────────────────────────────────
class _WfState {
  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int pages;
  final bool isLoading;
  final String? error;
  final String search;

  const _WfState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    this.isLoading = true,
    this.error,
    this.search = '',
  });

  _WfState copyWith({
    List<Map<String, dynamic>>? items,
    int? total,
    int? page,
    int? pages,
    bool? isLoading,
    String? error,
    String? search,
  }) =>
      _WfState(
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
class _WfNotifier extends StateNotifier<_WfState> {
  final Dio _dio;
  _WfNotifier(this._dio) : super(const _WfState()) {
    load();
  }

  Future<void> load({String? search, int? page}) async {
    final s = search ?? state.search;
    final p = page ?? state.page;
    state = state.copyWith(isLoading: true, error: null, search: s, page: p);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/workflows',
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

  Future<void> createWorkflow(Map<String, dynamic> body) async {
    await _dio.post<dynamic>('/workflows', data: body);
    await load();
  }

  Future<void> updateWorkflow(String id, Map<String, dynamic> body) async {
    await _dio.put<dynamic>('/workflows/$id', data: body);
    await load();
  }

  Future<void> deactivateWorkflow(String id) async {
    await _dio.delete<dynamic>('/workflows/$id');
    await load();
  }
}

final _wfProvider =
    StateNotifierProvider.autoDispose<_WfNotifier, _WfState>(
        (ref) => _WfNotifier(ref.watch(dioProvider)));

// ── Screen ────────────────────────────────────────────────────
class WorkflowsScreen extends ConsumerStatefulWidget {
  const WorkflowsScreen({super.key});
  @override
  ConsumerState<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends ConsumerState<WorkflowsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_wfProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────
          _Header(
            total: s.isLoading ? null : s.total,
            searchCtrl: _searchCtrl,
            onSearch: (v) =>
                ref.read(_wfProvider.notifier).load(search: v, page: 1),
            onAdd: () => _showForm(context, null),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),

          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: s.isLoading
                ? const _ShimmerList()
                : s.error != null
                    ? _ErrorView(
                        message: s.error!,
                        onRetry: () =>
                            ref.read(_wfProvider.notifier).load(),
                      )
                    : s.items.isEmpty
                        ? const _EmptyView()
                        : RefreshIndicator(
                            onRefresh: () =>
                                ref.read(_wfProvider.notifier).load(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              itemCount: s.items.length +
                                  (s.page < s.pages ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == s.items.length) {
                                  return _LoadMoreButton(onTap: () => ref
                                      .read(_wfProvider.notifier)
                                      .load(page: s.page + 1));
                                }
                                final wf = s.items[i];
                                return _WorkflowCard(
                                  workflow: wf,
                                  index: i,
                                  onQuizzes: () => context.push(
                                    '/admin/workflows/${wf['id']}/quizzes?name=${Uri.encodeComponent(wf['name'] as String? ?? '')}',
                                  ),
                                  onRuleEngine: () => context.push(
                                    '/admin/workflows/${wf['id']}/rule-engine?name=${Uri.encodeComponent(wf['name'] as String? ?? '')}',
                                  ),
                                  onEdit: () => _showForm(context, wf),
                                  onDeactivate: () => _confirmDeactivate(
                                      context, wf['id'] as String,
                                      wf['name'] as String? ?? ''),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, Map<String, dynamic>? wf) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WorkflowFormDialog(
        initial: wf,
        onSave: (body) async {
          final n = ref.read(_wfProvider.notifier);
          if (wf == null) {
            await n.createWorkflow(body);
          } else {
            await n.updateWorkflow(wf['id'] as String, body);
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
        title: const Text('Deactivate workflow'),
        content: Text('"$name" will be deactivated.'),
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
    if (ok == true) {
      try {
        await ref.read(_wfProvider.notifier).deactivateWorkflow(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.danger));
        }
      }
    }
  }
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int? total;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  const _Header({
    required this.total,
    required this.searchCtrl,
    required this.onSearch,
    required this.onAdd,
  });

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
              color: Color(0x331B4D3E), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_tree_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Workflows',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            )),
                        Text(
                          total == null
                              ? 'Loading…'
                              : '$total workflow${total == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AddButton(onTap: onAdd),
                ],
              ),
              const Gap(14),
              // Search bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.7), size: 18),
                    hintText: 'Search workflows…',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                  onChanged: onSearch,
                ),
              ),
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
            const Text('Add Workflow',
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

// ── Workflow Card ─────────────────────────────────────────────
class _WorkflowCard extends StatefulWidget {
  final Map<String, dynamic> workflow;
  final int index;
  final VoidCallback onQuizzes;
  final VoidCallback onRuleEngine;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _WorkflowCard({
    required this.workflow,
    required this.index,
    required this.onQuizzes,
    required this.onRuleEngine,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  State<_WorkflowCard> createState() => _WorkflowCardState();
}

class _WorkflowCardState extends State<_WorkflowCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final wf = widget.workflow;
    final isActive = wf['isActive'] as bool? ?? true;
    final quizCount = wf['quizCount'] as int? ?? 0;
    final color = isActive ? _kGrad2 : Colors.grey;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? _kGrad2.withOpacity(0.12)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _hovered ? 20 : 6,
              offset: Offset(0, _hovered ? 6 : 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_tree_rounded,
                    color: color, size: 20),
              ),
              const Gap(14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            wf['name'] as String? ?? '—',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isActive)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Inactive',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    if ((wf['description'] as String?)?.isNotEmpty ?? false) ...[
                      const Gap(2),
                      Text(
                        wf['description'] as String,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                    const Gap(4),
                    // Quiz count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kGrad1.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$quizCount quiz${quizCount == 1 ? '' : 'zes'}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _kGrad1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  _ActionIcon(
                    icon: Icons.playlist_add_check_rounded,
                    color: const Color(0xFF059669),
                    tooltip: 'Manage Quizzes',
                    onTap: widget.onQuizzes,
                  ),
                  const Gap(2),
                  _ActionIcon(
                    icon: Icons.rule_folder_rounded,
                    color: const Color(0xFF7C3AED),
                    tooltip: 'Rule Engine',
                    onTap: widget.onRuleEngine,
                  ),
                  const Gap(2),
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    color: _kGrad2,
                    tooltip: 'Edit',
                    onTap: widget.onEdit,
                  ),
                  const Gap(2),
                  _ActionIcon(
                    icon: Icons.block_rounded,
                    color: AppColors.danger,
                    tooltip: 'Deactivate',
                    onTap: widget.onDeactivate,
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
          begin: 0.06,
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

// ── Load More ─────────────────────────────────────────────────
class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.expand_more_rounded, size: 16),
          label: const Text('Load more'),
          style: OutlinedButton.styleFrom(foregroundColor: _kGrad2),
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
        itemCount: 6,
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
  const _EmptyView();

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
          child: Icon(Icons.account_tree_outlined,
              size: 48, color: _kGrad1.withOpacity(0.5)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.06, 1.06),
                duration: 1800.ms,
                curve: Curves.easeInOut),
        const Gap(20),
        const Text(
          'No workflows yet.\nCreate the first workflow.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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

// ── Workflow File Item model ──────────────────────────────────
class _WfFileItem {
  final String id;
  final String workflowId;
  final String fileId;
  final String filePath;
  final String fileName;
  final String fileType;
  final String? fileText;
  final String? imageDescription;
  final DateTime createdAt;

  const _WfFileItem({
    required this.id,
    required this.workflowId,
    required this.fileId,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    this.fileText,
    this.imageDescription,
    required this.createdAt,
  });

  factory _WfFileItem.fromJson(Map<String, dynamic> j) => _WfFileItem(
        id: j['id'] as String,
        workflowId: j['workflowId'] as String,
        fileId: j['fileId'] as String,
        filePath: j['filePath'] as String? ?? '',
        fileName: j['fileName'] as String? ?? '',
        fileType: j['fileType'] as String? ?? 'text',
        fileText: j['fileText'] as String?,
        imageDescription: j['imageDescription'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ── Workflow Form Dialog ──────────────────────────────────────
class _WorkflowFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initial;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _WorkflowFormDialog({this.initial, required this.onSave});

  @override
  ConsumerState<_WorkflowFormDialog> createState() =>
      _WorkflowFormDialogState();
}

class _WorkflowFormDialogState extends ConsumerState<_WorkflowFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;
  String? _error;

  // ── Fine source state ────────────────────────────────────────
  String _fineSource = 'llm';
  String? _fineQuizId;
  List<Map<String, String>> _quizzes = []; // [{id, name}]
  bool _quizzesLoading = false;

  // ── File evidence state ──────────────────────────────────────
  bool _uploading = false;
  double _uploadProgress = 0.0;
  final List<_WfFileItem> _files = [];

  bool get _isEdit => widget.initial != null;
  String? get _workflowId => widget.initial?['id'] as String?;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.initial?['name'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: widget.initial?['description'] as String? ?? '');
    _fineSource =
        (widget.initial?['fineSource'] as String?) ?? 'llm';
    _fineQuizId = widget.initial?['fineQuizId'] as String?;
    if (_isEdit && _workflowId != null) {
      _loadFiles();
      _loadQuizzes();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuizzes() async {
    if (_workflowId == null) return;
    setState(() => _quizzesLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio
          .get<List<dynamic>>('/workflows/$_workflowId/quizzes');
      if (!mounted) return;
      setState(() {
        _quizzes = (res.data ?? [])
            .map((e) => {
                  'id': (e as Map<String, dynamic>)['quizId'] as String,
                  'name': e['quizName'] as String,
                })
            .toList();
        _quizzesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _quizzesLoading = false);
    }
  }

  Future<void> _loadFiles() async {
    try {
      final dio = ref.read(dioProvider);
      final res =
          await dio.get<List<dynamic>>('/workflows/$_workflowId/files');
      if (!mounted) return;
      setState(() {
        _files
          ..clear()
          ..addAll(
            (res.data ?? [])
                .map((e) => _WfFileItem.fromJson(e as Map<String, dynamic>)),
          );
      });
    } catch (_) {}
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final dio = ref.read(dioProvider);

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: picked.name),
      });
      final uploadRes = await dio.post<Map<String, dynamic>>(
        '/files/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      final fileId = uploadRes.data!['id'] as String;

      final linkRes = await dio.post<Map<String, dynamic>>(
        '/workflows/$_workflowId/files',
        data: {'fileId': fileId},
      );
      final newItem = _WfFileItem.fromJson(linkRes.data!);

      if (mounted) {
        setState(() {
          _files.insert(0, newItem);
          _uploading = false;
          _uploadProgress = 0.0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeFile(_WfFileItem item) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/workflows/$_workflowId/files/${item.id}');
      if (mounted) {
        setState(() => _files.removeWhere((f) => f.id == item.id));
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Validate: if quiz_numeric selected, a quiz must be chosen
    if (_fineSource == 'quiz_numeric' && _fineQuizId == null) {
      setState(() {
        _error = 'Please select a quiz for the fine calculation.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'fineSource': _fineSource,
        'fineQuizId': _fineSource == 'quiz_numeric' ? _fineQuizId : null,
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 780),
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
                        : Icons.account_tree_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const Gap(10),
                  Text(
                    _isEdit ? 'Edit Workflow' : 'New Workflow',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),

              // Form + File section (scrollable)
              Flexible(
               child: SingleChildScrollView(
                child: Column(children: [
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
                      _FormField(
                          label: 'Workflow Name',
                          ctrl: _nameCtrl,
                          required: true),
                      const Gap(12),
                      _FormField(
                          label: 'Description (optional)',
                          ctrl: _descCtrl,
                          maxLines: 3),
                      if (_isEdit) ...[
                      const Gap(16),
                      // ── Fine Source Picker ────────────────────────
                      const Text(
                        'Estimated Fine Source',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const Gap(6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'llm',
                            icon: Icon(Icons.auto_awesome_rounded, size: 14),
                            label: Text('AI (LLM)'),
                          ),
                          ButtonSegment(
                            value: 'quiz_numeric',
                            icon: Icon(Icons.calculate_rounded, size: 14),
                            label: Text('Quiz Result'),
                          ),
                        ],
                        selected: {_fineSource},
                        onSelectionChanged: (s) => setState(() {
                          _fineSource = s.first;
                          if (_fineSource == 'llm') _fineQuizId = null;
                        }),
                        style: ButtonStyle(
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (_fineSource == 'quiz_numeric') ...[
                        const Gap(10),
                        if (_quizzesLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else if (_quizzes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline_rounded,
                                    size: 14, color: AppColors.warning),
                                Gap(6),
                                Expanded(
                                  child: Text(
                                    'No quizzes linked to this workflow yet.',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            value: _fineQuizId,
                            decoration: InputDecoration(
                              labelText: 'Quiz',
                              labelStyle:
                                  const TextStyle(fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                            ),
                            hint: const Text('Select quiz',
                                style: TextStyle(fontSize: 12)),
                            items: _quizzes
                                .map((q) => DropdownMenuItem(
                                      value: q['id'],
                                      child: Text(q['name'] ?? '',
                                          style:
                                              const TextStyle(fontSize: 12)),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _fineQuizId = v),
                          ),
                        const Gap(4),
                        const Text(
                          'The numeric result of the selected quiz will be used as the estimated fine for all AI-created tasks.',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],   // closes if (_fineSource == 'quiz_numeric')
                      ],   // closes if (_isEdit)
                    ],
                  ),
                ),
              ),

              // ── File Evidence Section (edit mode only) ─────────
              if (_isEdit) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: AppColors.border, height: 1),
                      const Gap(14),
                      Row(
                        children: const [
                          Icon(Icons.attach_file_rounded,
                              size: 14, color: AppColors.muted),
                          Gap(6),
                          Text('Attached Files',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted)),
                        ],
                      ),
                      const Gap(8),
                      // Progress bar while uploading
                      if (_uploading) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value:
                                _uploadProgress > 0 ? _uploadProgress : null,
                            minHeight: 4,
                            backgroundColor:
                                AppColors.blue.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.blue),
                          ),
                        ),
                        const Gap(8),
                      ],
                      // File rows
                      ..._files.map((f) => _WfFileRow(
                            item: f,
                            baseUrl: ref.read(dioProvider).options.baseUrl,
                            onRemove: () => _removeFile(f),
                          )),
                      // Upload button
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickAndUpload,
                        icon: const Icon(Icons.upload_file_outlined, size: 16),
                        label: const Text('Add File'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.blue,
                          side: const BorderSide(color: AppColors.blue),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const Gap(14),
                    ],
                  ),
                ),
              ],
              // End of scrollable area
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
                          : Text(_isEdit ? 'Save Changes' : 'Create'),
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

// ── Reusable form field ───────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool required;
  final int maxLines;

  const _FormField({
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
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      ],
    );
  }
}

// ── Workflow file row ─────────────────────────────────────────
class _WfFileRow extends StatelessWidget {
  final _WfFileItem item;
  final VoidCallback onRemove;
  final String baseUrl;

  const _WfFileRow({
    required this.item,
    required this.onRemove,
    required this.baseUrl,
  });

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  void _openViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _WfFileViewerDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImage = item.fileType == 'image';
    final hasContent =
        (item.fileText != null && item.fileText!.isNotEmpty) ||
            (item.imageDescription != null && item.imageDescription!.isNotEmpty);
    final displayName =
        item.fileName.isNotEmpty ? item.fileName : item.filePath.split('/').last;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isImage ? Icons.image_outlined : Icons.description_outlined,
            size: 16,
            color: isImage ? AppColors.info : AppColors.blue,
          ),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  _fmtDate(item.createdAt),
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          const Gap(4),
          if (hasContent)
            _WfFileIconBtn(
              icon: Icons.visibility_outlined,
              tooltip: 'View',
              color: AppColors.blue,
              onTap: () => _openViewer(context),
            ),
          _WfFileIconBtn(
            icon: Icons.download_outlined,
            tooltip: 'Download',
            color: AppColors.success,
            onTap: () async {
              final uri = Uri.parse('$baseUrl/files/${item.fileId}/download');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
          _WfFileIconBtn(
            icon: Icons.delete_outline,
            tooltip: 'Remove',
            color: AppColors.danger,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _WfFileIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _WfFileIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}

// ── Workflow file viewer dialog ───────────────────────────────
class _WfFileViewerDialog extends StatelessWidget {
  final _WfFileItem item;
  const _WfFileViewerDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final isImage = item.fileType == 'image';
    final displayName =
        item.fileName.isNotEmpty ? item.fileName : item.filePath.split('/').last;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: isImage
                    ? AppColors.info.withOpacity(0.08)
                    : AppColors.blue.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                border: const Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    isImage ? Icons.image_outlined : Icons.article_outlined,
                    color: isImage ? AppColors.info : AppColors.blue,
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      displayName,
                      style: AppTextStyles.h4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: isImage
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _WfImageDescView(
                          description: item.imageDescription ?? ''),
                    )
                  : _WfDocumentView(fileText: item.fileText ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}

class _WfDocumentView extends StatefulWidget {
  final String fileText;
  const _WfDocumentView({required this.fileText});

  @override
  State<_WfDocumentView> createState() => _WfDocumentViewState();
}

class _WfDocumentViewState extends State<_WfDocumentView> {
  final _scrollController = ScrollController();
  final _sectionKeys = <GlobalKey>[];
  int _activeSection = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(int index) {
    if (index < 0 || index >= _sectionKeys.length) return;
    setState(() => _activeSection = index);
    final ctx = _sectionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fileText.isEmpty) {
      return Center(
        child: Text('No content available.',
            style: AppTextStyles.body.copyWith(color: AppColors.muted)),
      );
    }

    try {
      final data = jsonDecode(widget.fileText) as Map<String, dynamic>;
      final title = data['title'] as String? ?? '';
      final sections = (data['content'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      // Grow key list as needed
      while (_sectionKeys.length < sections.length) {
        _sectionKeys.add(GlobalKey());
      }

      final hasToc = sections.length >= 2 &&
          sections.any((s) => (s['sectionName'] as String? ?? '').isNotEmpty);

      if (hasToc) {
        // ── Two-panel layout ──────────────────────────────────
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left TOC panel
            Container(
              width: 190,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F8),
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                    child: Text(
                      'CONTENTS',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.muted,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sections.length,
                      itemBuilder: (context, i) {
                        final name =
                            sections[i]['sectionName'] as String? ?? '';
                        final isActive = i == _activeSection;
                        return InkWell(
                          onTap: () => _scrollTo(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.blue.withOpacity(0.08)
                                  : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: isActive
                                      ? AppColors.blue
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${i + 1}',
                                  style: AppTextStyles.label.copyWith(
                                    fontSize: 11,
                                    color: isActive
                                        ? AppColors.blue
                                        : AppColors.muted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Gap(8),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 12,
                                      color: isActive
                                          ? AppColors.blue
                                          : AppColors.text,
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Right content panel
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) ...[
                      Text(title,
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.text)),
                      const Gap(12),
                      const Divider(color: AppColors.border),
                      const Gap(16),
                    ],
                    ...List.generate(sections.length, (i) {
                      final s = sections[i];
                      final sName = s['sectionName'] as String? ?? '';
                      final sContent = s['sectionContent'] as String? ?? '';
                      return Padding(
                        key: _sectionKeys[i],
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (sName.isNotEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: AppColors.blue,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const Gap(8),
                                  Expanded(
                                    child: Text(
                                      sName,
                                      style: AppTextStyles.label.copyWith(
                                        color: AppColors.blue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(10),
                            ],
                            SelectableText(sContent,
                                style:
                                    AppTextStyles.body.copyWith(height: 1.7)),
                          ],
                        ),
                      );
                    }),
                    const Gap(40),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      // ── Single-column fallback ────────────────────────────
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(title,
                  style: AppTextStyles.h3.copyWith(color: AppColors.text)),
              const Gap(12),
              const Divider(color: AppColors.border),
              const Gap(16),
            ],
            ...sections.map((s) {
              final sName = s['sectionName'] as String? ?? '';
              final sContent = s['sectionContent'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sName.isNotEmpty) ...[
                      Text(sName,
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.blue,
                              fontWeight: FontWeight.w700)),
                      const Gap(4),
                    ],
                    SelectableText(sContent,
                        style: AppTextStyles.body.copyWith(height: 1.55)),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    } catch (_) {
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: SelectableText(widget.fileText, style: AppTextStyles.body),
      );
    }
  }
}

class _WfImageDescView extends StatelessWidget {
  final String description;
  const _WfImageDescView({required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 14, color: AppColors.info),
            const Gap(6),
            Text('AI Image Description',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.info)),
          ]),
          const Gap(10),
          SelectableText(description,
              style: AppTextStyles.body.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}
