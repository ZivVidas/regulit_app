# Login Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain centered-card login with a split-panel layout — blue gradient brand panel left, white form right — matching the app's premium SaaS direction.

**Architecture:** Single file change to `lib/features/auth/login_screen.dart`. A `LayoutBuilder` in the `Scaffold` body switches between `_DesktopLayout` (≥700px, `Row` with `_BrandPanel` + form) and `_MobileLayout` (<700px, gradient header strip + overlapping form card). All existing form logic, validation, and auth calls are unchanged. New widgets (`_BrandPanel`, `_MobileHeader`, `_FeatureBullet`, `_DesktopLayout`, `_MobileLayout`) are private to the file. `flutter_animate` (already a dependency) drives entrance animations.

**Tech Stack:** Flutter 3, Dart, Riverpod 2 (riverpod_annotation), flutter_animate, mocktail (tests)

---

## File Map

| File | Change |
|---|---|
| `lib/features/auth/login_screen.dart` | Restructure `build`, add 5 private widgets, add `flutter_animate` import, remove unused `app_card.dart` import |
| `test/features/auth/login_screen_test.dart` | New — layout tests (desktop brand panel visible, mobile brand panel hidden, form always present) |

---

### Task 1: Write layout tests

**Files:**
- Create: `test/features/auth/login_screen_test.dart`

- [ ] **Step 1: Create the test file**

```dart
// test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/core/api/api_client.dart';
import 'package:regulit_app/core/auth/auth_provider.dart';
import 'package:regulit_app/core/models/user.dart';
import 'package:regulit_app/features/auth/login_screen.dart';
import 'package:regulit_app/l10n/app_localizations.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

// Minimal AuthState that returns null (logged out) without hitting the network.
class _LoggedOutAuthState extends AuthState {
  @override
  Future<AppUser?> build() async => null;
}

Widget _wrap(WidgetTester tester, {required Size size}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final storage = _MockStorage();
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authStateProvider.overrideWith(_LoggedOutAuthState.new),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const LoginScreen(),
    ),
  );
}

void main() {
  tearDown(() {
    // Reset view after each test.
  });

  group('LoginScreen — desktop layout (≥ 700 px)', () {
    testWidgets('shows brand panel with ReguLit name and headline',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(900, 700)));
      await tester.pumpAndSettle();

      expect(find.text('ReguLit'), findsOneWidget);
      expect(find.textContaining('Compliance made'), findsOneWidget);
    });

    testWidgets('shows "Welcome back" heading and two form fields',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(900, 700)));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  group('LoginScreen — mobile layout (< 700 px)', () {
    testWidgets('hides brand panel headline, shows ReguLit in mobile header',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(400, 700)));
      await tester.pumpAndSettle();

      // Brand panel headline is desktop-only.
      expect(find.textContaining('Compliance made'), findsNothing);
      // Mobile header still shows the brand name.
      expect(find.text('ReguLit'), findsOneWidget);
    });

    testWidgets('shows two form fields on mobile', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(400, 700)));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });
}
```

- [ ] **Step 2: Run tests — confirm they fail**

```
flutter test test/features/auth/login_screen_test.dart -v
```

Expected: all 4 tests FAIL because `LoginScreen` doesn't yet have the split layout (`ReguLit` brand text in a panel, `'Compliance made'` text, `'Welcome back'` heading).

---

### Task 2: Implement the split-panel layout

**Files:**
- Modify: `lib/features/auth/login_screen.dart` (full replacement)

- [ ] **Step 1: Replace the file with the new implementation**

```dart
// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      // GoRouter's redirect handles navigation automatically
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppSurfaces.page,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final form = _buildForm(isLoading, l10n, context);
          if (constraints.maxWidth >= 700) {
            return _DesktopLayout(form: form, l10n: l10n);
          }
          return _MobileLayout(form: form, l10n: l10n);
        },
      ),
    );
  }

  Widget _buildForm(bool isLoading, AppLocalizations l10n, BuildContext context) {
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

          // Sign-in button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      style:
                          AppTextStyles.button.copyWith(color: AppColors.white),
                    ),
            ),
          ),
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
        FractionallySizedBox(
          widthFactor: 0.42,
          child: _BrandPanel(l10n: l10n)
              .animate()
              .fadeIn(duration: 400.ms),
        ),
        Expanded(
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
                      'Welcome back',
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      'Sign in to your account',
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
                const Text(
                  'Compliance made\nclear and simple.',
                  style: TextStyle(
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
                const _FeatureBullet(label: 'Risk assessment & tracking'),
                const Gap(10),
                const _FeatureBullet(label: 'Workflow automation'),
                const Gap(10),
                const _FeatureBullet(label: 'Audit-ready reports'),
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
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Heebo',
            fontSize: 11,
            color: Color(0xCCFFFFFF),
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
```

- [ ] **Step 2: Run the tests — confirm they pass**

```
flutter test test/features/auth/login_screen_test.dart -v
```

Expected output:
```
00:XX +4: All tests passed!
```

- [ ] **Step 3: Run analyze to confirm no issues**

```
flutter analyze lib/features/auth/login_screen.dart
```

Expected: no errors (info-level warnings about deprecated APIs elsewhere in the project are pre-existing and acceptable).

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat: redesign login page with split-panel layout"
```
