/// Per-customer dashboard — shows active-session picker, compliance metrics,
/// task counts, linked users, and linked workflows.
/// Route: /admin/customers/:customerId/dashboard
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import 'customer_users_panel.dart';
import 'customer_workflows_panel.dart';

// ── Colour constants ──────────────────────────────────────────
const _kGrad0 = Color(0xFFEA580C);
const _kGrad1 = Color(0xFFF97316);

// ─────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────

class _CustDashData {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> links;
  final List<Map<String, dynamic>> workflowLinks;

  const _CustDashData({
    required this.customer,
    required this.links,
    required this.workflowLinks,
  });
}

class _SessionItem {
  final String id;
  final String workflowName;
  const _SessionItem({required this.id, required this.workflowName});

  factory _SessionItem.fromJson(Map<String, dynamic> j) => _SessionItem(
        id: j['id'] as String,
        workflowName: j['workflowName'] as String? ?? '—',
      );
}

class _DashSummary {
  final double? complianceScore;
  final double? totalExposure;
  final String? evaluationDate;
  final int openTasks;
  final int closedTasks;
  final int totalTasks;

  const _DashSummary({
    required this.complianceScore,
    required this.totalExposure,
    required this.evaluationDate,
    required this.openTasks,
    required this.closedTasks,
    required this.totalTasks,
  });

  factory _DashSummary.fromJson(Map<String, dynamic> j) => _DashSummary(
        complianceScore: (j['complianceScore'] as num?)?.toDouble(),
        totalExposure: (j['totalExposure'] as num?)?.toDouble(),
        evaluationDate: j['evaluationDate'] as String?,
        openTasks: j['openTasks'] as int? ?? 0,
        closedTasks: j['closedTasks'] as int? ?? 0,
        totalTasks: j['totalTasks'] as int? ?? 0,
      );

  bool get hasEvaluation => complianceScore != null || totalExposure != null;
}

// ─────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────

// Static customer info (users, workflows)
final _custDashProvider = FutureProvider.autoDispose
    .family<_CustDashData, String>((ref, customerId) async {
  final dio = ref.watch(dioProvider);
  final results = await Future.wait([
    dio.get<Map<String, dynamic>>('/customers/$customerId'),
    dio.get<List<dynamic>>('/customers/$customerId/users'),
    dio.get<List<dynamic>>('/customers/$customerId/workflows'),
  ]);
  return _CustDashData(
    customer: (results[0] as Response<Map<String, dynamic>>).data!,
    links: ((results[1] as Response<List<dynamic>>).data ?? [])
        .cast<Map<String, dynamic>>(),
    workflowLinks: ((results[2] as Response<List<dynamic>>).data ?? [])
        .cast<Map<String, dynamic>>(),
  );
});

// Active workflow-answer sessions for the session picker
final _dashSessionsProvider =
    FutureProvider.autoDispose.family<List<_SessionItem>, String>(
  (ref, customerId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<List<dynamic>>(
      '/workflow-answers/active-sessions/$customerId',
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(_SessionItem.fromJson)
        .toList();
  },
);

// Dashboard summary for the selected session
final _dashSummaryProvider =
    FutureProvider.autoDispose.family<_DashSummary, String>(
  (ref, sessionId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<Map<String, dynamic>>(
      '/workflow-answers/$sessionId/dashboard-summary',
    );
    return _DashSummary.fromJson(res.data!);
  },
);

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class CustomerDashboardScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDashboardScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState
    extends ConsumerState<CustomerDashboardScreen> {
  String? _selectedSessionId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_custDashProvider(widget.customerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header (always shown) ──────────────────────────
          async.when(
            loading: () => _HeaderShell(
                customerName: '…', onBack: () => Navigator.pop(context)),
            error: (_, __) => _HeaderShell(
                customerName: 'Error', onBack: () => Navigator.pop(context)),
            data: (d) => _Header(
              customer: d.customer,
              onBack: () => Navigator.pop(context),
              onManageUsers: () =>
                  showCustomerUsersPanel(context, ref, d.customer),
              onManageWorkflows: () =>
                  showCustomerWorkflowsPanel(context, ref, d.customer),
              onRefresh: () {
                ref.invalidate(_custDashProvider(widget.customerId));
                ref.invalidate(_dashSessionsProvider(widget.customerId));
                if (_selectedSessionId != null) {
                  ref.invalidate(_dashSummaryProvider(_selectedSessionId!));
                }
              },
            ),
          ),

          // ── Body ──────────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.danger),
                    const Gap(12),
                    Text(e.toString(),
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.danger)),
                    const Gap(16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(_custDashProvider(widget.customerId)),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (d) => _Body(
                data: d,
                customerId: widget.customerId,
                selectedSessionId: _selectedSessionId,
                onSessionChanged: (id) =>
                    setState(() => _selectedSessionId = id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────
class _HeaderShell extends StatelessWidget {
  final String customerName;
  final VoidCallback onBack;
  const _HeaderShell({required this.customerName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad0, _kGrad1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 14),
          child: Row(
            children: [
              BackButton(color: Colors.white, onPressed: onBack),
              Text(customerName,
                  style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onBack;
  final VoidCallback onManageUsers;
  final VoidCallback onManageWorkflows;
  final VoidCallback onRefresh;

  const _Header({
    required this.customer,
    required this.onBack,
    required this.onManageUsers,
    required this.onManageWorkflows,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final tier = customer['subscriptionTier'] as String? ?? 'basic';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad0, _kGrad1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x40EA580C),
              blurRadius: 16,
              offset: Offset(0, 4))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 16),
          child: Row(
            children: [
              BackButton(color: Colors.white, onPressed: onBack),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['name'] as String? ?? '—',
                      style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                    if ((customer['industry'] as String?)?.isNotEmpty == true)
                      Text(
                        customer['industry'] as String,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tier[0].toUpperCase()}${tier.substring(1)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
              const Gap(6),
              IconButton(
                icon: const Icon(Icons.group_outlined, color: Colors.white),
                tooltip: 'Manage users',
                onPressed: onManageUsers,
              ),
              IconButton(
                icon: const Icon(Icons.account_tree_outlined,
                    color: Colors.white),
                tooltip: 'Manage workflows',
                onPressed: onManageWorkflows,
              ),
              IconButton(
                icon:
                    const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Refresh',
                onPressed: onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────
class _Body extends ConsumerWidget {
  final _CustDashData data;
  final String customerId;
  final String? selectedSessionId;
  final ValueChanged<String?> onSessionChanged;

  const _Body({
    required this.data,
    required this.customerId,
    required this.selectedSessionId,
    required this.onSessionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = data.customer;
    final links = data.links;

    final roleCounts = <String, int>{};
    for (final l in links) {
      final r = l['role'] as String? ?? 'employee';
      roleCounts[r] = (roleCounts[r] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Session picker + metrics ───────────────────────
          _SessionSection(
            customerId: customerId,
            selectedSessionId: selectedSessionId,
            onSessionChanged: onSessionChanged,
          ),
          const Gap(20),

          // ── Customer info card ─────────────────────────────
          _InfoCard(c: c),
          const Gap(16),

          // ── Stats row ──────────────────────────────────────
          _StatsRow(links: links, roleCounts: roleCounts),
          const Gap(20),

          // ── Linked users list ──────────────────────────────
          Row(
            children: [
              const Icon(Icons.people_outlined,
                  size: 18, color: AppColors.muted),
              const Gap(8),
              Text('Linked Users (${links.length})',
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    showCustomerUsersPanel(context, ref, c),
                icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                label: const Text('Manage'),
              ),
            ],
          ),
          const Gap(8),
          if (links.isEmpty)
            _emptyCard('No users linked yet.')
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: links.asMap().entries.map((e) {
                  return _LinkedUserRow(
                      link: e.value,
                      index: e.key,
                      isLast: e.key == links.length - 1);
                }).toList(),
              ),
            ),

          // ── Linked workflows ───────────────────────────────
          const Gap(24),
          Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  size: 18, color: Color(0xFF2E7D5C)),
              const Gap(8),
              Text(
                'Linked Workflows (${data.workflowLinks.length})',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    showCustomerWorkflowsPanel(context, ref, c),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Manage'),
              ),
            ],
          ),
          const Gap(8),
          if (data.workflowLinks.isEmpty)
            _emptyCard('No workflows linked yet.')
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: data.workflowLinks.asMap().entries.map((e) {
                  return _LinkedWorkflowRow(
                      wf: e.value,
                      index: e.key,
                      isLast: e.key == data.workflowLinks.length - 1);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyCard(String label) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
            child: Text(label,
                style: const TextStyle(color: AppColors.muted))),
      );
}

// ─────────────────────────────────────────────────────────────
// Session picker + metrics section
// ─────────────────────────────────────────────────────────────

class _SessionSection extends ConsumerWidget {
  final String customerId;
  final String? selectedSessionId;
  final ValueChanged<String?> onSessionChanged;

  const _SessionSection({
    required this.customerId,
    required this.selectedSessionId,
    required this.onSessionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(_dashSessionsProvider(customerId));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 18, color: _kGrad0),
              const Gap(8),
              Text('Active Assessment',
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const Gap(12),

          // Dropdown
          sessionsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Failed to load sessions: $e',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.danger)),
            data: (sessions) {
              // Auto-select first session once loaded
              if (selectedSessionId == null && sessions.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => onSessionChanged(sessions.first.id));
              }

              if (sessions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('No active assessment sessions',
                      style: TextStyle(color: AppColors.muted)),
                );
              }

              final currentId = selectedSessionId != null &&
                      sessions.any((s) => s.id == selectedSessionId)
                  ? selectedSessionId
                  : sessions.first.id;

              return DropdownButtonFormField<String>(
                value: currentId,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                items: sessions
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.workflowName,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: onSessionChanged,
              );
            },
          ),

          // Summary metrics (shown once a session is selected)
          if (selectedSessionId != null) ...[
            const Gap(16),
            _SessionMetrics(sessionId: selectedSessionId!),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────
// Session metrics — evaluation + task counts
// ─────────────────────────────────────────────────────────────

class _SessionMetrics extends ConsumerWidget {
  final String sessionId;
  const _SessionMetrics({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_dashSummaryProvider(sessionId));

    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Could not load metrics: $e',
          style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Evaluation row
          if (s.hasEvaluation) ...[
            Text('Latest Evaluation',
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w600)),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.security_outlined,
                    label: 'Compliance Score',
                    value: s.complianceScore != null
                        ? '${s.complianceScore!.toStringAsFixed(1)}%'
                        : '—',
                    color: _scoreColor(s.complianceScore),
                    sub: s.evaluationDate != null
                        ? _fmtDate(s.evaluationDate!)
                        : null,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.account_balance_outlined,
                    label: 'Total Exposure',
                    value: s.totalExposure != null
                        ? _fmtCurrency(s.totalExposure!)
                        : '—',
                    color: s.totalExposure != null && s.totalExposure! > 0
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ),
              ],
            ),
            const Gap(12),
          ] else ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.muted),
                  const Gap(8),
                  const Text('No evaluation run yet for this session.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            const Gap(12),
          ],

          // Task counts row
          Text('Tasks',
              style: AppTextStyles.caption
                  .copyWith(fontWeight: FontWeight.w600)),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.radio_button_unchecked,
                  label: 'Open Tasks',
                  value: '${s.openTasks}',
                  color: s.openTasks > 0
                      ? AppColors.warning
                      : AppColors.muted,
                ),
              ),
              const Gap(12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.check_circle_outline,
                  label: 'Closed Tasks',
                  value: '${s.closedTasks}',
                  color: AppColors.success,
                ),
              ),
              const Gap(12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.list_alt_outlined,
                  label: 'Total Tasks',
                  value: '${s.totalTasks}',
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double? score) {
    if (score == null) return AppColors.muted;
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  String _fmtCurrency(double v) {
    final fmt = NumberFormat.compact(locale: 'en_US');
    return '₪${fmt.format(v)}';
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Metric tile (compliance score, exposure, task counts)
// ─────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                Text(label,
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 11)),
                if (sub != null)
                  Text(sub!,
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer info card ────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Map<String, dynamic> c;
  const _InfoCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 10,
        children: [
          if ((c['contactName'] as String?)?.isNotEmpty == true)
            _Detail(
                icon: Icons.person_outlined,
                label: 'Contact',
                value: c['contactName'] as String),
          if ((c['contactEmail'] as String?)?.isNotEmpty == true)
            _Detail(
                icon: Icons.email_outlined,
                label: 'Email',
                value: c['contactEmail'] as String),
          if ((c['contactPhone'] as String?)?.isNotEmpty == true)
            _Detail(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: c['contactPhone'] as String),
          if ((c['city'] as String?)?.isNotEmpty == true)
            _Detail(
                icon: Icons.location_city_outlined,
                label: 'City',
                value: c['city'] as String),
          if ((c['companySize'] as int?) != null)
            _Detail(
                icon: Icons.people_outline,
                label: 'Size',
                value: '${c['companySize']} employees'),
          _Detail(
              icon: Icons.circle,
              label: 'Status',
              value:
                  (c['isActive'] as bool? ?? true) ? 'Active' : 'Inactive',
              valueColor: (c['isActive'] as bool? ?? true)
                  ? const Color(0xFF16A34A)
                  : AppColors.danger),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, duration: 300.ms);
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const Gap(4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            Text(value,
                style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: valueColor)),
          ],
        ),
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<Map<String, dynamic>> links;
  final Map<String, int> roleCounts;
  const _StatsRow({required this.links, required this.roleCounts});

  static const _roleInfo = {
    'client_admin': (
      label: 'Admins',
      color: Color(0xFF0891B2),
      icon: Icons.admin_panel_settings_outlined
    ),
    'it_executor': (
      label: 'IT Executors',
      color: Color(0xFF059669),
      icon: Icons.build_outlined
    ),
    'employee': (
      label: 'Employees',
      color: Color(0xFF9CA3AF),
      icon: Icons.person_outlined
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatChip(
          label: 'Total linked',
          value: links.length,
          color: _kGrad0,
          icon: Icons.link_rounded,
          index: 0,
        ),
        ...roleCounts.entries.map((e) {
          final info = _roleInfo[e.key];
          return _StatChip(
            label: info?.label ?? e.key,
            value: e.value,
            color: info?.color ?? const Color(0xFF9CA3AF),
            icon: info?.icon ?? Icons.people_outline,
            index: roleCounts.keys.toList().indexOf(e.key) + 1,
          );
        }),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final int index;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const Gap(8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.toString(),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 20)),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 60).ms, duration: 320.ms)
        .scale(
            begin: const Offset(0.9, 0.9),
            delay: (index * 60).ms,
            duration: 320.ms);
  }
}

String _roleLabel(String role) => switch (role) {
      'client_admin' => 'Client Admin',
      'it_executor' => 'IT Executor',
      'employee' => 'Employee',
      _ => role,
    };

// ── Linked user row ───────────────────────────────────────────
class _LinkedUserRow extends StatelessWidget {
  final Map<String, dynamic> link;
  final int index;
  final bool isLast;

  const _LinkedUserRow({
    required this.link,
    required this.index,
    required this.isLast,
  });

  static const _roleColors = {
    'client_admin': Color(0xFF0891B2),
    'it_executor': Color(0xFF059669),
    'employee': Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    final name = link['userName'] as String? ?? '—';
    final email = link['userEmail'] as String? ?? '';
    final role = link['role'] as String? ?? 'employee';
    final color = _roleColors[role] ?? const Color(0xFF9CA3AF);

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          title: Text(name,
              style:
                  AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(email, style: AppTextStyles.caption),
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(_roleLabel(role),
                style: AppTextStyles.tag.copyWith(color: color)),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 56, color: AppColors.border),
      ],
    )
        .animate()
        .fadeIn(delay: (index * 50).ms, duration: 280.ms)
        .slideX(begin: 0.08, delay: (index * 50).ms, duration: 280.ms);
  }
}

// ── Linked workflow row ───────────────────────────────────────
class _LinkedWorkflowRow extends StatelessWidget {
  final Map<String, dynamic> wf;
  final int index;
  final bool isLast;

  const _LinkedWorkflowRow({
    required this.wf,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final name = wf['workflowName'] as String? ?? '—';
    final desc = wf['workflowDescription'] as String?;
    final isActive = wf['isActive'] as bool? ?? true;
    const activeColor = Color(0xFF2E7D5C);

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: activeColor.withOpacity(0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'W',
              style: const TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          title: Text(name,
              style:
                  AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: desc != null && desc.isNotEmpty
              ? Text(desc,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis)
              : null,
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFDCFCE7)
                  : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isActive
                      ? activeColor.withOpacity(0.4)
                      : AppColors.danger.withOpacity(0.4)),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: AppTextStyles.tag.copyWith(
                  color: isActive ? activeColor : AppColors.danger),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 56, color: AppColors.border),
      ],
    )
        .animate()
        .fadeIn(delay: (index * 50).ms, duration: 280.ms)
        .slideX(begin: 0.08, delay: (index * 50).ms, duration: 280.ms);
  }
}

