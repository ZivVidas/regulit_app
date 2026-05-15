import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../utils/currency_formatter.dart';

enum MetricVariant { neutral, success, warning, danger }

enum TrendDirection { up, down, flat }

class MetricTrend {
  final TrendDirection direction;
  final String label;
  const MetricTrend({required this.direction, required this.label});
}

extension _MetricVariantX on MetricVariant {
  Color get valueColor => switch (this) {
        MetricVariant.neutral => AppColors.blue,
        MetricVariant.success => AppColors.success,
        MetricVariant.warning => AppColors.warning,
        MetricVariant.danger  => AppColors.danger,
      };

  Color get tintColor => switch (this) {
        MetricVariant.neutral => AppSurfaces.card,
        MetricVariant.success => AppSurfaces.successTint,
        MetricVariant.warning => AppSurfaces.warningTint,
        MetricVariant.danger  => AppSurfaces.dangerTint,
      };
}

extension _TrendDirectionX on TrendDirection {
  IconData get icon => switch (this) {
        TrendDirection.up   => Icons.trending_up_rounded,
        TrendDirection.down => Icons.trending_down_rounded,
        TrendDirection.flat => Icons.trending_flat_rounded,
      };

  Color get color => switch (this) {
        TrendDirection.up   => AppColors.success,
        TrendDirection.down => AppColors.danger,
        TrendDirection.flat => AppColors.muted,
      };
}

/// Reusable metric card used across all dashboards.
///
/// ```dart
/// MetricCard(
///   label: 'Total Exposure',
///   value: '₪2,400,000',
///   variant: MetricVariant.danger,
///   icon: Icons.warning_rounded,
///   trend: MetricTrend(direction: TrendDirection.up, label: '+3 new gaps'),
/// )
/// ```
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final MetricVariant variant;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;
  final MetricTrend? trend;
  final bool tinted;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.variant = MetricVariant.neutral,
    this.trailing,
    this.onTap,
    this.icon,
    this.trend,
    this.tinted = false,
  });

  factory MetricCard.currency({
    Key? key,
    required String label,
    required double amountNIS,
    String? sub,
    MetricVariant variant = MetricVariant.neutral,
    IconData? icon,
    MetricTrend? trend,
    VoidCallback? onTap,
  }) {
    return MetricCard(
      key: key,
      label: label,
      value: CurrencyFormatter.nis(amountNIS),
      sub: sub,
      variant: variant,
      icon: icon,
      trend: trend,
      onTap: onTap,
    );
  }

  factory MetricCard.percent({
    Key? key,
    required String label,
    required double value,
    String? sub,
    MetricVariant variant = MetricVariant.neutral,
    IconData? icon,
    MetricTrend? trend,
    VoidCallback? onTap,
  }) {
    return MetricCard(
      key: key,
      label: label,
      value: '${(value * 100).round()}%',
      sub: sub,
      variant: variant,
      icon: icon,
      trend: trend,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = tinted ? variant.tintColor : AppSurfaces.card;
    final radius = BorderRadius.circular(AppRadius.lg);

    Widget content = Padding(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
              if (icon != null)
                Icon(icon, size: 18, color: variant.valueColor),
              if (trailing != null) trailing!,
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.metric.copyWith(color: variant.valueColor),
          ),
          if (trend != null) ...[
            const Gap(AppSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trend!.direction.icon,
                    size: 14, color: trend!.direction.color),
                const SizedBox(width: 3),
                Text(
                  trend!.label,
                  style: AppTextStyles.caption
                      .copyWith(color: trend!.direction.color),
                ),
              ],
            ),
          ],
          if (sub != null && trend == null) ...[
            const Gap(AppSpacing.xs),
            Text(sub!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );

    return Material(
      color: bgColor,
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: AppShadows.md,
          border: tinted
              ? null
              : Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ClipRRect(
            borderRadius: radius,
            child: content,
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
          return Column(
            children: cards
                .map((c) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.md),
                      child: SizedBox(width: double.infinity, child: c),
                    ))
                .toList(),
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
