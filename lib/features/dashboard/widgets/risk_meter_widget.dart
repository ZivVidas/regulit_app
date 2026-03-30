import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../../app/theme.dart';
import '../../../core/models/gap.dart' hide Gap; // 'Gap' widget comes from package:gap
import '../../../shared/utils/currency_formatter.dart';

/// Circular risk gauge for the Executive Dashboard hero section.
/// Shows total ₪ exposure with a color-coded arc (green → yellow → red).
class RiskMeterWidget extends StatelessWidget {
  final GapSummary summary;

  const RiskMeterWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = (summary.totalExposureNIS / 3200000).clamp(0.0, 1.0);
    final riskColor = switch (pct) {
      < 0.3  => AppColors.success,
      < 0.6  => AppColors.warning,
      _      => AppColors.danger,
    };
    final riskLabel = switch (pct) {
      < 0.3  => 'Low Risk',
      < 0.6  => 'Medium Risk',
      _      => 'High Risk',
    };

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          children: [
            Text('Regulatory Exposure', style: AppTextStyles.h4),
            const Gap(AppSpacing.md),

            // ── Gauge ────────────────────────────────────────
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background track
                  PieChart(
                    PieChartData(
                      startDegreeOffset: 180,
                      sections: [
                        // Fill arc
                        PieChartSectionData(
                          value: pct * 180,
                          color: riskColor,
                          radius: 20,
                          showTitle: false,
                        ),
                        // Remaining arc
                        PieChartSectionData(
                          value: (1 - pct) * 180,
                          color: AppColors.border,
                          radius: 20,
                          showTitle: false,
                        ),
                        // Bottom half (invisible spacer)
                        PieChartSectionData(
                          value: 180,
                          color: Colors.transparent,
                          radius: 0,
                          showTitle: false,
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .custom(
                    duration: 800.ms,
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) => child!,
                  ),

                  // Center text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.nisCompact(summary.totalExposureNIS),
                        style: AppTextStyles.metric.copyWith(
                          color: riskColor,
                          fontSize: 24,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 400.ms),
                      Text(riskLabel,
                          style: AppTextStyles.caption
                              .copyWith(color: riskColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(AppSpacing.sm),

            // ── Compliance Score ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Compliance Score', style: AppTextStyles.caption),
                Text(
                  '${(summary.complianceScore * 100).round()}%',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.xs),
            ClipRRect(
              borderRadius: AppRadius.pill_,
              child: LinearProgressIndicator(
                value: summary.complianceScore,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
            const Gap(AppSpacing.sm),
            Text(
              '${CurrencyFormatter.nisCompact(summary.resolvedExposureNIS)} risk eliminated',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }
}
