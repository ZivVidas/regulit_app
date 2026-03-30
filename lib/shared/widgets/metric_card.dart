import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../utils/currency_formatter.dart';

enum MetricVariant { neutral, success, warning, danger }

extension _MetricVariantX on MetricVariant {
  Color get valueColor => switch (this) {
    MetricVariant.neutral => AppColors.blue,
    MetricVariant.success => AppColors.success,
    MetricVariant.warning => AppColors.warning,
    MetricVariant.danger  => AppColors.danger,
  };
}

/// Reusable metric card used across all dashboards.
/// Supports numeric values, ₪ currency, percentages, and trend badges.
///
/// ```dart
/// MetricCard(
///   label: 'Total Exposure',
///   value: '₪2,400,000',
///   sub: '↑ 3 new gaps',
///   variant: MetricVariant.danger,
/// )
/// ```
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final MetricVariant variant;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.variant = MetricVariant.neutral,
    this.trailing,
    this.onTap,
  });

  /// Convenience constructor for ₪ currency values
  factory MetricCard.currency({
    Key? key,
    required String label,
    required double amountNIS,
    String? sub,
    MetricVariant variant = MetricVariant.neutral,
    VoidCallback? onTap,
  }) {
    return MetricCard(
      key: key,
      label: label,
      value: CurrencyFormatter.nis(amountNIS),
      sub: sub,
      variant: variant,
      onTap: onTap,
    );
  }

  /// Convenience constructor for percentage values
  factory MetricCard.percent({
    Key? key,
    required String label,
    required double value,   // 0.0 – 1.0
    String? sub,
    MetricVariant variant = MetricVariant.neutral,
    VoidCallback? onTap,
  }) {
    return MetricCard(
      key: key,
      label: label,
      value: '${(value * 100).round()}%',
      sub: sub,
      variant: variant,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const Gap(AppSpacing.sm),

              // Value
              Text(
                value,
                style: AppTextStyles.metric.copyWith(
                  color: variant.valueColor,
                ),
              ),

              // Sub-label / trend
              if (sub != null) ...[
                const Gap(AppSpacing.xs),
                Text(sub!, style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of metric cards — responsive wrap on small screens
class MetricRow extends StatelessWidget {
  final List<MetricCard> cards;
  const MetricRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          // Stack vertically on very narrow screens
          return Column(
            children: cards.map((c) => SizedBox(width: double.infinity, child: c)).toList(),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const Gap(AppSpacing.md),
              ],
            ],
          ),
        );
      },
    );
  }
}
