# Login Page Redesign — Design Spec

## Goal

Elevate `LoginScreen` from a plain centered-card layout to a premium split-panel design that matches the rest of the app's visual direction (blue gradient sidebar, gradient MetricCards, PageHeader gradients).

## Decisions Made

| Decision | Choice |
|---|---|
| Layout | Split panel — gradient left, white form right |
| Left panel width | 42% on desktop (≥ 700 px) |
| Left panel background | `AppGradients.primaryHeader` (#0078D4 → #005A9E), `topLeft → bottomRight` |
| Right panel background | `AppSurfaces.page` (#FAFAFA) |
| Sign In button | Keep orange (`AppColors.orange`) gradient — accent contrast against blue left panel |
| Animations | Subtle entrance only — left panel `fadeIn`, form card `fadeIn + slideY` |
| Mobile behaviour | Gradient header bar + form card below (no brand panel text) |

---

## Desktop Layout (width ≥ 700 px)

```
┌────────────────────────────┬──────────────────────────────┐
│  LEFT PANEL (42%)          │  RIGHT PANEL (58%)           │
│  primaryHeader gradient    │  AppSurfaces.page            │
│                            │                              │
│  [logo 44px]  ReguLit      │      Welcome back            │
│                            │      Sign in to your account │
│  "Compliance made          │                              │
│   clear and simple."       │  EMAIL ADDRESS               │
│                            │  [________________]          │
│  GRC workflows, risk       │                              │
│  visibility, and audit     │  PASSWORD                    │
│  readiness — in one place. │  [________________]          │
│                            │                              │
│  ✓ Risk assessment         │      Forgot password?        │
│  ✓ Workflow automation     │  [  Sign In →  ]  (orange)   │
│  ✓ Audit-ready reports     │                              │
│                            │  footer caption              │
│  [glow orbs × 3]           │                              │
└────────────────────────────┴──────────────────────────────┘
```

### Left Panel

- Background: `AppGradients.primaryHeader` (`BoxDecoration.gradient`)
- Width: `0.42 * screenWidth` on a `Row`; enforced via `FractionallySizedBox` or explicit `width`
- Logo: `Image.asset('assets/images/newlogo.png', width: 44, height: 44)` with `FilterQuality.high`
- Brand name: `"ReguLit"` — 22 px, `FontWeight.w800`, `Colors.white`
- Brand row: logo + name in a `Row` with 11 px gap, top-left aligned
- Headline: `"Compliance made\nclear and simple."` — 18 px, `FontWeight.w700`, `Colors.white`, `height: 1.35`
- Sub-text: `l10n.loginTagline` — 13 px, `Color(0xA6FFFFFF)` (65% white) — already translated into all 5 supported languages; repurposed from the old above-card position
- Feature bullets (3 items): 20×20 dp rounded rect chip (`rgba(255,255,255,0.15)`, border `rgba(255,255,255,0.20)`, radius 6), checkmark icon `Icons.check` 10 px white, label 11 px `rgba(255,255,255,0.80)`. Items are localisation keys `loginFeature1/2/3` if they exist, otherwise hardcoded English strings.
- Glow orbs (3, decorative, `IgnorePointer`):
  - Orb 1: 180 × 180 dp, `rgba(255,255,255,0.07)`, `Positioned(top: -50, right: -60)`
  - Orb 2: 110 × 110 dp, `rgba(255,255,255,0.05)`, `Positioned(bottom: -30, left: -30)`
  - Orb 3: 60 × 60 dp, `rgba(255,255,255,0.06)`, `Positioned(bottom: 80, right: 20)`

### Right Panel

- Background: `AppSurfaces.page`
- Content horizontally and vertically centred in the available space (`Center` → `ConstrainedBox(maxWidth: 360)`)
- Heading: `"Welcome back"` — 20 px, `FontWeight.w800`, `AppColors.text` (hardcoded English; no l10n key exists)
- Sub: `"Sign in to your account"` — 13 px, `AppColors.muted` (hardcoded English)
- Form: existing `Form` widget — fields, forgot-password link, sign-in button, footer — **unchanged in behaviour**
- Sign-in button: keep existing orange `FilledButton` style (no change)

---

## Mobile Layout (width < 700 px)

Single-column. The brand panel is replaced by a compact gradient header bar:

```
┌──────────────────────────────┐
│  [logo 30px]  ReguLit        │  ← primaryHeader gradient, padding 16/14
│                              │
│  ┌────────────────────────┐  │  ← form card, margin-top: -10px overlap
│  │  Welcome back          │  │    white, borderRadius 14, shadow
│  │  [email field]         │  │
│  │  [password field]      │  │
│  │  [Sign In →]           │  │
│  └────────────────────────┘  │
│  footer                      │
└──────────────────────────────┘
```

- Header bar: `primaryHeader` gradient, padding `fromLTRB(16, 48, 16, 28)` (top accounts for status bar)
  - Logo 30 × 30 dp + "ReguLit" 16 px w800 white in a Row
- Form card: white, `borderRadius: 14`, `boxShadow: AppShadows.md`, `margin: EdgeInsets.fromLTRB(16, -10, 16, 0)` — the negative top margin creates the overlap effect
- Form content unchanged (same fields, button, footer)
- Background below card: `AppSurfaces.page`

---

## Animations

Both use `flutter_animate` (already a dependency):

| Element | Animation |
|---|---|
| Left brand panel | `.animate().fadeIn(duration: 400.ms)` |
| Right form content | `.animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.08, curve: Curves.easeOut, duration: 500.ms, delay: 200.ms)` |
| Mobile form card | `.animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.10, curve: Curves.easeOut, duration: 400.ms, delay: 150.ms)` |

---

## Implementation Notes

- The breakpoint check `constraints.maxWidth >= 700` uses `LayoutBuilder` wrapping the `Scaffold` body.
- The existing `_LoginScreenState` logic (`_submit`, `_prefillEmail`, `_showForgotPassword`, form key, controllers) is **unchanged** — only the `build` method's layout changes.
- The existing `_ErrorBanner` and `_ForgotPasswordDialog` widgets are **unchanged**.
- No new dependencies required (`flutter_animate` is already used in the dashboard).
- The left panel feature bullets use hardcoded English strings (the three strings are not in the existing l10n ARB files — adding l10n keys is out of scope).

---

## Files Affected

| File | Change |
|---|---|
| `lib/features/auth/login_screen.dart` | Restructure `build` — add `LayoutBuilder`, `_BrandPanel`, `_FormPanel`, `_MobileHeader` widgets; existing `_ErrorBanner` / `_ForgotPasswordDialog` unchanged |

No other files require changes.

---

## Out of Scope

- Adding the feature-bullet strings to ARB localisation files
- Any changes to auth logic, form validation, or forgot-password flow
- Animated background (pulsing orbs, particles) — explicitly not chosen
