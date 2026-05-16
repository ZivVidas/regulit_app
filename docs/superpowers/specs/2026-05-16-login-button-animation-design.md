# Login Button Animation — Design Spec

**Date:** 2026-05-16  
**Status:** Approved

---

## Problem

On successful login, GoRouter's redirect fires immediately when `authStateProvider` becomes `AsyncData(user)`, causing an abrupt full-screen refresh. There is no animated transition — just a jarring page swap.

---

## Goal

The Sign In button:
1. Morphs from a full-width pill to a 48 px circle on tap, showing a spinner while the API call is in flight.
2. On **success**: turns green with a check mark, holds briefly, then the entire screen fades to white — navigation happens during the fade so the transition feels seamless.
3. On **error**: flashes red, shakes horizontally, re-expands to full width, and the error banner fades in above the form fields.

---

## Constraints

- No new packages. `flutter_animate` is already imported in `login_screen.dart`.
- GoRouter config, route definitions, and the rest of the auth flow are unchanged.
- Desktop and mobile layouts both use the same `_buildForm()` method, so the button change covers both automatically.
- The mock login path (`loginAsMock`) is not modified.

---

## Architecture

### New: `_ButtonPhase` enum (in `login_screen.dart`)

```dart
enum _ButtonPhase { idle, loading, succeeded, error }
```

Replaces the pair of `bool _loginSucceeded` + `ref.watch(authStateProvider).isLoading`. The phase is the single source of truth for button appearance.

### Changed: `AuthStateNotifier` (in `auth_provider.dart`)

`login()` is split into two steps so the login screen controls when GoRouter fires:

| Method | What it does |
|---|---|
| `loginAndHold(email, password)` | POST `/auth/login`, writes tokens to storage, stores the resulting `AppUser` in `_pendingUser`. Sets `state = const AsyncLoading()`. **Does NOT set `AsyncData`.** |
| `completeLogin()` | Sets `state = AsyncData(_pendingUser!)`. GoRouter redirect fires on this call. |

`_pendingUser` is a private `AppUser?` field on `_$AuthState`. It is reset to `null` after `completeLogin()` consumes it.

`login()` (existing method) is removed. `loginAsMock()`, `loginWithSSO()`, and `logout()` are unchanged.

### Changed: `_LoginScreenState` (in `login_screen.dart`)

- `bool _loginSucceeded` removed. Replaced by `_ButtonPhase _phase = _ButtonPhase.idle`.
- `String? _errorMessage` remains.
- `_submit()` is rewritten: calls `loginAndHold()` instead of `login()`. On success, drives the phase transitions and calls `completeLogin()` when the fade overlay signals readiness.
- The `AnimatedContainer` button uses `_phase` to morph width and border radius.
- `_SuccessOverlay` is removed from the `Stack`.
- `_FadeToWhiteOverlay` is added to the `Stack` — visible only when `_phase == _ButtonPhase.succeeded`.

### New widget: `_FadeToWhiteOverlay`

A full-screen `IgnorePointer > AnimatedOpacity > ColoredBox(white)`.

- Becomes visible (opacity 1.0) over 400 ms when `_phase == _ButtonPhase.succeeded`.
- Uses `onEnd` callback: when the fade-in completes, calls `ref.read(authStateProvider.notifier).completeLogin()`.
- GoRouter fires during the white-screen state; the app's own route transition (whatever GoRouter uses) renders underneath the white overlay, then the overlay is gone because the widget is no longer in the tree.

---

## Detailed Behaviour

### Success path timing

| Event | Time (relative to tap) |
|---|---|
| Tap → `_phase = loading` | 0 ms |
| Button morphs: width → 48, radius → 24 | 0–300 ms (AnimatedContainer, Curves.easeInOut) |
| Spinner shown (loading phase) | 0 ms – API response |
| API success → `_phase = succeeded` | API response time |
| Button: orange → green, check icon fades in | 0–200 ms |
| Hold (check visible, button green) | 200–350 ms |
| `_FadeToWhiteOverlay` begins fading in | 350 ms |
| Screen is fully white | 350 + 400 = 750 ms |
| `completeLogin()` called (onEnd callback) | 750 ms |
| GoRouter fires, app navigates in | 750 ms + 1 frame |

The `AnimatedContainer` re-expansion (back to full width, orange) never plays on success — the widget tree is replaced by GoRouter before it would appear.

### Error path timing

| Event | Detail |
|---|---|
| API error → `_phase = error` | Immediately on exception |
| Button: flashes red | `color` switches to `Color(0xFFD13438)` |
| Shake animation | `flutter_animate` `.shake(hz: 4, offset: Offset(6, 0), duration: 400.ms)` on the `AnimatedContainer` |
| After shake ends → `_phase = idle` | Triggered by `onEnd` on the shake controller |
| Button re-expands | `AnimatedContainer` animates back to `double.infinity`, orange |
| `_errorMessage` set | Error banner fades in above form fields |

---

## Button Widget Spec

```dart
// Width and radius driven by _phase
double get _btnWidth => _phase == _ButtonPhase.idle ? double.infinity : 48.0;
double get _btnRadius => _phase == _ButtonPhase.idle ? AppRadius.sm : 24.0;
Color  get _btnColor  => switch (_phase) {
  _ButtonPhase.idle      => AppColors.orange,
  _ButtonPhase.loading   => AppColors.orange,
  _ButtonPhase.succeeded => const Color(0xFF107C10),
  _ButtonPhase.error     => const Color(0xFFD13438),
};

// AnimatedContainer wrapping a FilledButton (transparent)
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: _btnWidth,
  height: 48,
  decoration: BoxDecoration(
    color: _btnColor,
    borderRadius: BorderRadius.circular(_btnRadius),
  ),
  child: FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_btnRadius),
      ),
    ),
    onPressed: _phase == _ButtonPhase.idle ? _submit : null,
    child: _buildBtnChild(),
  ),
);

// Child switcher
Widget _buildBtnChild() => AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  child: switch (_phase) {
    _ButtonPhase.idle => Text(key: const ValueKey('label'), '${l10n.signIn} →',
        style: AppTextStyles.button.copyWith(color: AppColors.white)),
    _ButtonPhase.loading => const SizedBox(key: ValueKey('spinner'),
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
    _ButtonPhase.succeeded => const Icon(key: ValueKey('check'),
        Icons.check_rounded, color: Colors.white, size: 22),
    _ButtonPhase.error => const SizedBox.shrink(key: ValueKey('empty')),
  },
);
```

---

## `_FadeToWhiteOverlay` Widget Spec

```dart
class _FadeToWhiteOverlay extends StatelessWidget {
  final bool visible;
  final VoidCallback onFadeComplete;
  const _FadeToWhiteOverlay({required this.visible, required this.onFadeComplete});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
        onEnd: visible ? onFadeComplete : null,
        child: const ColoredBox(color: Colors.white,
            child: SizedBox.expand()),
      ),
    );
  }
}
```

Placed last in the root `Stack` in `_LoginScreenState.build()`:

```dart
Stack(
  children: [
    LayoutBuilder(...),  // existing layouts
    _FadeToWhiteOverlay(
      visible: _phase == _ButtonPhase.succeeded,
      onFadeComplete: () {
        ref.read(authStateProvider.notifier).completeLogin();
      },
    ),
  ],
)
```

---

## `_submit()` Rewrite

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
    // Turn green, show check, then _FadeToWhiteOverlay takes over
    setState(() => _phase = _ButtonPhase.succeeded);
    // completeLogin() is called by _FadeToWhiteOverlay.onFadeComplete
  } on Exception catch (e) {
    if (!mounted) return;
    setState(() {
      _phase = _ButtonPhase.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    });
    // After shake, re-expand via a Future.delayed or flutter_animate onComplete
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _phase = _ButtonPhase.idle);
  }
}
```

---

## `auth_provider.dart` Changes

### New field

```dart
AppUser? _pendingUser;
```

### New method: `loginAndHold`

```dart
Future<void> loginAndHold({required String email, required String password}) async {
  state = const AsyncLoading();

  final result = await AsyncValue.guard(() async {
    final dio = ref.read(dioProvider);
    final storage = ref.read(secureStorageProvider);

    final response = await dio.post(
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
    // Surface the error to the caller — restore state to previous null
    state = const AsyncData(null);
    throw result.error!;
  }

  _pendingUser = result.value;
  // state remains AsyncLoading — GoRouter does NOT fire yet
}
```

### New method: `completeLogin`

```dart
void completeLogin() {
  assert(_pendingUser != null, 'completeLogin called before loginAndHold succeeded');
  state = AsyncData(_pendingUser);
  _pendingUser = null;
}
```

### Removed method

`login()` is deleted. No other callers exist (confirmed by searching the codebase — only `_submit()` in `login_screen.dart` called it).

---

## Files Changed

| File | Change |
|---|---|
| `lib/core/auth/auth_provider.dart` | Add `_pendingUser`, add `loginAndHold()`, add `completeLogin()`, remove `login()` |
| `lib/features/auth/login_screen.dart` | Add `_ButtonPhase`, rewrite `_submit()`, morph `AnimatedContainer`, add `_FadeToWhiteOverlay`, remove `_SuccessOverlay` |

No other files. No new packages.

---

## Testing

### Unit / widget tests

| Test | File |
|---|---|
| `loginAndHold` sets `AsyncLoading` and does not set `AsyncData` | `test/core/auth/auth_provider_test.dart` |
| `completeLogin` sets `AsyncData(user)` | same |
| `loginAndHold` on 401 throws and resets state to `AsyncData(null)` | same |
| Button morphs to 48 px circle when phase is loading | `test/features/auth/login_screen_test.dart` |
| `_FadeToWhiteOverlay` is not visible when phase is idle | same |
| `_FadeToWhiteOverlay` is visible when phase is succeeded | same |

### Manual acceptance criteria

- [ ] Sign in with valid creds → button shrinks to circle, spinner shows, turns green, screen fades to white, app appears
- [ ] Sign in with invalid creds → button shrinks, spinner, flashes red and shakes, re-expands, error banner appears
- [ ] Desktop (≥ 700 px) and mobile layouts both behave identically
- [ ] Back-navigating to login (logout) shows the button in idle state with no visual artifacts
