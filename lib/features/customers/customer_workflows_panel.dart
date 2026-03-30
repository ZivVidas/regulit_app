/// Dialog panel for managing which workflows are linked to a customer.
/// Opened from the customer dashboard → "Manage Workflows" button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad0 = Color(0xFF1B4D3E);
const _kGrad1 = Color(0xFF2E7D5C);

// ── State ─────────────────────────────────────────────────────
class _PanelState {
  final List<Map<String, dynamic>> links;
  final bool isLoading;
  final String? error;

  const _PanelState({
    this.links = const [],
    this.isLoading = true,
    this.error,
  });

  _PanelState copyWith({
    List<Map<String, dynamic>>? links,
    bool? isLoading,
    String? error,
  }) =>
      _PanelState(
        links: links ?? this.links,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class _PanelNotifier extends StateNotifier<_PanelState> {
  final dynamic _dio;
  final String customerId;

  _PanelNotifier(this._dio, this.customerId) : super(const _PanelState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res =
          await _dio.get<List<dynamic>>('/customers/$customerId/workflows');
      state = state.copyWith(
        isLoading: false,
        links: (res.data as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> link(String workflowId) async {
    await _dio.post<dynamic>(
      '/customers/$customerId/workflows',
      data: {'workflowId': workflowId},
    );
    await load();
  }

  Future<void> unlink(String workflowId) async {
    await _dio.delete<dynamic>(
        '/customers/$customerId/workflows/$workflowId');
    await load();
  }
}

// ── Entry point ───────────────────────────────────────────────
void showCustomerWorkflowsPanel(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> customer,
) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: CustomerWorkflowsPanel(customer: customer),
    ),
  );
}

// ── Panel widget ──────────────────────────────────────────────
class CustomerWorkflowsPanel extends ConsumerStatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerWorkflowsPanel({super.key, required this.customer});

  @override
  ConsumerState<CustomerWorkflowsPanel> createState() =>
      _CustomerWorkflowsPanelState();
}

class _CustomerWorkflowsPanelState
    extends ConsumerState<CustomerWorkflowsPanel> {
  late final StateNotifierProvider<_PanelNotifier, _PanelState> _provider;

  // ── Link-form state ─────────────────────────────────────────
  bool _linking = false;
  List<Map<String, dynamic>> _availableWorkflows = [];
  bool _loadingWorkflows = false;
  String? _selectedWorkflowId;
  bool _saving = false;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    final cid = widget.customer['id'] as String;
    _provider = StateNotifierProvider<_PanelNotifier, _PanelState>(
      (r) => _PanelNotifier(r.watch(dioProvider), cid),
    );
  }

  Future<void> _startLinking() async {
    setState(() {
      _linking = true;
      _loadingWorkflows = true;
      _selectedWorkflowId = null;
      _linkError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get<Map<String, dynamic>>(
        '/workflows',
        queryParameters: {'page': 1, 'page_size': 500},
      );
      final all =
          ((res.data!['items']) as List).cast<Map<String, dynamic>>();

      final linkedIds = ref
          .read(_provider)
          .links
          .map((l) => l['workflowId'] as String)
          .toSet();

      setState(() {
        _availableWorkflows = all
            .where((w) =>
                (w['isActive'] as bool? ?? true) &&
                !linkedIds.contains(w['id'] as String))
            .toList();
        _loadingWorkflows = false;
        if (_availableWorkflows.isNotEmpty) {
          _selectedWorkflowId =
              _availableWorkflows.first['id'] as String;
        }
      });
    } catch (e) {
      setState(() {
        _loadingWorkflows = false;
        _linking = false;
      });
    }
  }

  void _cancelLinking() => setState(() {
        _linking = false;
        _linkError = null;
        _selectedWorkflowId = null;
      });

  Future<void> _submitLink() async {
    final wfId = _selectedWorkflowId;
    if (wfId == null) return;

    setState(() {
      _saving = true;
      _linkError = null;
    });

    try {
      await ref.read(_provider.notifier).link(wfId);
      setState(() {
        _linking = false;
        _saving = false;
        _selectedWorkflowId = null;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _linkError = e
            .toString()
            .replaceAll('DioException [bad response]:', '')
            .trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_provider);
    final customerName =
        widget.customer['name'] as String? ?? 'Customer';

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, customerName),
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: _linking ? 220 : 460),
              child: _buildLinkedList(s),
            ),
            if (_linking) _buildLinkForm(),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .scale(
          begin: const Offset(0.93, 0.93),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, String customerName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad0, _kGrad1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined,
              color: Colors.white, size: 22),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Linked Workflows',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Text(
                  customerName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _linking ? Icons.close : Icons.add_link_rounded,
              color: Colors.white,
            ),
            tooltip: _linking ? 'Cancel' : 'Link a Workflow',
            onPressed: _linking ? _cancelLinking : _startLinking,
          ),
          IconButton(
            icon: const Icon(Icons.close,
                color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  // ── Linked workflows list ────────────────────────────────────
  Widget _buildLinkedList(_PanelState s) {
    if (s.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (s.error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 40),
            const Gap(10),
            Text(s.error!,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.danger),
                textAlign: TextAlign.center),
            const Gap(14),
            OutlinedButton(
              onPressed: () => ref.read(_provider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (s.links.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 48, color: _kGrad0.withOpacity(0.3)),
            const Gap(12),
            Text(
              'No workflows linked yet.',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
            const Gap(16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kGrad0),
              onPressed: _linking ? null : _startLinking,
              icon: const Icon(Icons.add_link_rounded, size: 16),
              label: const Text('Link first workflow'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: s.links.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) {
        final link = s.links[i];
        return _WorkflowLinkTile(
          link: link,
          index: i,
          onUnlink: () => ref
              .read(_provider.notifier)
              .unlink(link['workflowId'] as String),
        );
      },
    );
  }

  // ── Inline link form ─────────────────────────────────────────
  Widget _buildLinkForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section label
              Row(
                children: [
                  const Icon(Icons.add_link_rounded,
                      size: 16, color: _kGrad0),
                  const Gap(6),
                  Text(
                    'Link a Workflow',
                    style: AppTextStyles.h4.copyWith(color: _kGrad0),
                  ),
                ],
              ),
              const Gap(14),

              // Error banner
              if (_linkError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _linkError!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.danger),
                  ),
                ),
                const Gap(10),
              ],

              // Workflow dropdown
              Text('Select Workflow', style: AppTextStyles.label),
              const Gap(4),
              if (_loadingWorkflows)
                const LinearProgressIndicator()
              else if (_availableWorkflows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No active workflows available to link.',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedWorkflowId,
                  decoration: const InputDecoration(isDense: true),
                  items: _availableWorkflows
                      .map((w) => DropdownMenuItem(
                            value: w['id'] as String,
                            child: Text(
                              w['name'] as String? ?? '—',
                              style: AppTextStyles.body,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedWorkflowId = v),
                ),
              const Gap(16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : _cancelLinking,
                    child: const Text('Cancel'),
                  ),
                  const Gap(8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _kGrad0),
                    onPressed: (_saving ||
                            _loadingWorkflows ||
                            _availableWorkflows.isEmpty ||
                            _selectedWorkflowId == null)
                        ? null
                        : _submitLink,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.link_rounded, size: 16),
                    label: const Text('Link'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Linked workflow tile ──────────────────────────────────────
class _WorkflowLinkTile extends StatelessWidget {
  final Map<String, dynamic> link;
  final int index;
  final VoidCallback onUnlink;

  const _WorkflowLinkTile({
    required this.link,
    required this.index,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final name = link['workflowName'] as String? ?? '—';
    final desc = link['workflowDescription'] as String?;
    final isActive = link['isActive'] as bool? ?? true;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: _kGrad1.withOpacity(0.12),
        child: Text(
          initial,
          style: const TextStyle(
            color: _kGrad0,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        name,
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: desc != null && desc.isNotEmpty
          ? Text(desc,
              style: AppTextStyles.caption,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active badge
          if (!isActive)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Inactive',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          if (!isActive) const Gap(4),
          IconButton(
            icon: const Icon(Icons.link_off_outlined,
                size: 18, color: AppColors.danger),
            tooltip: 'Unlink',
            onPressed: onUnlink,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 40).ms, duration: 280.ms)
        .slideX(begin: 0.08, delay: (index * 40).ms, duration: 280.ms);
  }
}
