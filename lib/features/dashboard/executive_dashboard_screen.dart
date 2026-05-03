import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/models/gap.dart' hide Gap;
import '../../shared/utils/currency_formatter.dart';
import '../../shared/widgets/metric_card.dart';
import 'widgets/risk_meter_widget.dart';

// ─────────────────────────────────────────────────────────────
// Local models
// ─────────────────────────────────────────────────────────────

class _ExecSession {
  final String id;
  final String workflowName;
  const _ExecSession({required this.id, required this.workflowName});

  factory _ExecSession.fromJson(Map<String, dynamic> j) => _ExecSession(
        id: j['id'] as String,
        workflowName: j['workflowName'] as String? ?? '—',
      );
}

class _ExecSummary {
  final double? complianceScore; // 0–100
  final double? totalExposure;
  final int openTasks;
  final int closedTasks;
  final int totalTasks;

  const _ExecSummary({
    required this.complianceScore,
    required this.totalExposure,
    required this.openTasks,
    required this.closedTasks,
    required this.totalTasks,
  });

  factory _ExecSummary.fromJson(Map<String, dynamic> j) => _ExecSummary(
        complianceScore: (j['complianceScore'] as num?)?.toDouble(),
        totalExposure: (j['totalExposure'] as num?)?.toDouble(),
        openTasks: j['openTasks'] as int? ?? 0,
        closedTasks: j['closedTasks'] as int? ?? 0,
        totalTasks: j['totalTasks'] as int? ?? 0,
      );

  bool get hasData => complianceScore != null || totalExposure != null;

  /// Map to the legacy GapSummary used by RiskMeterWidget / _MetricsGrid.
  GapSummary toGapSummary() => GapSummary(
        total: totalTasks,
        open: openTasks,
        inProgress: 0,
        resolved: closedTasks,
        critical: 0,
        high: 0,
        totalExposureNIS: totalExposure ?? 0,
        resolvedExposureNIS: 0,
        // API returns 0–100; GapSummary expects 0.0–1.0
        complianceScore: (complianceScore ?? 0) / 100,
      );
}

// ─────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────

final _execSessionsProvider =
    FutureProvider.autoDispose.family<List<_ExecSession>, String>(
  (ref, customerId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<List<dynamic>>(
      '/workflow-answers/active-sessions/$customerId',
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(_ExecSession.fromJson)
        .toList();
  },
);

final _execSummaryProvider =
    FutureProvider.autoDispose.family<_ExecSummary, String>(
  (ref, sessionId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<Map<String, dynamic>>(
      '/workflow-answers/$sessionId/dashboard-summary',
    );
    return _ExecSummary.fromJson(res.data!);
  },
);

// ─────────────────────────────────────────────────────────────
// Risk exposure trend — real data from the backend
// Key: (customerId, period) where period is 'monthly' or 'weekly'
// ─────────────────────────────────────────────────────────────

class _TrendPoint {
  final String label;
  final double? totalExposure;
  final double? complianceScore;
  const _TrendPoint(this.label, this.totalExposure, this.complianceScore);

  factory _TrendPoint.fromJson(Map<String, dynamic> j) => _TrendPoint(
        j['label'] as String,
        (j['totalExposure'] as num?)?.toDouble(),
        (j['complianceScore'] as num?)?.toDouble(),
      );
}

/// Provider key: (customerId, period)
final _riskTrendProvider = FutureProvider.autoDispose
    .family<List<_TrendPoint>, (String, String)>(
  (ref, args) async {
    final (customerId, period) = args;
    final dio = ref.watch(dioProvider);
    final res = await dio.get<List<dynamic>>(
      '/workflow-answers/risk-trend',
      queryParameters: {'customer_id': customerId, 'period': period},
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(_TrendPoint.fromJson)
        .toList();
  },
);

// ─────────────────────────────────────────────────────────────
// Top-risks model + provider
// ─────────────────────────────────────────────────────────────

class _TopRiskItem {
  final String taskId;
  final String taskName;
  final String risk;
  final double? estimatedFine;
  final int statusId;
  final String? statusDescription;

  const _TopRiskItem({
    required this.taskId,
    required this.taskName,
    required this.risk,
    required this.estimatedFine,
    required this.statusId,
    required this.statusDescription,
  });

  factory _TopRiskItem.fromJson(Map<String, dynamic> j) => _TopRiskItem(
        taskId: j['taskId'] as String,
        taskName: j['taskName'] as String,
        risk: j['risk'] as String,
        estimatedFine: (j['estimatedFine'] as num?)?.toDouble(),
        statusId: j['statusId'] as int,
        statusDescription: j['statusDescription'] as String?,
      );
}

final _topRisksProvider =
    FutureProvider.autoDispose.family<List<_TopRiskItem>, String>(
  (ref, sessionId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<List<dynamic>>(
      '/workflow-answers/$sessionId/top-risks',
      queryParameters: {'limit': 5},
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(_TopRiskItem.fromJson)
        .toList();
  },
);

// ─────────────────────────────────────────────────────────────
// Category breakdown model + provider
// ─────────────────────────────────────────────────────────────

class _CategoryItem {
  final String category;
  final double totalFine;
  final int taskCount;
  const _CategoryItem(this.category, this.totalFine, this.taskCount);

  factory _CategoryItem.fromJson(Map<String, dynamic> j) => _CategoryItem(
        j['category'] as String? ?? 'Uncategorised',
        (j['totalFine'] as num?)?.toDouble() ?? 0.0,
        (j['taskCount'] as num?)?.toInt() ?? 0,
      );
}

final _categoryBreakdownProvider =
    FutureProvider.autoDispose.family<List<_CategoryItem>, String>(
  (ref, sessionId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<List<dynamic>>(
      '/workflow-answers/$sessionId/category-breakdown',
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(_CategoryItem.fromJson)
        .toList();
  },
);

// ═══════════════════════════════════════════════════════════════
class ExecutiveDashboardScreen extends ConsumerStatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  ConsumerState<ExecutiveDashboardScreen> createState() =>
      _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState
    extends ConsumerState<ExecutiveDashboardScreen> {
  String? _selectedSessionId;
  bool _analyzing = false;

  Future<void> _analyzeAgain(String customerId) async {
    final sessionId = _selectedSessionId;
    if (sessionId == null) return;
    setState(() => _analyzing = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/workflow-answers/$sessionId/analyze',
      );
      final created = (res.data?['tasksCreated'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      // Refresh all session-dependent providers
      ref.invalidate(_execSummaryProvider(sessionId));
      ref.invalidate(_topRisksProvider(sessionId));
      ref.invalidate(_categoryBreakdownProvider(sessionId));
      ref.invalidate(_riskTrendProvider((customerId, 'monthly')));
      ref.invalidate(_riskTrendProvider((customerId, 'weekly')));
      if (mounted) {
        final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            created > 0
                ? l10n.analysisCompleteNew(created)
                : l10n.analysisCompleteNoGaps,
          ),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${l10n.analysisFailed}: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customerId = ref.watch(customerContextProvider)?['customerId'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.complianceDashboard),
        actions: [
          // ── Audit Pack shortcut ──────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: Text(l10n.navAuditPack),
              onPressed: () => context.go(AppRoutes.auditPack),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // ── Re-analyse ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _selectedSessionId == null || customerId == null
                ? const SizedBox.shrink()
                : _analyzing
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
                        label: Text(l10n.analyzeAgain),
                        onPressed: () => _analyzeAgain(customerId),
                      ),
          ),
        ],
      ),
      body: customerId == null
          ? Center(child: Text(l10n.noCustomerContextSelected))
          : _DashboardWithSession(
              customerId: customerId,
              selectedSessionId: _selectedSessionId,
              onSessionChanged: (id) =>
                  setState(() => _selectedSessionId = id),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top-level layout: session picker + body
// ─────────────────────────────────────────────────────────────

class _DashboardWithSession extends ConsumerWidget {
  final String customerId;
  final String? selectedSessionId;
  final ValueChanged<String?> onSessionChanged;

  const _DashboardWithSession({
    required this.customerId,
    required this.selectedSessionId,
    required this.onSessionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(_execSessionsProvider(customerId));

    return sessionsAsync.when(
      loading: () => const _LoadingSkeleton(),
      error: (e, _) => _ErrorState(error: e.toString()),
      data: (sessions) {
        // Auto-select first session on first load
        if (selectedSessionId == null && sessions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => onSessionChanged(sessions.first.id));
        }

        final effectiveId = selectedSessionId != null &&
                sessions.any((s) => s.id == selectedSessionId)
            ? selectedSessionId!
            : (sessions.isNotEmpty ? sessions.first.id : null);

        return Column(
          children: [
            // ── Session picker bar ───────────────────────────
            _SessionPickerBar(
              sessions: sessions,
              selectedId: effectiveId,
              onChanged: onSessionChanged,
            ),

            // ── Dashboard body ───────────────────────────────
            Expanded(
              child: effectiveId == null
                  ? Center(
                      child: Text(AppLocalizations.of(context).noActiveAssessmentSessions,
                          style: const TextStyle(color: AppColors.muted)))
                  : _SessionBody(
                      sessionId: effectiveId,
                      customerId: customerId,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Session picker bar
// ─────────────────────────────────────────────────────────────

class _SessionPickerBar extends StatelessWidget {
  final List<_ExecSession> sessions;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _SessionPickerBar({
    required this.sessions,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, size: 16, color: AppColors.muted),
          const Gap(8),
          Text(AppLocalizations.of(context).assessmentLabel,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const Gap(12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedId,
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Body — loads summary for selected session
// ─────────────────────────────────────────────────────────────

class _SessionBody extends ConsumerWidget {
  final String sessionId;
  final String customerId;

  const _SessionBody({required this.sessionId, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_execSummaryProvider(sessionId));

    return summaryAsync.when(
      loading: () => const _LoadingSkeleton(),
      error: (e, _) => _ErrorState(error: e.toString()),
      data: (summary) => _DashboardBody(
        sessionId: sessionId,
        customerId: customerId,
        summary: summary.toGapSummary(),
        execSummary: summary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Dashboard body (existing layout, now driven by real data)
// ─────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final String sessionId;
  final String customerId;
  final GapSummary summary;
  final _ExecSummary execSummary;

  const _DashboardBody({
    required this.sessionId,
    required this.customerId,
    required this.summary,
    required this.execSummary,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Action Required Banner ─────────────────────────
          if (execSummary.openTasks > 0)
            _ActionBanner(openTasks: execSummary.openTasks)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.1),
          const Gap(AppSpacing.lg),

          // ── Hero: Risk Meter + 4 metrics ───────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 800;
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 240,
                          child: RiskMeterWidget(summary: summary),
                        ),
                        const Gap(AppSpacing.xl),
                        Expanded(
                            child: _MetricsGrid(
                                summary: summary, exec: execSummary)),
                      ],
                    )
                  : Column(children: [
                      RiskMeterWidget(summary: summary),
                      const Gap(AppSpacing.lg),
                      _MetricsGrid(summary: summary, exec: execSummary),
                    ]);
            },
          ),
          const Gap(AppSpacing.xl),

          // ── Charts row ─────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _TrendChart(customerId: customerId),
                    ),
                    const Gap(AppSpacing.lg),
                    Expanded(
                      flex: 2,
                      child: _CategoryBreakdown(sessionId: sessionId),
                    ),
                  ],
                );
              }
              return Column(children: [
                _TrendChart(customerId: customerId),
                const Gap(AppSpacing.lg),
                _CategoryBreakdown(sessionId: sessionId),
              ]);
            },
          ),
          const Gap(AppSpacing.xl),

          // ── Top Open Risks ─────────────────────────────────
          _TopRisksCard(sessionId: sessionId),
        ],
      ),
    );
  }
}

// ── Action Required Banner ─────────────────────────────────────
class _ActionBanner extends StatelessWidget {
  final int openTasks;
  const _ActionBanner({required this.openTasks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: AppColors.warning, size: 18),
          const Gap(AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                children: [
                  TextSpan(
                      text: '${AppLocalizations.of(context).actionRequired} ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: AppLocalizations.of(context).tasksNeedApproval(openTasks)),
                ],
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.blue,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => context.go(AppRoutes.taskList),
            child: Text(AppLocalizations.of(context).reviewNow),
          ),
        ],
      ),
    );
  }
}

// ── Metrics Grid ───────────────────────────────────────────────
class _MetricsGrid extends StatelessWidget {
  final GapSummary summary;
  final _ExecSummary exec;
  const _MetricsGrid({required this.summary, required this.exec});

  @override
  Widget build(BuildContext context) {
    final scoreLabel = exec.complianceScore != null
        ? '${exec.complianceScore!.toStringAsFixed(1)}%'
        : '—';
    final exposureLabel = exec.totalExposure != null
        ? CurrencyFormatter.nisCompact(exec.totalExposure!)
        : '—';

    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        MetricRow(cards: [
          MetricCard.currency(
            label: l10n.totalExposure,
            amountNIS: exec.totalExposure ?? 0,
            sub: exec.hasData ? exposureLabel : l10n.runAnalysisToPopulate,
            variant: (exec.totalExposure ?? 0) > 0
                ? MetricVariant.danger
                : MetricVariant.neutral,
          ),
          MetricCard.percent(
            label: l10n.complianceScore,
            value: summary.complianceScore,
            sub: exec.hasData ? scoreLabel : l10n.runAnalysisToPopulate,
            variant: summary.complianceScore >= 0.8
                ? MetricVariant.success
                : summary.complianceScore >= 0.5
                    ? MetricVariant.warning
                    : MetricVariant.danger,
          ),
        ]),
        const Gap(AppSpacing.md),
        MetricRow(cards: [
          MetricCard(
            label: l10n.openTasksLabel,
            value: '${exec.openTasks}',
            sub: exec.openTasks > 0 ? l10n.requireAttention : l10n.allClear,
            variant: exec.openTasks > 0
                ? MetricVariant.warning
                : MetricVariant.success,
          ),
          MetricCard(
            label: l10n.tasksClosedLabel,
            value: '${exec.closedTasks}',
            sub: l10n.ofNTotal(exec.totalTasks),
            variant: MetricVariant.neutral,
          ),
        ]),
      ],
    );
  }
}

// ── Risk Trend Chart ───────────────────────────────────────────
class _TrendChart extends ConsumerStatefulWidget {
  final String customerId;
  const _TrendChart({required this.customerId});

  @override
  ConsumerState<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends ConsumerState<_TrendChart> {
  String _period = 'monthly'; // 'monthly' | 'weekly'

  @override
  Widget build(BuildContext context) {
    final trendAsync =
        ref.watch(_riskTrendProvider((widget.customerId, _period)));

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: title + period toggle ─────────────
            Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context).riskExposureTrend,
                      style: AppTextStyles.h4),
                ),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'monthly',
                      label: Text(AppLocalizations.of(context).monthly),
                      icon: const Icon(Icons.calendar_month_outlined, size: 14),
                    ),
                    ButtonSegment(
                      value: 'weekly',
                      label: Text(AppLocalizations.of(context).weekly),
                      icon: const Icon(Icons.calendar_view_week_outlined, size: 14),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (set) =>
                      setState(() => _period = set.first),
                  style: SegmentedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 11),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.lg),

            // ── Bar chart ─────────────────────────────────────
            SizedBox(
              height: 160,
              child: trendAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(AppLocalizations.of(context).failedToLoadTrend,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.muted)),
                ),
                data: (points) {
                  if (points.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bar_chart_outlined,
                              size: 32, color: AppColors.muted),
                          const Gap(8),
                          Text(
                            AppLocalizations.of(context).noEvaluationData,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    );
                  }

                  // Dynamic Y-axis ceiling: 20 % headroom above max value
                  final maxVal = points
                      .map((p) => p.totalExposure ?? 0.0)
                      .fold(0.0, max);
                  final maxY = maxVal > 0 ? maxVal * 1.2 : 1000000.0;

                  // Bar width scales with number of points (fewer = wider)
                  final barWidth = (points.length <= 4
                      ? 32.0
                      : points.length <= 7
                          ? 24.0
                          : 16.0);

                  return BarChart(
                    BarChartData(
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  points[idx].label,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIdx, rod, rodIdx) {
                            final p = points[group.x];
                            return BarTooltipItem(
                              '${p.label}\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: CurrencyFormatter.nisCompact(
                                      p.totalExposure ?? 0),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      barGroups: points.asMap().entries.map((e) {
                        final isLatest = e.key == points.length - 1;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.totalExposure ?? 0,
                              color: isLatest
                                  ? AppColors.orange
                                  : AppColors.blue,
                              width: barWidth,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Breakdown ─────────────────────────────────────────
class _CategoryBreakdown extends ConsumerWidget {
  final String sessionId;
  const _CategoryBreakdown({required this.sessionId});

  /// Colour for the fine amount based on magnitude.
  static Color _fineColor(double fine) {
    if (fine >= 500000) return AppColors.danger;
    if (fine >= 100000) return AppColors.orange;
    return AppColors.warning;
  }

  /// Icon for a known category name.
  static IconData _categoryIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('govern') || c.contains('legal')) return Icons.gavel_outlined;
    if (c.contains('access') || c.contains('identity')) return Icons.lock_outline;
    if (c.contains('backup') || c.contains('recovery')) return Icons.backup_outlined;
    if (c.contains('network')) return Icons.lan_outlined;
    if (c.contains('incident')) return Icons.crisis_alert_outlined;
    if (c.contains('physical')) return Icons.security_outlined;
    if (c.contains('risk')) return Icons.assessment_outlined;
    if (c.contains('third') || c.contains('vendor')) return Icons.handshake_outlined;
    if (c.contains('audit') || c.contains('monitor')) return Icons.fact_check_outlined;
    if (c.contains('training') || c.contains('awareness')) return Icons.school_outlined;
    if (c.contains('data') || c.contains('protection')) return Icons.shield_outlined;
    if (c.contains('endpoint')) return Icons.devices_outlined;
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_categoryBreakdownProvider(sessionId));

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(AppLocalizations.of(context).riskByCategory, style: AppTextStyles.h4),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  color: AppColors.muted,
                  visualDensity: VisualDensity.compact,
                  tooltip: AppLocalizations.of(context).retry,
                  onPressed: () =>
                      ref.invalidate(_categoryBreakdownProvider(sessionId)),
                ),
              ],
            ),
            const Gap(AppSpacing.md),
            async.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '${AppLocalizations.of(context).failedToLoadFiles}: $e',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.danger),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).noTasksForSession,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.muted),
                      ),
                    ),
                  );
                }

                // Max fine for proportional bar widths
                final maxFine =
                    items.map((i) => i.totalFine).reduce((a, b) => a > b ? a : b);

                return Column(
                  children: items.map((item) {
                    final barFraction =
                        maxFine > 0 ? (item.totalFine / maxFine) : 0.0;
                    final color = _fineColor(item.totalFine);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category label + task count + fine
                          Row(
                            children: [
                              Icon(_categoryIcon(item.category),
                                  size: 14, color: AppColors.muted),
                              const Gap(6),
                              Expanded(
                                child: Text(
                                  item.category,
                                  style: AppTextStyles.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Gap(6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.border.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).nTasks(item.taskCount),
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.muted),
                                ),
                              ),
                              const Gap(8),
                              Text(
                                item.totalFine > 0
                                    ? CurrencyFormatter.nisCompact(item.totalFine)
                                    : '—',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: item.totalFine > 0
                                      ? color
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const Gap(4),
                          // Proportional progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: barFraction.toDouble(),
                              minHeight: 5,
                              backgroundColor: color.withOpacity(0.12),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Risks ──────────────────────────────────────────────────
class _TopRisksCard extends ConsumerWidget {
  final String sessionId;
  const _TopRisksCard({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risksAsync = ref.watch(_topRisksProvider(sessionId));

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        size: 18, color: AppColors.danger),
                    const Gap(AppSpacing.sm),
                    Text(AppLocalizations.of(context).topOpenRisks, style: AppTextStyles.h4),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.taskList),
                  child: Text(AppLocalizations.of(context).seeAll),
                ),
              ],
            ),
            const Gap(AppSpacing.sm),
            risksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppColors.danger),
                    const Gap(8),
                    Expanded(
                      child: Text('${AppLocalizations.of(context).failedToLoadDashboard}: $e',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.danger)),
                    ),
                  ],
                ),
              ),
              data: (risks) {
                if (risks.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 36, color: AppColors.success),
                          const Gap(8),
                          Text(AppLocalizations.of(context).noOpenRisks,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: risks
                      .asMap()
                      .entries
                      .map((e) => _RiskRow(
                            item: e.value,
                            index: e.key,
                            onTap: () => context.go(AppRoutes.taskList),
                          )
                          .animate()
                          .fadeIn(
                            delay: (e.key * 60).ms,
                            duration: 280.ms,
                          )
                          .slideX(
                            begin: 0.08,
                            delay: (e.key * 60).ms,
                            duration: 280.ms,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskRow extends StatefulWidget {
  final _TopRiskItem item;
  final int index;
  final VoidCallback onTap;

  const _RiskRow({
    required this.item,
    required this.index,
    required this.onTap,
  });

  @override
  State<_RiskRow> createState() => _RiskRowState();
}

class _RiskRowState extends State<_RiskRow> {
  bool _hovered = false;

  // Map statusId → color
  Color _statusColor(int statusId) => switch (statusId) {
        2 => AppColors.blue,       // In Progress
        3 => AppColors.orange,     // Pending Review
        4 => AppColors.success,    // Approved
        5 => AppColors.danger,     // Overdue
        _ => AppColors.muted,      // To Do
      };

  String _statusLabel(BuildContext context, int statusId, String? desc) {
    if (desc != null) return desc;
    final l10n = AppLocalizations.of(context);
    return switch (statusId) {
      2 => l10n.statusInProgress,
      3 => l10n.statusPendingReview,
      4 => l10n.statusApproved,
      5 => l10n.statusOverdue,
      _ => l10n.statusToDo,
    };
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final statusColor = _statusColor(item.statusId);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.orange.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppColors.orange.withOpacity(0.25)
                  : Colors.transparent,
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${widget.index + 1}',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                    fontSize: 11,
                  ),
                ),
              ),
              const Gap(AppSpacing.sm),
              // Task name + risk description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.taskName,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      item.risk,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.sm),
              // Fine + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.estimatedFine != null)
                    Text(
                      CurrencyFormatter.nisCompact(item.estimatedFine!),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  const Gap(3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: statusColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      _statusLabel(context, item.statusId, item.statusDescription),
                      style: AppTextStyles.tag
                          .copyWith(color: statusColor, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const Gap(4),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: _hovered ? AppColors.orange : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Loading Skeleton ───────────────────────────────────────────
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        children: List.generate(
          4,
          (i) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.card,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const Gap(AppSpacing.md),
          Text(AppLocalizations.of(context).failedToLoadDashboard, style: AppTextStyles.h3),
          const Gap(AppSpacing.sm),
          Text(error, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
