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
  LinearGradient get gradient => switch (this) {
        MetricVariant.neutral => AppGradients.primaryHeader,
        MetricVariant.success => AppGradients.successHeader,
        MetricVariant.warning => AppGradients.warningHeader,
        MetricVariant.danger  => AppGradients.dangerHeader,
      };

  Color get shadowColor => switch (this) {
        MetricVariant.neutral => const Color(0x400078D4),
        MetricVariant.success => const Color(0x40107C10),
        MetricVariant.warning => const Color(0x40CA8A04),
        MetricVariant.danger  => const Color(0x40D13438),
      };
}

extension _TrendDirectionX on TrendDirection {
  IconData get icon => switch (this) {
        TrendDirection.up   => Icons.trending_up_rounded,
        TrendDirection.down => Icons.trending_down_rounded,
        TrendDirection.flat => Icons.trending_flat_rounded,
      };
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final MetricVariant variant;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;
  final MetricTrend? trend;

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

  // All text is white-palette on gradient backgrounds.
  static const _labelStyle = TextStyle(
    fontFamily: 'Heebo', fontSize: 11, fontWeight: FontWeight.w700,
    letterSpacing: 0.4, color: Color(0xB3FFFFFF), // 70% white
  );
  static const _valueStyle = TextStyle(
    fontFamily: 'Heebo', fontSize: 28, fontWeight: FontWeight.w800,
    color: Colors.white, height: 1,
  );
  static const _trendStyle = TextStyle(
    fontFamily: 'Heebo', fontSize: 11, color: Color(0xCCFFFFFF), // 80% white
  );
  static const _subStyle = TextStyle(
    fontFamily: 'Heebo', fontSize: 11, color: Color(0xBFFFFFFF), // 75% white
  );
  static const _iconColor  = Color(0xCCFFFFFF);
  static const _trendColor = Color(0xCCFFFFFF);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);

    // ── Content ──────────────────────────────────────────────
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
                  style: _labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) Icon(icon, size: 20, color: _iconColor),
              if (trailing != null) trailing!,
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(value, style: _valueStyle),
          if (trend != null) ...[
            const Gap(AppSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trend!.direction.icon, size: 14, color: _trendColor),
                const SizedBox(width: 3),
                Text(trend!.label, style: _trendStyle),
              ],
            ),
          ],
          if (sub != null && trend == null) ...[
            const Gap(AppSpacing.xs),
            Text(sub!, style: _subStyle),
          ],
        ],
      ),
    );

    // ── Glow orb (decorative, no pointer events) ─────────────
    final contentStack = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -25,
          right: -15,
          child: IgnorePointer(
            child: SizedBox(
              width: 90,
              height: 90,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0x1AFFFFFF), // 10% white circle
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        content,
      ],
    );

    final shadow = BoxShadow(
      color: variant.shadowColor,
      blurRadius: 20,
      offset: const Offset(0, 4),
    );

    // ── Tappable: Ink (gradient) on Material (ink canvas) ────
    if (onTap != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [shadow],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              gradient: variant.gradient,
              borderRadius: radius,
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: ClipRRect(borderRadius: radius, child: contentStack),
            ),
          ),
        ),
      );
    }

    // ── Non-tappable: DecoratedBox with gradient ──────────────
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: variant.gradient,
        borderRadius: radius,
        boxShadow: [shadow],
      ),
      child: ClipRRect(borderRadius: radius, child: contentStack),
    );
  }
}

/// Row of metric cards — responsive wrap on small screens.
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
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
