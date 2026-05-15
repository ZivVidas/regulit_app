# Fancy UI — Phase 2 Design Spec

## Goal

Push the ReguLit Flutter app's visual quality from "clean and consistent" to "premium SaaS product" — focusing on two high-leverage components that affect every screen: MetricCard (gradient fill) and AppShell desktop sidebar (expanded labels).

## Decisions Made

| Decision | Choice |
|---|---|
| Visual direction | Modern SaaS — light, bold, sharp |
| Metric card style | Full gradient fill, white text |
| Animation level | Subtle polish only — gentle fades, no pulsing |
| Desktop sidebar | 160 px expanded — app name, grouped labels, user info |
| Approach | Component-first — MetricCard + AppShell, screens inherit automatically |

---

## Component 1 — MetricCard (gradient fill)

### What changes

The current `MetricCard` renders on a white or tinted background with a colored value. The upgraded version fills the entire card with a semantic gradient and renders all text in white.

### Gradient mapping per variant

| `MetricVariant` | Gradient | Shadow tint |
|---|---|---|
| `neutral` | `AppGradients.primaryHeader` (#0078D4 → #005A9E) | `rgba(0,120,212,0.25)` |
| `success` | `AppGradients.successHeader` (#107C10 → #0A5C0A) | `rgba(16,124,16,0.25)` |
| `warning` | `AppGradients.warningHeader` (#CA8A04 → #D97C0A) | `rgba(202,138,4,0.25)` |
| `danger` | `AppGradients.dangerHeader` (#D13438 → #A01010) | `rgba(209,52,56,0.25)` |

Two new gradients must be added to `AppGradients` in `theme.dart`: `successHeader` and `warningHeader`. (`dangerHeader` and `primaryHeader` already exist or can reuse `primaryHeader`.) The `dangerHeader` is new.

### Typography on gradient cards

All text switches to white palette:

- **Label** (uppercase, small): `rgba(255,255,255,0.70)`
- **Value** (28 px bold): `white`
- **Trend label**: `rgba(255,255,255,0.80)`
- **Trend icon**: same color as trend label (not the semantic green/red)
- **Sub text**: `rgba(255,255,255,0.75)`

### Icon

The `icon` parameter is kept. Rendered at 20 px, `rgba(255,255,255,0.80)`. No tinted chip background.

### Glow orb decoration

A decorative circle sits behind the content (Stack, positioned top-right, pointer-events none):

- Size: 90 × 90 dp
- Color: `rgba(255,255,255,0.10)`
- Offset: `top: -25, right: -15`

This is purely decorative — no animation (consistent with "subtle" choice).

### Shadow

Replace the current neutral `AppShadows.md` with a colored shadow per variant (4 dp blur, 20 dp spread equivalent — implemented as a single BoxShadow with `spreadRadius: 0`):

```dart
BoxShadow(color: _variantShadowColor, blurRadius: 20, offset: Offset(0, 4))
```

### Removed: `tinted` parameter

The `tinted: bool` parameter is removed. All MetricCards now use gradient fill. Any call sites that pass `tinted: true` must be updated to remove the argument (the behavior is now the default). Call sites that pass `tinted: false` (the default) require no change — just remove the named argument.

### Kept unchanged

- `MetricCard.currency` factory
- `MetricCard.percent` factory
- `MetricTrend`, `TrendDirection` model classes
- `MetricRow` responsive wrapper
- Tap behaviour and `onTap` parameter
- `trailing` parameter

---

## Component 2 — AppShell desktop sidebar (160 px expanded)

### What changes

The current `_DesktopSidebar` is 56 px wide and shows only icons with tooltips. The upgraded version is 160 px wide and always shows labels, a brand row, section group labels, and a user footer.

### Structure (top → bottom)

```
[16 px top padding]
Brand row:   [36px logo image]  [ReguLit — 14px bold white]
[20 px gap]
Section label (if group starts):  "MAIN" — 9px uppercase, white 35% opacity
Nav item row: [icon 18px]  [label 12px]  — active: white bg 13%, white text; inactive: white 55%
...
[Spacer]
[Divider — white 12%]
User footer:  [24px avatar circle] [name 11px bold] / [role 9px white 50%]
[8 px bottom padding]
```

### Section grouping

Add an optional `group` field to `_NavItem`:

```dart
class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final String? group;          // NEW — section header text
  const _NavItem({required this.icon, required this.label, required this.route, this.group});
}
```

When building the sidebar item list, insert a `_SidebarSectionLabel` widget before the first item of each new group. Group labels are shown only if at least one item in the list has a non-null group.

#### Group assignments per role

**regulitAdmin**: Main → [Users, Customers], Workflows → [Quizzes, Workflows, Agents], System → [Admin Dashboard]

**csm / analyst**: Clients → [Clients, Evidence Queue], Monitoring → [Alerts, Reports]

**clientAdmin**: Main → [Dashboard, Kanban], Manage → [Session Files, Users]

**itExecutor / employee**: no groups (items displayed without section labels)

### Language picker

Keep the existing `_LanguagePicker` widget. In the expanded sidebar it sits above the user footer, rendering its icon + a short "Language" text label in the same style as nav items.

### User footer

Displays `user.name` (bold, 11 px, white) and `user.role?.name ?? ''` (9 px, white 50%). Tapping shows the existing logout dialog. No tooltip needed (name is already visible).

### Active item indicator

Rounded rectangle background: `rgba(255,255,255,0.13)`, `BorderRadius.circular(10)`. No yellow chip — the current orange active background is replaced with the subtle white glass style matching the preview.

### Mobile

BottomNavigationBar is **unchanged** — the 160 px expansion is desktop-only.

### VerticalDivider between sidebar and content

Keep the existing `VerticalDivider(width: 1)`. No changes needed.

---

## theme.dart additions

Three new gradients added to `AppGradients`:

```dart
static const LinearGradient successHeader = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF107C10), Color(0xFF0A5C0A)],
);

static const LinearGradient warningHeader = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFCA8A04), Color(0xFFD97C0A)],
);

static const LinearGradient dangerHeader = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFD13438), Color(0xFFA01010)],
);
```

---

## Files affected

| File | Change |
|---|---|
| `lib/app/theme.dart` | Add `successHeader`, `warningHeader`, `dangerHeader` to `AppGradients` |
| `lib/shared/widgets/metric_card.dart` | Gradient fill, glow orb, white text palette, colored shadow, remove `tinted` |
| `lib/shared/widgets/app_shell.dart` | Expand `_DesktopSidebar` to 160 px, add brand row, section labels, user footer |
| `test/shared/widgets/metric_card_test.dart` | Update tests to reflect gradient cards (no `tinted` param) |
| `test/shared/widgets/app_shell_test.dart` | Update/add tests for expanded sidebar |

No call sites pass `tinted:` — the parameter was defined in Phase 1 but never used in screens. Removing it requires no call-site updates.

---

## Out of scope

- `AppCard` accent bar — deferred; no screen currently needs it
- Expressive animations (pulsing glow orb, spring physics) — explicitly not chosen
- Mobile sidebar changes
- Any screen-level layout changes beyond what inherits automatically from the two components
