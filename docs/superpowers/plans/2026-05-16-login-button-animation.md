# Login Button Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Morph the Sign In button into a loading circle, then fade the entire screen to white on success (triggering GoRouter only when the screen is fully white), and shake+re-expand on error.

**Architecture:** Split `login()` into `loginAndHold()` (API call, holds `AsyncLoading` so GoRouter does not fire) and `completeLogin()` (sets `AsyncData` → GoRouter fires). A `_ButtonPhase` enum drives the button's appearance. A `_FadeToWhiteOverlay` widget calls `completeLogin()` in its `onEnd` callback after a 400 ms fade. Error path uses `TweenAnimationBuilder` with a key-change trick to replay a damped-sine shake.

**Tech Stack:** Flutter 3, Dart, Riverpod 2 (`riverpod_annotation`), `flutter_animate` (already imported), `mocktail` (already in dev_dependencies), `dart:math`

---

## File map

| File | Action |
|---|---|
| `lib/core/auth/auth_provider.dart` | Add `_pendingUser`, add `loginAndHold()`, add `completeLogin()`, remove `login()` |
| `lib/features/auth/login_screen.dart` | Add `_ButtonPhase`, rewrite `_submit()`, morph button via `LayoutBuilder`+`AnimatedContainer`, add `_FadeToWhiteOverlay`, add shake via `TweenAnimationBuilder`, remove `_SuccessOverlay` |
| `test/core/auth/auth_provider_test.dart` | **Create** — unit tests for `loginAndHold` / `completeLogin` |
| `test/features/auth/login_screen_test.dart` | **Extend** — add widget tests for phase transitions and overlay visibility |

---

### Task 1: Auth provider — `loginAndHold` and `completeLogin`

**Files:**
- Create: `test/core/auth/auth_provider_test.dart`
- Modify: `lib/core/auth/auth_provider.dart`

---

- [ ] **Step 1: Create the failing tests**

Create `test/core/auth/auth_provider_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:regulit_app/core/api/api_client.dart';
import 'package:regulit_app/core/auth/auth_provider.dart';
import 'package:regulit_app/core/models/user.dart';

class _MockDio extends Mock implements Dio {}
class _MockStorage extends Mock implements FlutterSecureStorage {}

// Subclass that skips _restoreSession so no network call happens during build.
class _TestAuthState extends AuthState {
  @override
  Future<AppUser?> build() async => null;
}

// Successful POST response that loginAndHold expects.
Response<dynamic> _successResponse() => Response(
      data: {
        'access_token': 'tok_access',
        'refresh_token': 'tok_refresh',
        'tenant_id': 'ten_001',
        'user': {
          'id': 'u1',
          'tenantId': 'ten_001',
          'email': 'alice@test.com',
          'name': 'Alice',
          'role': 'employee',
        },
      },
      statusCode: 200,
      requestOptions: RequestOptions(path: '/auth/login'),
    );

void main() {
  late _MockDio mockDio;
  late _MockStorage mockStorage;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = _MockDio();
    mockStorage = _MockStorage();

    when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    when(() => mockStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);

    container = ProviderContainer(overrides: [
      secureStorageProvider.overrideWith((ref) => mockStorage),
      dioProvider.overrideWith((ref) => mockDio),
      authStateProvider.overrideWith(_TestAuthState.new),
    ]);
    // Prevent auto-dispose while the test runs.
    container.listen(authStateProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  group('loginAndHold — success', () {
    setUp(() {
      when(() => mockDio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _successResponse());
    });

    test('leaves state as AsyncLoading after API call completes', () async {
      await container.read(authStateProvider.future); // wait for build()
      final notifier = container.read(authStateProvider.notifier);

      await notifier.loginAndHold(email: 'alice@test.com', password: 'pass1234');

      expect(container.read(authStateProvider), isA<AsyncLoading<AppUser?>>());
    });

    test('completeLogin sets AsyncData with the pending user', () async {
      await container.read(authStateProvider.future);
      final notifier = container.read(authStateProvider.notifier);

      await notifier.loginAndHold(email: 'alice@test.com', password: 'pass1234');
      notifier.completeLogin();

      final state = container.read(authStateProvider);
      expect(state, isA<AsyncData<AppUser?>>());
      expect(state.value?.email, 'alice@test.com');
    });

    test('completeLogin is idempotent — second call is a no-op', () async {
      await container.read(authStateProvider.future);
      final notifier = container.read(authStateProvider.notifier);

      await notifier.loginAndHold(email: 'alice@test.com', password: 'pass1234');
      notifier.completeLogin();
      notifier.completeLogin(); // must not crash or change state back to null

      expect(container.read(authStateProvider).value?.email, 'alice@test.com');
    });
  });

  group('loginAndHold — error', () {
    setUp(() {
      when(() => mockDio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => throw DioException(
                requestOptions: RequestOptions(path: '/auth/login'),
                response: Response(
                  statusCode: 401,
                  requestOptions: RequestOptions(path: '/auth/login'),
                ),
                type: DioExceptionType.badResponse,
              ));
    });

    test('resets state to AsyncData(null) and throws', () async {
      await container.read(authStateProvider.future);
      final notifier = container.read(authStateProvider.notifier);

      await expectLater(
        notifier.loginAndHold(email: 'alice@test.com', password: 'wrong'),
        throwsException,
      );

      final state = container.read(authStateProvider);
      expect(state, isA<AsyncData<AppUser?>>());
      expect(state.value, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```
flutter test test/core/auth/auth_provider_test.dart
```

Expected: FAIL — `loginAndHold` and `completeLogin` do not exist yet.

- [ ] **Step 3: Add `_pendingUser` field to `AuthState` in `auth_provider.dart`**

In `lib/core/auth/auth_provider.dart`, inside the `AuthState` class (after the `build()` method), add:

```dart
AppUser? _pendingUser;
```

- [ ] **Step 4: Add `loginAndHold()` to `AuthState`**

Add after `_pendingUser`:

```dart
/// Authenticates against the API and stores tokens, but does NOT set
/// AsyncData — GoRouter's redirect will not fire yet.
/// Call [completeLogin] after the success animation to trigger navigation.
Future<void> loginAndHold({
  required String email,
  required String password,
}) async {
  state = const AsyncLoading();

  final result = await AsyncValue.guard(() async {
    final dio = ref.read(dioProvider);
    final storage = ref.read(secureStorageProvider);

    final response = await dio.post<dynamic>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;

    await storage.write(key: 'auth_token',    value: data['access_token']  as String);
    await storage.write(key: 'refresh_token', value: data['refresh_token'] as String);
    await storage.write(key: 'tenant_id',     value: data['tenant_id']     as String);
    await storage.write(key: 'last_email',    value: email);

    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  });

  if (result is AsyncError) {
    state = const AsyncData(null);
    throw result.error!;
  }

  _pendingUser = result.value;
  // state intentionally stays AsyncLoading
}
```

- [ ] **Step 5: Add `completeLogin()` to `AuthState`**

Add after `loginAndHold`:

```dart
/// Sets AsyncData with the user stored by [loginAndHold].
/// GoRouter's redirect fires on this call. Safe to call multiple times.
void completeLogin() {
  if (_pendingUser == null) return;
  state = AsyncData(_pendingUser);
  _pendingUser = null;
}
```

- [ ] **Step 6: Remove `login()` from `AuthState`**

Delete the entire `login()` method (lines roughly 49–71 in the original file):

```dart
// DELETE this entire method:
/// Login with email + password
Future<void> login({required String email, required String password}) async {
  state = const AsyncLoading();
  state = await AsyncValue.guard(() async {
    ...
  });
}
```

- [ ] **Step 7: Run tests**

```
flutter test test/core/auth/auth_provider_test.dart
```

Expected: All 4 tests PASS.

- [ ] **Step 8: Commit**

```
git add lib/core/auth/auth_provider.dart test/core/auth/auth_provider_test.dart
git commit -m "feat: split login() into loginAndHold() + completeLogin() for animation timing"
```

---

### Task 2: `_ButtonPhase` enum + button morph

**Files:**
- Modify: `lib/features/auth/login_screen.dart`
- Modify: `test/features/auth/login_screen_test.dart`

Context: `_LoginScreenState` currently has `bool _loginSucceeded` and watches `authStateProvider.isLoading`. Both are replaced by `_ButtonPhase _phase`. The button currently uses `width: double.infinity`; because `AnimatedContainer` cannot lerp from `double.infinity`, we wrap it in a `LayoutBuilder` to get a concrete width.

---

- [ ] **Step 1: Add failing widget tests**

In `test/features/auth/login_screen_test.dart`, add a new group AFTER the existing groups (before the closing `}` of `main()`):

```dart
  group('LoginScreen — button phase transitions', () {
    testWidgets('idle state: Sign In label visible, no spinner', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(400, 800)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sign In'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
```

- [ ] **Step 2: Run to confirm it passes (baseline)**

```
flutter test test/features/auth/login_screen_test.dart
```

Expected: All tests PASS (the new test also passes because the idle state already shows the label).

- [ ] **Step 3: Add `_ButtonPhase` enum and field to `login_screen.dart`**

At the top of `lib/features/auth/login_screen.dart`, add after the imports (before `class LoginScreen`):

```dart
enum _ButtonPhase { idle, loading, succeeded, error }
```

In `_LoginScreenState`, replace:

```dart
bool _loginSucceeded = false;
String? _errorMessage;
```

with:

```dart
_ButtonPhase _phase = _ButtonPhase.idle;
int _errorShakeVersion = 0;
String? _errorMessage;
```

- [ ] **Step 4: Add `import 'dart:math' as math;` to `login_screen.dart`**

Add at the top of the import block (after `package:` imports):

```dart
import 'dart:math' as math;
```

- [ ] **Step 5: Rewrite `build()` to remove `isLoading` watch and `_SuccessOverlay`**

Replace the full `build()` method:

```dart
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
        // _FadeToWhiteOverlay added in Task 3
      ],
    ),
  );
}
```

Note: `_SuccessOverlay` is removed from the Stack. `_FadeToWhiteOverlay` is added in Task 3.

- [ ] **Step 6: Rewrite `_buildForm()` — remove `isLoading` param, replace button widget**

Replace the `_buildForm` method signature and button section. The full method:

```dart
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
```

- [ ] **Step 7: Add `_buildButton()` and `_buildBtnChild()` helper methods**

Add these methods to `_LoginScreenState` (before `_showForgotPassword`):

```dart
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
```

- [ ] **Step 8: Update the two call sites for `_buildForm` in `_DesktopLayout` and `_MobileLayout`**

In `_DesktopLayout.build()`, find:

```dart
final form = _buildForm(isLoading, l10n, context);
```

Replace with:

```dart
final form = _buildForm(l10n, context);
```

Do the same in `_MobileLayout.build()`.

Wait — `_buildForm` is called from `_LoginScreenState.build()`, not from the layout classes. In the current code, `build()` passes `form` as a parameter to `_DesktopLayout` and `_MobileLayout`. So the only call site to update is in `_LoginScreenState.build()`, which was already updated in Step 5. No other changes needed.

- [ ] **Step 9: Run tests**

```
flutter test test/features/auth/login_screen_test.dart
```

Expected: All tests PASS. The existing tests still pass because the button is still visible in idle state.

- [ ] **Step 10: Commit**

```
git add lib/features/auth/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat: _ButtonPhase enum + AnimatedContainer button morph on login screen"
```

---

### Task 3: `_FadeToWhiteOverlay` + success flow

**Files:**
- Modify: `lib/features/auth/login_screen.dart`
- Modify: `test/features/auth/login_screen_test.dart`

Context: Add `_FadeToWhiteOverlay` to the Stack. Rewrite `_submit()` to call `loginAndHold()` and drive `_phase = succeeded`. `_FadeToWhiteOverlay.onFadeComplete` calls `completeLogin()`. Remove `_SuccessOverlay` class.

---

- [ ] **Step 1: Add failing widget test for the fade overlay**

In `test/features/auth/login_screen_test.dart`, inside the existing `_LoggedOutAuthState`, add the override below. Then add a new `_SuccessAuthState` class after `_LoggedOutAuthState`:

```dart
// Simulates a loginAndHold() that completes instantly with a fake user.
class _SuccessAuthState extends AuthState {
  @override
  Future<AppUser?> build() async => null;

  @override
  Future<void> loginAndHold({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    // Simulate instant success — _pendingUser set internally
    // (In production, loginAndHold sets _pendingUser; here we test
    //  that _FadeToWhiteOverlay becomes visible after _phase = succeeded)
  }

  @override
  void completeLogin() {
    state = AsyncData(AppUser(
      id: 'u1',
      tenantId: 'ten',
      email: 'alice@test.com',
      name: 'Alice',
      role: UserRole.employee,
    ));
  }
}
```

Then add a new helper that uses `_SuccessAuthState`:

```dart
Widget _wrapSuccess(WidgetTester tester, {required Size size}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final storage = _MockStorage();
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authStateProvider.overrideWith(_SuccessAuthState.new),
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
```

Add a new test group:

```dart
  group('LoginScreen — fade overlay', () {
    testWidgets('no white overlay visible in idle state', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(400, 800)));
      await tester.pumpAndSettle();

      // The white ColoredBox from _FadeToWhiteOverlay should be at opacity 0.
      // We check no fully-opaque white container covers the screen.
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).last,
      );
      expect(opacity.opacity, 0.0);
    });
  });
```

- [ ] **Step 2: Run to confirm the test fails**

```
flutter test test/features/auth/login_screen_test.dart
```

Expected: FAIL — `_FadeToWhiteOverlay` does not exist yet, so `find.byType(AnimatedOpacity).last` will not find it.

- [ ] **Step 3: Add the `_FadeToWhiteOverlay` widget to `login_screen.dart`**

Add this new private widget class at the bottom of `login_screen.dart` (after `_ForgotPasswordDialog`):

```dart
// ── Fade-to-white overlay ─────────────────────────────────────
class _FadeToWhiteOverlay extends StatelessWidget {
  final bool visible;
  final VoidCallback onFadeComplete;
  const _FadeToWhiteOverlay({
    required this.visible,
    required this.onFadeComplete,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
        onEnd: visible ? onFadeComplete : null,
        child: const ColoredBox(
          color: Colors.white,
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add `_FadeToWhiteOverlay` to the Stack in `build()`**

In `_LoginScreenState.build()`, replace the Stack's children:

```dart
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
    _FadeToWhiteOverlay(
      visible: _phase == _ButtonPhase.succeeded,
      onFadeComplete: () {
        if (mounted) {
          ref.read(authStateProvider.notifier).completeLogin();
        }
      },
    ),
  ],
),
```

- [ ] **Step 5: Rewrite `_submit()`**

Replace the current `_submit()` method:

```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() {
    _phase = _ButtonPhase.loading;
    _errorMessage = null;
  });
  try {
    await ref.read(authStateProvider.notifier).loginAndHold(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    // Turn button green — _FadeToWhiteOverlay.onFadeComplete calls completeLogin()
    setState(() => _phase = _ButtonPhase.succeeded);
  } on Exception catch (e) {
    if (!mounted) return;
    final message = e.toString().replaceFirst('Exception: ', '');
    setState(() {
      _phase = _ButtonPhase.error;
      _errorShakeVersion++;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _phase = _ButtonPhase.idle;
      _errorMessage = message;
    });
  }
}
```

- [ ] **Step 6: Delete the `_SuccessOverlay` class**

Remove the entire `_SuccessOverlay` class (roughly lines 546–580 in the original file):

```dart
// DELETE this entire class:
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) { ... }
}
```

- [ ] **Step 7: Run tests**

```
flutter test test/features/auth/login_screen_test.dart
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```
git add lib/features/auth/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat: _FadeToWhiteOverlay + loginAndHold-driven success flow"
```

---

### Task 4: Error path — shake, re-expand, error banner

**Files:**
- Modify: `test/features/auth/login_screen_test.dart`
- Modify: `lib/features/auth/login_screen.dart` (verify shake is wired correctly)

Context: The shake animation (`TweenAnimationBuilder` with a damped-sine `Transform.translate`) and the error path in `_submit()` were both written in Tasks 2 and 3. This task adds a mock auth state for the error path and verifies the observable outcome.

---

- [ ] **Step 1: Add `_ErrorAuthState` to the test file**

In `test/features/auth/login_screen_test.dart`, add after `_SuccessAuthState`:

```dart
// Simulates loginAndHold() that throws immediately.
class _ErrorAuthState extends AuthState {
  @override
  Future<AppUser?> build() async => null;

  @override
  Future<void> loginAndHold({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    throw Exception('Invalid credentials');
  }

  @override
  void completeLogin() {} // never called on error path
}
```

Add a helper for the error scenario:

```dart
Widget _wrapError(WidgetTester tester, {required Size size}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final storage = _MockStorage();
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authStateProvider.overrideWith(_ErrorAuthState.new),
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
```

- [ ] **Step 2: Add failing test for error path**

Add a new group in `test/features/auth/login_screen_test.dart`:

```dart
  group('LoginScreen — error path', () {
    testWidgets('error banner appears after failed login', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrapError(tester, size: const Size(400, 800)));
      await tester.pumpAndSettle();

      // Fill in the form to enable submission
      await tester.enterText(
        find.byType(TextFormField).first,
        'alice@test.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'wrongpass',
      );

      // Tap submit
      await tester.tap(find.byType(FilledButton));
      await tester.pump(); // start loading phase

      // Pump past the 500 ms delay in _submit's error path
      await tester.pump(const Duration(milliseconds: 600));

      // Error banner should now be visible
      expect(find.byType(_ErrorBanner), findsOneWidget);
      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('button returns to idle (full-width) after error', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrapError(tester, size: const Size(400, 800)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'alice@test.com');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // After error delay + AnimatedContainer re-expand animation
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 350)); // container re-expand

      // Button text label should be back
      expect(find.textContaining('Sign In'), findsOneWidget);
    });
  });
```

Note: `_ErrorBanner` must be accessible from the test. Since it is a private class in `login_screen.dart`, change it to `find.text('Invalid credentials')` only if the test file cannot reference `_ErrorBanner`. Replace `find.byType(_ErrorBanner)` with `find.text('Invalid credentials')` if it causes a compile error.

- [ ] **Step 3: Run the tests**

```
flutter test test/features/auth/login_screen_test.dart
```

Expected: All tests PASS. (The shake and re-expand are already wired in Tasks 2 and 3.)

If either test fails because of timing, adjust the `pump(Duration)` values:
- Error path delay is 500 ms (in `_submit`) → pump 600 ms to clear it
- `AnimatedContainer` re-expand is 300 ms → pump 350 ms after that

- [ ] **Step 4: Commit**

```
git add test/features/auth/login_screen_test.dart
git commit -m "test: login screen error path — banner and button re-expand"
```

---

### Task 5: Full test suite

**Files:** None (verification only)

---

- [ ] **Step 1: Run the full test suite**

```
flutter test
```

Expected: All tests PASS, including:
- `test/core/auth/auth_provider_test.dart` (4 tests)
- `test/features/auth/login_screen_test.dart` (all existing + new tests)
- `test/features/splash/splash_screen_test.dart` (3 tests)
- All other existing tests

- [ ] **Step 2: Commit if any minor fixes were needed**

```
git add -A
git commit -m "fix: test suite cleanup after login button animation"
```

Only commit if you had to make fixes. Skip this step if the suite passed cleanly.

---

## Manual acceptance checklist

After implementation, verify these by running the app and testing manually:

- [ ] Entering valid credentials → button shrinks to circle, spinner appears, button turns green with check, screen fades to white, app navigates in
- [ ] Entering invalid credentials → button shrinks, spinner, flashes red and shakes, re-expands to full width, error banner appears with the server error message
- [ ] Submitting with empty fields → form validation fires, button stays full-width (no morph)
- [ ] Desktop layout (≥ 700 px wide) — same behaviour as mobile
- [ ] Logging out and returning to login screen → button shows in idle state with no visual artifacts
