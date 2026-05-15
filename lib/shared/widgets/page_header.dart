import 'package:flutter/material.dart';
import '../../app/theme.dart';

enum PageHeaderVariant { flat, gradient, secondaryGradient }

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PageHeaderVariant variant;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final EdgeInsetsGeometry? padding;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.variant = PageHeaderVariant.flat,
    this.actions,
    this.leading,
    this.showBack = false,
    this.padding,
  });

  bool get _isColored => variant != PageHeaderVariant.flat;
  Color get _foreground => _isColored ? Colors.white : AppColors.text;
  Color get _fgMuted =>
      _isColored ? Colors.white.withValues(alpha: 0.75) : AppColors.muted;

  Decoration? get _decoration => switch (variant) {
        PageHeaderVariant.flat             => null,
        PageHeaderVariant.gradient         => const BoxDecoration(
            gradient: AppGradients.primaryHeader,
          ),
        PageHeaderVariant.secondaryGradient => const BoxDecoration(
            gradient: AppGradients.secondaryHeader,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        if (showBack)
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: _foreground, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            constraints: const BoxConstraints(),
          ),
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.h2.copyWith(color: _foreground),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(color: _fgMuted),
                  ),
                ),
            ],
          ),
        ),
        if (actions != null)
          ...actions!.map((a) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: a,
              )),
      ],
    );

    final insets = padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        );

    if (_decoration != null) {
      return DecoratedBox(
        decoration: _decoration!,
        child: Padding(padding: insets, child: content),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: insets, child: content),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    );
  }
}
