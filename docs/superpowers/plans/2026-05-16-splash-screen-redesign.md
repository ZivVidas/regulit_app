# Splash Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the splash screen's ad-hoc deep-navy palette with `AppGradients.primaryHeader` and clean up all `withOpacity` calls to `withValues(alpha:)`, making the splash feel like a natural intro to the app's visual language.

**Architecture:** All changes are in `lib/features/splash/splash_screen.dart`. The five ad-hoc colour constants (`_bg`, `_grad1`, `_grad2`, `_accent`, `_accentL`) are removed and every reference replaced in one atomic task so the file always compiles. No animation logic, widget structure, or screen behaviour changes.

**Tech Stack:** Flutter 3, Dart, flutter_animate (already imported)

---

### Task 1: Smoke test

**Files:**
- Create: `test/features/splash/splash_screen_test.dart`

---

- [ ] **Step 1: Create the test file**

Create `test/features/splash/splash_screen_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/features/splash/splash_screen.dart';

void main() {
  // The breathing animation and pulsing "Loading…" text loop forever.
  // pumpAndSettle would time out — use pump(Duration) throughout.

  testWidgets('SplashScreen renders without error', (tester) async {
    await tester.pumpWidget(const SplashScreen());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('Loading text appears after entrance delay', (tester) async {
    await tester.pumpWidget(const SplashScreen());
    // Progress bar delay 600 ms + animation 400 ms → pump past 1100 ms.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('Compliance tagline appears', (tester) async {
    await tester.pumpWidget(const SplashScreen());
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Compliance that protects.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests**

```
flutter test test/features/splash/splash_screen_test.dart
```

Expected: All 3 tests PASS. These are regression guards — they verify the screen renders and its key text content survives the colour changes ahead.

- [ ] **Step 3: Commit**

```bash
git add test/features/splash/splash_screen_test.dart
git commit -m "test: splash screen smoke tests (regression guards)"
```

---

### Task 2: Remove ad-hoc constants, add theme import, swap background and glow colours

All five colour constants are referenced in both the background gradient and the glow circles, so their call sites must be updated in one go before the constants are deleted.

**Files:**
- Modify: `lib/features/splash/splash_screen.dart` (lines 1–65, 244–249)

---

- [ ] **Step 1: Add the theme import**

In `lib/features/splash/splash_screen.dart`, add after line 1 (`import 'package:flutter/material.dart';`):

```dart
import 'package:regulit_app/app/theme.dart';
```

- [ ] **Step 2: Delete the five colour constants**

In `_SplashView`, delete lines 21–25:

```dart
// DELETE these five lines:
static const _bg      = Color(0xFF04091A);
static const _grad1   = Color(0xFF06102A);
static const _grad2   = Color(0xFF0A1840);
static const _accent  = Color(0xFF0078D4);
static const _accentL = Color(0xFF58C2F0);
```

- [ ] **Step 3: Update Scaffold `backgroundColor`**

```dart
// FIND (around line 29 after deletion):
Scaffold(
  backgroundColor: _bg,

// REPLACE WITH:
Scaffold(
  backgroundColor: AppColors.blueDark,
```

- [ ] **Step 4: Replace the Container gradient**

```dart
// FIND (around line 33):
gradient: LinearGradient(
  colors: [_bg, _grad1, _grad2],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
),

// REPLACE WITH:
gradient: AppGradients.primaryHeader,
```

`AppGradients.primaryHeader` is `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blue, AppColors.blueDark])` — the same gradient used in screen headers throughout the app.

- [ ] **Step 5: Update the three glow circle colour arguments**

```dart
// FIND (top-right circle, around line 44):
_GlowCircle(size: 320, color: _accent, opacity: 0.07)
// REPLACE WITH:
_GlowCircle(size: 320, color: Colors.white, opacity: 0.07)

// FIND (bottom-left circle, around line 52):
_GlowCircle(size: 260, color: _accentL, opacity: 0.05)
// REPLACE WITH:
_GlowCircle(size: 260, color: Colors.white, opacity: 0.05)

// FIND (small left circle, around line 63):
_GlowCircle(size: 140, color: _accent, opacity: 0.04),
// REPLACE WITH:
_GlowCircle(size: 140, color: Colors.white, opacity: 0.04),
```

Keep all three `.animate().scale(...)` chains unchanged.

- [ ] **Step 6: Fix `_GlowCircle.build()` — `withOpacity` → `withValues(alpha:)`**

In `_GlowCircle.build()` (around line 249):

```dart
// FIND:
color: color.withOpacity(opacity),

// REPLACE WITH:
color: color.withValues(alpha: opacity),
```

- [ ] **Step 7: Run tests**

```
flutter test test/features/splash/splash_screen_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/splash/splash_screen.dart
git commit -m "feat: swap splash background to AppGradients.primaryHeader, white glow circles"
```

---

### Task 3: `_GifLogo` — white halo and ring border

**Files:**
- Modify: `lib/features/splash/splash_screen.dart` (lines 144–164)

---

- [ ] **Step 1: Update the outer radial-gradient halo**

In `_GifLogo.build()`, find the 220×220 outer glow `Container`. Update its `RadialGradient`:

```dart
// FIND (around line 146):
gradient: RadialGradient(
  colors: [
    const Color(0xFF0078D4).withOpacity(0.18),
    const Color(0xFF0078D4).withOpacity(0.0),
  ],
),

// REPLACE WITH:
gradient: RadialGradient(
  colors: [
    Colors.white.withValues(alpha: 0.14),
    Colors.white.withValues(alpha: 0.0),
  ],
),
```

- [ ] **Step 2: Update the ring border**

In `_GifLogo.build()`, find the 168×168 ring `Container`:

```dart
// FIND (around line 160):
border: Border.all(
  color: const Color(0xFF58C2F0).withOpacity(0.14),
  width: 1.5,
),

// REPLACE WITH:
border: Border.all(
  color: Colors.white.withValues(alpha: 0.28),
  width: 1.5,
),
```

- [ ] **Step 3: Run tests**

```
flutter test test/features/splash/splash_screen_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/splash/splash_screen.dart
git commit -m "feat: white glow halo and ring on splash logo"
```

---

### Task 4: `_ProgressBar` — white fill, track, and label colour

**Files:**
- Modify: `lib/features/splash/splash_screen.dart` (lines 201–222)

---

- [ ] **Step 1: Update the progress fill colour**

In `_ProgressBar.build()`, find the `valueColor` argument of `LinearProgressIndicator`:

```dart
// FIND (around line 207):
valueColor: const AlwaysStoppedAnimation<Color>(
  Color(0xFF0078D4),
),

// REPLACE WITH:
valueColor: AlwaysStoppedAnimation<Color>(
  Colors.white.withValues(alpha: 0.88),
),
```

`const` is removed because `withValues` is not a const expression.

- [ ] **Step 2: Update the track background**

```dart
// FIND (around line 205):
backgroundColor: Colors.white.withOpacity(0.10),

// REPLACE WITH:
backgroundColor: Colors.white.withValues(alpha: 0.18),
```

- [ ] **Step 3: Update the "Loading…" text colour**

```dart
// FIND (around line 215):
color: Colors.white.withOpacity(0.35),

// REPLACE WITH:
color: Colors.white.withValues(alpha: 0.45),
```

- [ ] **Step 4: Run tests**

```
flutter test test/features/splash/splash_screen_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/splash/splash_screen.dart
git commit -m "feat: white progress bar fill and track on splash screen"
```

---

### Task 5: Tagline + footer `withOpacity` → `withValues(alpha:)` and full suite

**Files:**
- Modify: `lib/features/splash/splash_screen.dart` (lines 89, 117)

---

- [ ] **Step 1: Update tagline colour**

In `_SplashView.build()`, find the tagline `Text` style:

```dart
// FIND (around line 89):
color: Colors.white.withOpacity(0.45),

// REPLACE WITH:
color: Colors.white.withValues(alpha: 0.55),
```

- [ ] **Step 2: Update footer colour**

In `_SplashView.build()`, find the bottom brand line `Text` style:

```dart
// FIND (around line 117):
color: Colors.white.withOpacity(0.2),

// REPLACE WITH:
color: Colors.white.withValues(alpha: 0.35),
```

- [ ] **Step 3: Run splash tests**

```
flutter test test/features/splash/splash_screen_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 4: Run full test suite**

```
flutter test
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/splash/splash_screen.dart
git commit -m "fix: withOpacity → withValues(alpha:) in splash tagline and footer"
```
