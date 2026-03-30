import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../shared/utils/currency_formatter.dart';
import '../../shared/widgets/metric_card.dart';

// ── Data model ────────────────────────────────────────────────
class _ClientRow {
  final String id;
  final String name;
  final String industry;
  final double complianceScore;
  final int openGaps;
  final double exposureNIS;
  final int overdueCount;
  final String riskLevel; // high | medium | low

  const _ClientRow({
    required this.id,
    required this.name,
    required this.industry,
    required this.complianceScore,
    required this.openGaps,
    required this.exposureNIS,
    required this.overdueCount,
    required this.riskLevel,
  });
}

// ── Provider (stub) ───────────────────────────────────────────
final portfolioProvider =
    FutureProvider<List<_ClientRow>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    const _ClientRow(id: '1', name: 'FinTech Ltd.', industry: 'Finance',
        complianceScore: 0.73, openGaps: 6, exposureNIS: 800000, overdueCount: 1, riskLevel: 'medium'),
    const _ClientRow(id: '2', name: 'MediCare Clinic', industry: 'Healthcare',
        complianceScore: 0.28, openGaps: 14, exposureNIS: 2100000, overdueCount: 3, riskLevel: 'high'),
    const _ClientRow(id: '3', name: 'LexCorp Legal', industry: 'Legal',
        complianceScore: 0.87, openGaps: 2, exposureNIS: 120000, overdueCount: 0, riskLevel: 'low'),
    const _ClientRow(id: '4', name: 'RetailMax', industry: 'E-commerce',
        complianceScore: 0.54, openGaps: 9, exposureNIS: 640000, overdueCount: 2, riskLevel: 'medium'),
    const _ClientRow(id: '5', name: 'InsurePlus', industry: 'Insurance',
        complianceScore: 0.33, openGaps: 12, exposureNIS: 1800000, overdueCount: 4, riskLevel: 'high'),
  ];
});

// ── Screen ────────────────────────────────────────────────────
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(portfolioProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Client Portfolio'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Client'),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: clientsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (clients) => _PortfolioBody(clients: clients),
      ),
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  final List<_ClientRow> clients;
  const _PortfolioBody({required this.clients});

  int get _atRisk =>
      clients.where((c) => c.riskLevel == 'high').length;
  int get _overdue =>
      clients.fold(0, (acc, c) => acc + c.overdueCount);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Summary metrics ──────────────────────────────
          MetricRow(cards: [
            MetricCard(
              label: 'Active Clients',
              value: '${clients.length}',
              sub: '3 new this month',
              variant: MetricVariant.neutral,
            ),
            MetricCard(
              label: 'At Risk',
              value: '$_atRisk',
              sub: 'Score < 40%',
              variant: _atRisk > 0
                  ? MetricVariant.danger
                  : MetricVariant.success,
            ),
            MetricCard(
              label: 'Overdue Tasks',
              value: '$_overdue',
              sub: 'Across ${clients.where((c) => c.overdueCount > 0).length} clients',
              variant: _overdue > 0
                  ? MetricVariant.warning
                  : MetricVariant.success,
            ),
          ]),
          const Gap(AppSpacing.lg),

          // ── Alert for at-risk clients ─────────────────────
          if (_atRisk > 0) ...[
            _AtRiskBanner(count: _atRisk),
            const Gap(AppSpacing.lg),
          ],

          // ── Client table ─────────────────────────────────
          Card(
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.md)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text('Client',
                            style: AppTextStyles.label),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Industry',
                            style: AppTextStyles.label),
                      ),
                      Expanded(
                        child: Text('Score',
                            style: AppTextStyles.label),
                      ),
                      Expanded(
                        child: Text('Gaps',
                            style: AppTextStyles.label),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Exposure',
                            style: AppTextStyles.label),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Status',
                            style: AppTextStyles.label),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Rows
                ...clients.asMap().entries.map(
                  (entry) => _ClientTableRow(
                    client: entry.value,
                    isLast: entry.key == clients.length - 1,
                    onTap: (id) => context.go(
                      AppRoutes.tenantGaps.replaceFirst(':tenantId', id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientTableRow extends StatelessWidget {
  final _ClientRow client;
  final bool isLast;
  final void Function(String id) onTap;

  const _ClientTableRow({
    required this.client,
    required this.isLast,
    required this.onTap,
  });

  Color get _scoreColor => switch (client.complianceScore) {
    >= 0.7 => AppColors.success,
    >= 0.4 => AppColors.warning,
    _      => AppColors.danger,
  };

  Color get _exposureColor => switch (client.exposureNIS) {
    >= 1000000 => AppColors.danger,
    >= 500000   => AppColors.orange,
    _            => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(client.id),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom:
                      BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            // Name + overdue indicator
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Text(
                    client.name,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (client.overdueCount > 0) ...[
                    const Gap(AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: AppRadius.pill_,
                      ),
                      child: Text(
                        '${client.overdueCount} overdue',
                        style: AppTextStyles.tag
                            .copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(client.industry,
                  style: AppTextStyles.bodySmall),
            ),
            Expanded(
              child: Text(
                '${(client.complianceScore * 100).round()}%',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _scoreColor,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${client.openGaps}',
                style: AppTextStyles.bodySmall,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.nisCompact(client.exposureNIS),
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _exposureColor,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _RiskChip(level: client.riskLevel),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  final String level;
  const _RiskChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = switch (level) {
      'high'   => (AppColors.dangerLight, AppColors.danger, 'At Risk', '🔴'),
      'medium' => (AppColors.orangeLight, AppColors.orange, 'In Progress', '🟡'),
      _        => (AppColors.successLight, AppColors.success, 'On Track', '✅'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pill_,
      ),
      child: Text(
        '$icon $label',
        style: AppTextStyles.tag.copyWith(color: fg),
      ),
    );
  }
}

class _AtRiskBanner extends StatelessWidget {
  final int count;
  const _AtRiskBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: AppRadius.card,
        border: Border.all(
            color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: AppColors.danger, size: 18),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(
              '$count client${count > 1 ? 's are' : ' is'} at risk (score < 40%). Review and schedule remediation sessions.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
