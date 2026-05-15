import 'package:flutter/material.dart';
import '../../app/theme.dart';

enum AppCardVariant { flat, elevated }

enum AppCardTint { none, primary, secondary, success, danger, warning }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final AppCardTint tint;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Widget? header;
  final Widget? footer;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.elevated,
    this.tint = AppCardTint.none,
    this.padding,
    this.onTap,
    this.header,
    this.footer,
    this.width,
    this.height,
    this.borderRadius,
  });

  Color get _surface => switch (tint) {
        AppCardTint.none      => AppSurfaces.card,
        AppCardTint.primary   => AppSurfaces.primaryTint,
        AppCardTint.secondary => AppSurfaces.secondaryTint,
        AppCardTint.success   => AppSurfaces.successTint,
        AppCardTint.danger    => AppSurfaces.dangerTint,
        AppCardTint.warning   => AppSurfaces.warningTint,
      };

  List<BoxShadow> get _shadows => switch (variant) {
        AppCardVariant.flat     => AppShadows.none,
        AppCardVariant.elevated => AppShadows.md,
      };

  Border? get _border => switch (variant) {
        AppCardVariant.flat     => Border.all(color: AppColors.border),
        AppCardVariant.elevated => null,
      };

  BorderRadius get _radius =>
      borderRadius ?? BorderRadius.circular(AppRadius.lg);

  @override
  Widget build(BuildContext context) {
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          header!,
          const Divider(height: 1, thickness: 1, color: AppColors.border),
        ],
        Padding(
          padding: padding ?? AppSpacing.cardPadding,
          child: child,
        ),
        if (footer != null) ...[
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          footer!,
        ],
      ],
    );

    Widget content = ClipRRect(
      borderRadius: _radius,
      child: SizedBox(width: width, height: height, child: inner),
    );

    if (onTap != null) {
      // Material provides the ink canvas so the ripple is visible
      content = Material(
        color: _surface,
        borderRadius: _radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: _radius,
          child: content,
        ),
      );
    }

    // DecoratedBox paints only the shadow + optional border outside the clip
    return DecoratedBox(
      decoration: BoxDecoration(
        color: onTap == null ? _surface : null, // Material handles color when tappable
        borderRadius: _radius,
        boxShadow: _shadows,
        border: _border,
      ),
      child: content,
    );
  }
}
