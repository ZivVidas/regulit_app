# Splash Screen Redesign

## Goal

Replace the splash screen's ad-hoc deep-navy palette with the app's primary blue gradient (`AppGradients.primaryHeader`), making the splash feel like a natural, in-context intro to the app's visual language. All existing animations are preserved; `withOpacity` calls are cleaned up to `withValues(alpha:)` throughout.

## Files Changed

| File | Change |
|---|---|
| `lib/features/splash/splash_screen.dart` | All changes — one file only |

No new dependencies. `flutter_animate` is already imported.

---

## 1. Remove Ad-Hoc Palette, Add Theme Import

Remove the five colour constants from `_SplashView`:

```dart
// DELETE all five:
static const _bg      = Color(0xFF04091A);
static const _grad1   = Color(0xFF06102A);
static const _grad2   = Color(0xFF0A1840);
static const _accent  = Color(0xFF0078D4);
static const _accentL = Color(0xFF58C2F0);
```

Add the theme import at the top of the file:

```dart
import 'package:regulit_app/app/theme.dart';
```

---

## 2. Background Gradient

In `_SplashView.build()`, change two things:

**Scaffold `backgroundColor`:** `_bg` → `AppColors.blueDark`

**Container gradient:**

```dart
// was:
gradient: LinearGradient(
  colors: [_bg, _grad1, _grad2],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
),

// becomes:
gradient: AppGradients.primaryHeader,
```

`AppGradients.primaryHeader` is `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blue, AppColors.blueDark])` — the same gradient used in screen headers and the Kanban column headers.

---

## 3. Glow Circles — Blue → White

The three `_GlowCircle` usages currently pass `_accent` or `_accentL`. On a blue gradient background, white glows are correct:

```dart
// was (top-right circle):
_GlowCircle(size: 320, color: _accent, opacity: 0.07)

// becomes:
_GlowCircle(size: 320, color: Colors.white, opacity: 0.07)


// was (bottom-left circle):
_GlowCircle(size: 260, color: _accentL, opacity: 0.05)

// becomes:
_GlowCircle(size: 260, color: Colors.white, opacity: 0.05)


// was (small left circle):
_GlowCircle(size: 140, color: _accent, opacity: 0.04)

// becomes:
_GlowCircle(size: 140, color: Colors.white, opacity: 0.04)
```

Keep all `opacity` values and `.animate().scale(...)` chains unchanged.

---

## 4. `_GifLogo` — Adapt Halo and Ring for Blue Background

The outer radial-gradient halo currently uses `Color(0xFF0078D4)` (blue-on-dark). On a blue background, switch to white:

```dart
// was:
gradient: RadialGradient(
  colors: [
    const Color(0xFF0078D4).withOpacity(0.18),
    const Color(0xFF0078D4).withOpacity(0.0),
  ],
),

// becomes:
gradient: RadialGradient(
  colors: [
    Colors.white.withValues(alpha: 0.14),
    Colors.white.withValues(alpha: 0.0),
  ],
),
```

The ring border currently uses `Color(0xFF58C2F0)` (light blue). Switch to white:

```dart
// was:
border: Border.all(
  color: const Color(0xFF58C2F0).withOpacity(0.14),
  width: 1.5,
),

// becomes:
border: Border.all(
  color: Colors.white.withValues(alpha: 0.28),
  width: 1.5,
),
```

GIF asset path, size (148×148), `filterQuality`, and the breathing `.animate(onPlay: ...)` chain are **unchanged**.

---

## 5. `_ProgressBar` — White Fill on Blue Background

The progress fill colour was Azure Blue (visible on dark). On the blue gradient background, it must be white:

```dart
// was:
valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0078D4)),

// becomes:
valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.88)),
```

Track background:

```dart
// was:
backgroundColor: Colors.white.withOpacity(0.10),

// becomes:
backgroundColor: Colors.white.withValues(alpha: 0.18),
```

"Loading…" text colour — make it a touch more readable:

```dart
// was:
color: Colors.white.withOpacity(0.35),

// becomes:
color: Colors.white.withValues(alpha: 0.45),
```

`TweenAnimationBuilder`, `SizedBox`, `ClipRRect`, and the pulsing `.animate(onPlay: ...)` chain are **unchanged**.

---

## 6. Tagline and Footer — `withOpacity` Cleanup

Tagline in `_SplashView.build()`:

```dart
// was:
color: Colors.white.withOpacity(0.45),

// becomes:
color: Colors.white.withValues(alpha: 0.55),
```

Footer text:

```dart
// was:
color: Colors.white.withOpacity(0.2),

// becomes:
color: Colors.white.withValues(alpha: 0.35),
```

---

## 7. `_GlowCircle.build()` — `withOpacity` Cleanup

```dart
// was:
color: color.withOpacity(opacity),

// becomes:
color: color.withValues(alpha: opacity),
```

---

## Non-Changes

- All entrance animation chains (`scale`, `fadeIn`, `slideY`, stagger delays) are **unchanged**.
- Breathing pulse on logo (`1.0 + v * 0.03`, 2800 ms, repeat reverse) is **unchanged**.
- Screen structure (`Stack` → `Center` → `Column`) is **unchanged**.
- `_ProgressBar` `TweenAnimationBuilder` logic (0→1.0, 2400 ms, easeInOut) is **unchanged**.
- Tagline text ("Compliance that protects.") is **unchanged**.
- Footer text ("© 2025 Regulit · Privacy by design") is **unchanged**.
- No new widgets, providers, routes, or dependencies.
