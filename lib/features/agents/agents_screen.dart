import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_localizations.dart';

// ── Palette ─────────────────────────────────────────────────────
const _kGrad1 = Color(0xFF1A237E); // deep indigo
const _kGrad2 = Color(0xFF3949AB); // mid indigo

// ── Agent type colour mapping ────────────────────────────────────
Color _typeColor(int typeId) {
  switch (typeId) {
    case 1:
      return const Color(0xFF2E7D32); // Evidence Reviewer – green
    case 2:
      return const Color(0xFF1565C0); // Compliance Report – blue
    case 3:
      return const Color(0xFFE65100); // Escalation – orange
    case 4:
      return const Color(0xFF6A1B9A); // Onboarding – purple
    case 5:
      return const Color(0xFF00695C); // Reg Change Watcher – teal
    case 11:
      return const Color(0xFFC62828); // Workflow Gap Analyzer / taskCreator – red
    default:
      return AppColors.muted;
  }
}

// ── State ────────────────────────────────────────────────────────
class _AgentState {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> agentTypes;
  final int total;
  final int page;
  final int pages;
  final bool isLoading;
  final String? error;
  final String search;
  final bool includeInactive;

  const _AgentState({
    this.items = const [],
    this.agentTypes = const [],
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    this.isLoading = true,
    this.error,
    this.search = '',
    this.includeInactive = false,
  });

  _AgentState copyWith({
    List<Map<String, dynamic>>? items,
    List<Map<String, dynamic>>? agentTypes,
    int? total,
    int? page,
    int? pages,
    bool? isLoading,
    String? error,
    String? search,
    bool? includeInactive,
  }) =>
      _AgentState(
        items: items ?? this.items,
        agentTypes: agentTypes ?? this.agentTypes,
        total: total ?? this.total,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        search: search ?? this.search,
        includeInactive: includeInactive ?? this.includeInactive,
      );
}

// ── Notifier ─────────────────────────────────────────────────────
class _AgentNotifier extends StateNotifier<_AgentState> {
  final Dio _dio;
  _AgentNotifier(this._dio) : super(const _AgentState()) {
    _loadTypes().then((_) => load());
  }

  Future<void> _loadTypes() async {
    try {
      final res = await _dio.get<List<dynamic>>('/agent-types');
      state = state.copyWith(
        agentTypes: (res.data ?? []).cast<Map<String, dynamic>>(),
      );
    } catch (_) {}
  }

  Future<void> load({String? search, int? page, bool? includeInactive}) async {
    final s = search ?? state.search;
    final p = page ?? state.page;
    final inc = includeInactive ?? state.includeInactive;
    state = state.copyWith(
      isLoading: true,
      error: null,
      search: s,
      page: p,
      includeInactive: inc,
    );
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/agents',
        queryParameters: {
          'search': s,
          'page': p,
          'page_size': 20,
          'include_inactive': inc,
        },
      );
      final data = res.data!;
      state = state.copyWith(
        isLoading: false,
        items: (data['items'] as List).cast<Map<String, dynamic>>(),
        total: data['total'] as int,
        pages: data['pages'] as int,
        page: data['page'] as int,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['detail'] as String? ?? e.message,
      );
    }
  }

  Future<bool> save(Map<String, dynamic> body, {String? id}) async {
    try {
      if (id == null) {
        await _dio.post('/agents', data: body);
      } else {
        await _dio.put('/agents/$id', data: body);
      }
      await load();
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> deactivate(String id) async {
    try {
      await _dio.delete('/agents/$id');
      await load();
      return true;
    } on DioException {
      return false;
    }
  }

  /// Loads the full agent record (including llm_api_key) before editing.
  Future<Map<String, dynamic>?> fetchFull(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/agents/$id');
      return res.data;
    } on DioException {
      return null;
    }
  }

  Future<bool> duplicate(Map<String, dynamic> agent) async {
    final suffix = Random().nextInt(1000) + 1;
    final body = <String, dynamic>{
      'name': '${agent['name']} $suffix',
      'description': agent['description'],
      'type_id': agent['typeId'],
      'prompt': agent['prompt'],
      'schedule': agent['schedule'],
      'is_active': agent['isActive'] ?? true,
      'is_default': false,
      'llm_provider': agent['llmProvider'],
      'llm_model': agent['llmModel'],
      'llm_api_key': agent['llmApiKey'],
      'max_tokens': agent['maxTokens'],
      'temperature': agent['temperature'],
      'llm_agent_url': agent['llmAgentUrl'],
    };
    return save(body);
  }
}

// ── Provider ─────────────────────────────────────────────────────
final _agentProvider =
    StateNotifierProvider.autoDispose<_AgentNotifier, _AgentState>(
  (ref) => _AgentNotifier(ref.watch(dioProvider)),
);

// ── Screen ───────────────────────────────────────────────────────
class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final st = ref.watch(_agentProvider);
    final notifier = ref.read(_agentProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          _Header(
            l10n: l10n,
            onAdd: () => _openDialog(context, notifier, st.agentTypes),
          ),
          // ── Toolbar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.search,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) =>
                          notifier.load(search: v, page: 1),
                    ),
                  ),
                ),
                const Gap(12),
                FilterChip(
                  label: Text(l10n.showInactive),
                  selected: st.includeInactive,
                  onSelected: (v) =>
                      notifier.load(includeInactive: v, page: 1),
                ),
              ],
            ),
          ),
          const Gap(12),
          // ── Body ────────────────────────────────────────────────
          Expanded(
            child: _Body(
              state: st,
              agentTypes: st.agentTypes,
              notifier: notifier,
              l10n: l10n,
            ),
          ),
          // ── Pagination ──────────────────────────────────────────
          if (!st.isLoading && st.error == null && st.pages > 1)
            _Pagination(state: st, notifier: notifier),
        ],
      ),
    );
  }

  void _openDialog(
    BuildContext context,
    _AgentNotifier notifier,
    List<Map<String, dynamic>> types,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AgentDialog(
        agentTypes: types,
        onSave: (body) async {
          final ok = await notifier.save(body);
          if (ok && context.mounted) Navigator.pop(context);
          return ok;
        },
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onAdd;
  const _Header({required this.l10n, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad1, _kGrad2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 28),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.navAgents,
                    style: AppTextStyles.h2.copyWith(color: Colors.white)),
                Text(l10n.agentsSubtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.addAgent),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _kGrad1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────
class _Body extends ConsumerWidget {
  final _AgentState state;
  final List<Map<String, dynamic>> agentTypes;
  final _AgentNotifier notifier;
  final AppLocalizations l10n;

  const _Body({
    required this.state,
    required this.agentTypes,
    required this.notifier,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) return _shimmer();
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const Gap(8),
            Text(state.error!, style: AppTextStyles.body),
            const Gap(12),
            OutlinedButton(
              onPressed: notifier.load,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined,
                size: 64, color: AppColors.border),
            const Gap(12),
            Text(l10n.noAgentsFound, style: AppTextStyles.body),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: state.items.length,
      itemBuilder: (context, i) {
        final agent = state.items[i];
        return _AgentCard(
          agent: agent,
          agentTypes: agentTypes,
          l10n: l10n,
          onEdit: () async {
            // Fetch the full agent (includes llm_api_key) before opening
            final full = await notifier.fetchFull(agent['id'] as String);
            if (!context.mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => _AgentDialog(
                agent: full ?? agent,
                agentTypes: agentTypes,
                onSave: (body) async {
                  final ok =
                      await notifier.save(body, id: agent['id'] as String);
                  if (ok && context.mounted) Navigator.pop(context);
                  return ok;
                },
              ),
            );
          },
          onDuplicate: () async {
            final ok = await notifier.duplicate(agent);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? l10n.agentDuplicated : l10n.error),
                  backgroundColor: ok ? AppColors.success : AppColors.danger,
                ),
              );
            }
          },
          onDeactivate: () async {
            final ok = await notifier.deactivate(agent['id'] as String);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.error)),
              );
            }
          },
        ).animate().fadeIn(duration: 220.ms, delay: (i * 30).ms);
      },
    );
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 88,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.card,
          ),
        ),
      ),
    );
  }
}

// ── Agent Card ───────────────────────────────────────────────────
class _AgentCard extends StatefulWidget {
  final Map<String, dynamic> agent;
  final List<Map<String, dynamic>> agentTypes;
  final AppLocalizations l10n;
  final Future<void> Function() onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDeactivate;

  const _AgentCard({
    required this.agent,
    required this.agentTypes,
    required this.l10n,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDeactivate,
  });

  @override
  State<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<_AgentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    final l10n = widget.l10n;
    final typeId = (a['typeId'] as int?) ?? 0;
    final typeName = a['typeName'] as String? ?? '';
    final isActive = (a['isActive'] as bool?) ?? true;
    final isDefault = (a['isDefault'] as bool?) ?? false;
    final color = _typeColor(typeId);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: _hovered ? color.withOpacity(0.4) : AppColors.border,
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Type colour dot
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(12),
                // Main info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a['name'] as String? ?? '',
                              style: AppTextStyles.h4,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDefault) ...[
                            const Gap(6),
                            _Badge(
                              label: l10n.agentDefault,
                              color: AppColors.orange,
                            ),
                          ],
                          if (!isActive) ...[
                            const Gap(6),
                            _Badge(
                              label: l10n.inactive,
                              color: AppColors.muted,
                            ),
                          ],
                        ],
                      ),
                      const Gap(4),
                      Row(
                        children: [
                          _Badge(label: typeName, color: color),
                          if (a['schedule'] != null &&
                              (a['schedule'] as String).isNotEmpty) ...[
                            const Gap(6),
                            Icon(Icons.schedule,
                                size: 12, color: AppColors.muted),
                            const Gap(3),
                            Text(
                              a['schedule'] as String,
                              style: AppTextStyles.caption,
                            ),
                          ] else ...[
                            const Gap(6),
                            Icon(Icons.bolt_outlined,
                                size: 12, color: AppColors.muted),
                            const Gap(3),
                            Text(
                              l10n.agentTriggered,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ],
                      ),
                      if (a['description'] != null &&
                          (a['description'] as String).isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          a['description'] as String,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(8),
                // LLM provider badge
                if (a['llmProvider'] != null &&
                    (a['llmProvider'] as String).isNotEmpty)
                  _Badge(
                    label: a['llmProvider'] as String,
                    color: AppColors.info,
                  ),
                const Gap(8),
                // Actions
                _ActionIcon(
                  icon: Icons.edit_outlined,
                  tooltip: l10n.edit,
                  color: color,
                  onTap: widget.onEdit,
                ),
                const Gap(4),
                _ActionIcon(
                  icon: Icons.copy_outlined,
                  tooltip: l10n.duplicate,
                  color: AppColors.blue,
                  onTap: widget.onDuplicate,
                ),
                const Gap(4),
                if (isActive)
                  _ActionIcon(
                    icon: Icons.pause_circle_outline,
                    tooltip: l10n.deactivate,
                    color: AppColors.muted,
                    onTap: widget.onDeactivate,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Badge ────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.tag.copyWith(color: color),
      ),
    );
  }
}

// ── Action Icon ──────────────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ── Pagination ───────────────────────────────────────────────────
class _Pagination extends StatelessWidget {
  final _AgentState state;
  final _AgentNotifier notifier;
  const _Pagination({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: state.page > 1
                ? () => notifier.load(page: state.page - 1)
                : null,
          ),
          Text('${state.page} / ${state.pages}',
              style: AppTextStyles.body),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: state.page < state.pages
                ? () => notifier.load(page: state.page + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

// ── Create / Edit Dialog ─────────────────────────────────────────
class _AgentDialog extends StatefulWidget {
  final Map<String, dynamic>? agent;
  final List<Map<String, dynamic>> agentTypes;
  final Future<bool> Function(Map<String, dynamic> body) onSave;

  const _AgentDialog({
    this.agent,
    required this.agentTypes,
    required this.onSave,
  });

  @override
  State<_AgentDialog> createState() => _AgentDialogState();
}

class _AgentDialogState extends State<_AgentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _scheduleCtrl;
  late final TextEditingController _providerCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _maxTokensCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _agentUrlCtrl;

  int? _selectedTypeId;
  bool _isActive = true;
  bool _isDefault = false;
  bool _saving = false;
  bool _showApiKey = false;

  bool get _isEdit => widget.agent != null;

  @override
  void initState() {
    super.initState();
    final a = widget.agent;
    _nameCtrl = TextEditingController(text: a?['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: a?['description'] as String? ?? '');
    _promptCtrl = TextEditingController(text: a?['prompt'] as String? ?? '');
    _scheduleCtrl = TextEditingController(text: a?['schedule'] as String? ?? '');
    _providerCtrl =
        TextEditingController(text: a?['llmProvider'] as String? ?? '');
    _modelCtrl = TextEditingController(text: a?['llmModel'] as String? ?? '');
    _apiKeyCtrl =
        TextEditingController(text: a?['llmApiKey'] as String? ?? '');
    _maxTokensCtrl = TextEditingController(
        text: a?['maxTokens'] != null ? '${a!['maxTokens']}' : '');
    _tempCtrl = TextEditingController(
        text: a?['temperature'] != null ? '${a!['temperature']}' : '');
    _agentUrlCtrl =
        TextEditingController(text: a?['llmAgentUrl'] as String? ?? '');
    _selectedTypeId = a?['typeId'] as int?;
    _isActive = (a?['isActive'] as bool?) ?? true;
    _isDefault = (a?['isDefault'] as bool?) ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    _scheduleCtrl.dispose();
    _providerCtrl.dispose();
    _modelCtrl.dispose();
    _apiKeyCtrl.dispose();
    _maxTokensCtrl.dispose();
    _tempCtrl.dispose();
    _agentUrlCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: _kGrad1, width: 2),
        ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        labelStyle: AppTextStyles.label,
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'type_id': _selectedTypeId,
      'prompt': _promptCtrl.text.trim().isEmpty ? null : _promptCtrl.text.trim(),
      'schedule':
          _scheduleCtrl.text.trim().isEmpty ? null : _scheduleCtrl.text.trim(),
      'is_active': _isActive,
      'is_default': _isDefault,
      'llm_provider': _providerCtrl.text.trim().isEmpty
          ? null
          : _providerCtrl.text.trim(),
      'llm_model':
          _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      'llm_api_key':
          _apiKeyCtrl.text.trim().isEmpty ? null : _apiKeyCtrl.text.trim(),
      'max_tokens': _maxTokensCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_maxTokensCtrl.text.trim()),
      'temperature': _tempCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_tempCtrl.text.trim()),
      'llm_agent_url':
          _agentUrlCtrl.text.trim().isEmpty ? null : _agentUrlCtrl.text.trim(),
    };
    await widget.onSave(body);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = _isEdit;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient header ────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kGrad1, _kGrad2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_outlined,
                      color: Colors.white, size: 22),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      isEdit ? l10n.editAgent : l10n.addAgent,
                      style: AppTextStyles.h3.copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── Form ──────────────────────────────────────────
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDeco(l10n.agentName),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.required
                            : null,
                      ),
                      const Gap(12),
                      // Description
                      TextFormField(
                        controller: _descCtrl,
                        decoration: _inputDeco(l10n.description),
                        maxLines: 2,
                      ),
                      const Gap(12),
                      // Agent Type
                      DropdownButtonFormField<int>(
                        value: _selectedTypeId,
                        decoration: _inputDeco(l10n.agentType),
                        items: widget.agentTypes.map((t) {
                          return DropdownMenuItem<int>(
                            value: t['id'] as int,
                            child: Text(t['typeName'] as String? ?? ''),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedTypeId = v),
                        validator: (v) =>
                            v == null ? l10n.required : null,
                      ),
                      // JSON structured output preview
                      if (_selectedTypeId != null) ...[
                        const Gap(8),
                        _JsonOutputPreview(
                          agentTypes: widget.agentTypes,
                          selectedTypeId: _selectedTypeId!,
                          l10n: l10n,
                        ),
                      ],
                      const Gap(16),
                      // ── LLM Config section ─────────────────
                      Text(l10n.llmConfig,
                          style: AppTextStyles.label.copyWith(
                              color: _kGrad1, letterSpacing: 0.5)),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _providerCtrl,
                              decoration: _inputDeco(l10n.llmProvider,
                                  hint: 'openai, anthropic…'),
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: TextFormField(
                              controller: _modelCtrl,
                              decoration: _inputDeco(l10n.llmModel,
                                  hint: 'gpt-4o, claude-3-5-sonnet…'),
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      TextFormField(
                        controller: _apiKeyCtrl,
                        obscureText: !_showApiKey,
                        decoration: _inputDeco(
                          l10n.llmApiKey,
                          suffix: IconButton(
                            icon: Icon(_showApiKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _showApiKey = !_showApiKey),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _maxTokensCtrl,
                              decoration:
                                  _inputDeco(l10n.llmMaxTokens, hint: '4096'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: TextFormField(
                              controller: _tempCtrl,
                              decoration: _inputDeco(l10n.llmTemperature,
                                  hint: '0.7'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      TextFormField(
                        controller: _agentUrlCtrl,
                        decoration: _inputDeco(l10n.llmAgentUrl,
                            hint: 'https://…'),
                      ),
                      const Gap(16),
                      // ── Schedule / Prompt ──────────────────
                      Text(l10n.agentBehavior,
                          style: AppTextStyles.label.copyWith(
                              color: _kGrad1, letterSpacing: 0.5)),
                      const Gap(8),
                      TextFormField(
                        controller: _scheduleCtrl,
                        decoration: _inputDeco(l10n.agentSchedule,
                            hint: '0 9 * * * (leave empty = triggered)'),
                      ),
                      const Gap(12),
                      TextFormField(
                        controller: _promptCtrl,
                        decoration: _inputDeco(l10n.agentPrompt),
                        maxLines: 5,
                      ),
                      const Gap(16),
                      // ── Toggles ────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: Text(l10n.active,
                                  style: AppTextStyles.body),
                              value: _isActive,
                              onChanged: (v) =>
                                  setState(() => _isActive = v ?? true),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: Text(l10n.agentIsDefault,
                                  style: AppTextStyles.body),
                              value: _isDefault,
                              onChanged: (v) =>
                                  setState(() => _isDefault = v ?? false),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Actions ──────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const Gap(10),
                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── JSON Structured Output Preview ────────────────────────────────
/// Collapsible panel shown below the type dropdown in the dialog.
/// Displays the expected JSON output schema for the selected agent type.
class _JsonOutputPreview extends StatefulWidget {
  final List<Map<String, dynamic>> agentTypes;
  final int selectedTypeId;
  final AppLocalizations l10n;

  const _JsonOutputPreview({
    required this.agentTypes,
    required this.selectedTypeId,
    required this.l10n,
  });

  @override
  State<_JsonOutputPreview> createState() => _JsonOutputPreviewState();
}

class _JsonOutputPreviewState extends State<_JsonOutputPreview> {
  bool _expanded = false;

  @override
  void didUpdateWidget(_JsonOutputPreview old) {
    super.didUpdateWidget(old);
    // Collapse when the user switches type
    if (old.selectedTypeId != widget.selectedTypeId) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.agentTypes.firstWhere(
      (t) => t['id'] == widget.selectedTypeId,
      orElse: () => {},
    );
    final json =
        type['jsonStructuredOutput'] as String? ?? '';
    if (json.trim().isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: AppRadius.card,
        border: Border.all(color: _kGrad2.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row — always visible ────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: AppRadius.card,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.data_object_outlined,
                      size: 15, color: _kGrad1),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      widget.l10n.jsonOutputSchema,
                      style: AppTextStyles.label
                          .copyWith(color: _kGrad1, letterSpacing: 0.4),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: _kGrad1,
                  ),
                ],
              ),
            ),
          ),
          // ── Expandable JSON body ────────────────────────────
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SelectableText(
                json.trim(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: Color(0xFF1A237E),
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
