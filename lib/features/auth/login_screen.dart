// lib/features/auth/login_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../l10n/app_localizations.dart';

enum _ButtonPhase { idle, loading, succeeded, error }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  _ButtonPhase _phase = _ButtonPhase.idle;
  int _errorShakeVersion = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prefillEmail();
  }

  Future<void> _prefillEmail() async {
    final storage = ref.read(secureStorageProvider);
    final saved = await storage.read(key: 'last_email');
    if (saved != null && mounted) {
      setState(() => _emailController.text = saved);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);
    try {
      await ref.read(authStateProvider.notifier).loginAndHold(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) ref.read(authStateProvider.notifier).completeLogin();
      if (mounted) setState(() => _phase = _ButtonPhase.succeeded);
      // GoRouter's redirect fires on the next frame after state change
    } on Exception catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppSurfaces.page,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final form = _buildForm(l10n, context);
              if (constraints.maxWidth >= 700) {
                return _DesktopLayout(form: form, l10n: l10n);
              }
              return _MobileLayout(form: form, l10n: l10n);
            },
          ),
          // _FadeToWhiteOverlay is added in Task 3
        ],
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n, BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const Gap(AppSpacing.lg),
          ],

          // Email
          Text(l10n.emailAddress, style: AppTextStyles.label),
          const Gap(AppSpacing.xs),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: l10n.emailPlaceholder,
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.required;
              if (!v.contains('@')) return l10n.enterValidEmail;
              return null;
            },
          ),
          const Gap(AppSpacing.lg),

          // Password
          Text(l10n.password, style: AppTextStyles.label),
          const Gap(AppSpacing.xs),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: '••••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.required;
              if (v.length < 8) return l10n.atLeast8Chars;
              return null;
            },
          ),

          // Forgot password
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _showForgotPassword(context),
              child: Text(
                l10n.forgotPassword,
                style: AppTextStyles.caption.copyWith(color: AppColors.orange),
              ),
            ),
          ),
          const Gap(AppSpacing.lg),

          // Sign-in button — morphs width and radius based on _phase
          _buildButton(l10n),
          const Gap(AppSpacing.lg),

          // Footer
          Text(
            l10n.loginFooter,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(AppLocalizations l10n) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_errorShakeVersion),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, t, child) => Transform.translate(
        // Damped sine: ±8 px at start, decays to 0 by t=1
        offset: Offset(8.0 * math.sin(t * math.pi * 4) * (1.0 - t), 0),
        child: child,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCircle = _phase != _ButtonPhase.idle;
          final btnColor = switch (_phase) {
            _ButtonPhase.idle      => AppColors.orange,
            _ButtonPhase.loading   => AppColors.orange,
            _ButtonPhase.succeeded => const Color(0xFF107C10),
            _ButtonPhase.error     => const Color(0xFFD13438),
          };
          final radius = isCircle ? 24.0 : AppRadius.sm;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.center,
            width: isCircle ? 48.0 : constraints.maxWidth,
            height: 48,
            decoration: BoxDecoration(
              color: btnColor,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              onPressed: _phase == _ButtonPhase.idle ? _submit : null,
              child: _buildBtnChild(l10n),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBtnChild(AppLocalizations l10n) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_phase) {
        _ButtonPhase.idle => Text(
            key: const ValueKey('label'),
            '${l10n.signIn} →',
            style: AppTextStyles.button.copyWith(color: AppColors.white),
          ),
        _ButtonPhase.loading => const SizedBox(
            key: ValueKey('spinner'),
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        _ButtonPhase.succeeded => const Icon(
            key: ValueKey('check'),
            Icons.check_rounded,
            color: Colors.white,
            size: 22,
          ),
        _ButtonPhase.error => const SizedBox.shrink(key: ValueKey('empty')),
      },
    );
  }

  void _showForgotPassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _ForgotPasswordDialog(),
    );
  }
}

// ── Desktop Layout ────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final Widget form;
  final AppLocalizations l10n;
  const _DesktopLayout({required this.form, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          flex: 42,
          child: _BrandPanel(l10n: l10n)
              .animate()
              .fadeIn(duration: 400.ms),
        ),
        Expanded(
          flex: 58,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.welcomeBack,
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      l10n.signInToAccount,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.muted),
                    ),
                    const Gap(AppSpacing.xxl),
                    form,
                  ],
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(
                  begin: 0.08,
                  curve: Curves.easeOut,
                  duration: 500.ms,
                  delay: 200.ms),
        ),
      ],
    );
  }
}

// ── Mobile Layout ─────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final Widget form;
  final AppLocalizations l10n;
  const _MobileLayout({required this.form, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MobileHeader(l10n: l10n),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppSurfaces.card,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.md,
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: form,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms)
                  .slideY(
                      begin: 0.10,
                      curve: Curves.easeOut,
                      duration: 400.ms,
                      delay: 150.ms),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Brand Panel (desktop left) ────────────────────────────────
class _BrandPanel extends StatelessWidget {
  final AppLocalizations l10n;
  const _BrandPanel({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.primaryHeader),
      child: Stack(
        children: [
          // Glow orbs
          const Positioned(
            top: -50,
            right: -60,
            child: IgnorePointer(
              child: SizedBox(
                width: 180,
                height: 180,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x12FFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: -30,
            left: -30,
            child: IgnorePointer(
              child: SizedBox(
                width: 110,
                height: 110,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x0DFFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            right: 20,
            child: IgnorePointer(
              child: SizedBox(
                width: 60,
                height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x0FFFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand row
                Row(
                  children: [
                    Image.asset(
                      'assets/images/newlogo.png',
                      width: 44,
                      height: 44,
                      filterQuality: FilterQuality.high,
                    ),
                    const Gap(11),
                    const Text(
                      'ReguLit',
                      style: TextStyle(
                        fontFamily: 'Heebo',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const Gap(40),
                // Headline
                Text(
                  l10n.loginHeadline,
                  style: const TextStyle(
                    fontFamily: 'Heebo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
                const Gap(12),
                // Tagline (localised)
                Text(
                  l10n.loginTagline,
                  style: const TextStyle(
                    fontFamily: 'Heebo',
                    fontSize: 13,
                    color: Color(0xA6FFFFFF),
                    height: 1.6,
                  ),
                ),
                const Gap(28),
                // Feature bullets
                _FeatureBullet(label: l10n.loginFeature1),
                const Gap(10),
                _FeatureBullet(label: l10n.loginFeature2),
                const Gap(10),
                _FeatureBullet(label: l10n.loginFeature3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final String label;
  const _FeatureBullet({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            border: Border.all(color: const Color(0x33FFFFFF)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.check, size: 12, color: Colors.white),
        ),
        const Gap(10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Heebo',
              fontSize: 11,
              color: Color(0xCCFFFFFF),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Mobile Header ─────────────────────────────────────────────
class _MobileHeader extends StatelessWidget {
  final AppLocalizations l10n;
  const _MobileHeader({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.primaryHeader),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Row(
            children: [
              Image.asset(
                'assets/images/newlogo.png',
                width: 30,
                height: 30,
                filterQuality: FilterQuality.high,
              ),
              const Gap(10),
              const Text(
                'ReguLit',
                style: TextStyle(
                  fontFamily: 'Heebo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Success Overlay ───────────────────────────────────────────
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.25),
      child: Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFF107C10),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF107C10).withValues(alpha: 0.40),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
        )
            .animate()
            .scale(
              begin: const Offset(0.3, 0.3),
              duration: 500.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 200.ms),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ── Error Banner ──────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Forgot Password Dialog ────────────────────────────────────
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.resetPassword),
      content: _sent
          ? Text(l10n.resetLinkSent)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.enterEmailForReset),
                const Gap(AppSpacing.md),
                TextField(
                  controller: _ctrl,
                  decoration:
                      InputDecoration(hintText: l10n.emailPlaceholder),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
        if (!_sent)
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange),
            onPressed: () => setState(() => _sent = true),
            child: Text(l10n.sendLink),
          ),
      ],
    );
  }
}
