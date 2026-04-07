import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../l10n/app_localizations.dart';

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
      await ref.read(authStateProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // GoRouter's redirect will handle navigation automatically
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.blue, AppColors.blueLight],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Card(
                elevation: 24,
                shadowColor: Colors.black38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Logo ─────────────────────────────────────────────
                        Center(
                          child: Image.asset(
                            'assets/images/logo_with_name.png',
                            width: 160,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const Gap(AppSpacing.sm),
                        Center(
                          child: Text(
                            l10n.loginTagline,
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Gap(AppSpacing.xxxl),

                        // ── Error Banner ──────────────────────────────────────
                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const Gap(AppSpacing.lg),
                        ],

                        // ── Email Field ───────────────────────────────────────
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
                            prefixIcon:
                                const Icon(Icons.email_outlined, size: 18),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return l10n.required;
                            if (!v.contains('@')) return l10n.enterValidEmail;
                            return null;
                          },
                        ),
                        const Gap(AppSpacing.lg),

                        // ── Password Field ────────────────────────────────────
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
                            prefixIcon:
                                const Icon(Icons.lock_outline, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: AppColors.muted,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return l10n.required;
                            if (v.length < 8) return l10n.atLeast8Chars;
                            return null;
                          },
                        ),

                        // ── Forgot Password ───────────────────────────────────
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
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.orange),
                            ),
                          ),
                        ),
                        const Gap(AppSpacing.lg),

                        // ── Sign In Button ────────────────────────────────────
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : Text(
                                  '${l10n.signIn} →',
                                  style: AppTextStyles.button
                                      .copyWith(color: AppColors.white),
                                ),
                        ),
                        const Gap(AppSpacing.lg),

                        // ── Footer ────────────────────────────────────────────
                        Text(
                          l10n.loginFooter,
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _ForgotPasswordDialog(),
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────────────────────
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
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
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

// ── Forgot Password Dialog ────────────────────────────────────────────────────
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _sent = false;

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
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () => setState(() => _sent = true),
            child: Text(l10n.sendLink),
          ),
      ],
    );
  }
}
