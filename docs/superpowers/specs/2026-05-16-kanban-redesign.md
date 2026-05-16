# Kanban Board Redesign

## Goal

Elevate the Kanban board (`task_board_screen.dart`) to match the app's premium SaaS visual language — gradient column headers, 3 px left-accent task cards, polished metric tiles, and staggered entrance animations — without changing any board behavior, data flow, or drag-and-drop logic.

## Files Changed

| File | Change |
|---|---|
| `lib/app/theme.dart` | Add `AppGradients.neutralHeader` for the To Do column |
| `lib/features/tasks/task_board_screen.dart` | All visual changes |

---

## 1. `AppGradients.neutralHeader` (theme.dart)

Add after the existing `AppGradients.primaryHeader` entry:

```dart
static const LinearGradient neutralHeader = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF8A8886), Color(0xFF605E5C)],
);
```

---

## 2. Column Headers — Gradient Fill (`_KanbanCol`)

### Parameter change

Remove `headerColor` (Color) and `headerBg` (Color). Replace with:

```dart
final LinearGradient gradient;
```

All callsites in `_KanbanBoard.build()` change to:

| Column | Old `headerColor` / `headerBg` | New `gradient` |
|---|---|---|
| To Do | `AppColors.muted` / `AppColors.surface` | `AppGradients.neutralHeader` |
| In Progress | `AppColors.warning` / `AppColors.warningLight` | `AppGradients.warningHeader` |
| Pending Review | `AppColors.orange` / `AppColors.orangeLight` | `AppGradients.secondaryHeader` |
| Done | `AppColors.success` / `AppColors.successLight` | `AppGradients.successHeader` |
| Overdue | `AppColors.danger` / `AppColors.dangerLight` | `AppGradients.dangerHeader` |

### Column outer `AnimatedContainer`

Wherever `widget.headerColor` was used for the column border and drag-over background, use `widget.gradient.colors.first` instead:

```dart
// was: widget.headerColor.withOpacity(0.06) / 0.65 / 0.3
decoration: BoxDecoration(
  color: isHovering
      ? widget.gradient.colors.first.withValues(alpha: 0.06)
      : AppColors.surface,
  borderRadius: BorderRadius.circular(10),
  border: Border.all(
    color: isHovering
        ? widget.gradient.colors.first.withValues(alpha: 0.65)
        : widget.gradient.colors.first.withValues(alpha: 0.30),
    width: isHovering ? 2 : 1,
  ),
),
```

### Header container

Replace the `Container` + `SectionHeader` block with a direct `Container` using the gradient and white text. Remove the `SectionHeader` call and the `section_header.dart` import:

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  decoration: BoxDecoration(
    gradient: isHovering ? null : widget.gradient,
    color: isHovering
        ? widget.gradient.colors.first.withValues(alpha: 0.12)
        : null,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
  ),
  child: Row(
    children: [
      Expanded(
        child: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
      ),
      if (isHovering)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: const Icon(
            Icons.move_down_rounded,
            size: 13,
            color: Colors.white,
          ),
        ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          '${widget.tasks.length}',
          style: AppTextStyles.tag.copyWith(color: Colors.white),
        ),
      ),
    ],
  ),
),
```

Note: `gradient` and `color` are mutually exclusive on `BoxDecoration`. When `isHovering` is true, set `color` and leave `gradient` null; otherwise set `gradient` and leave `color` null. This gives a subtle wash on drag-over while keeping the gradient at rest.

---

## 3. Task Cards — 3 px Left Accent Border (`_TaskCard`)

### Replace `AppCard` wrapper

The current `_buildCard()` wraps content in `AppCard(variant: elevated)`. Flutter's `BoxDecoration` does not support non-uniform borders combined with `borderRadius`, so the left-only border must be implemented as a thin child `Container` inside a clipped wrapper.

Remove the `AppCard` import (`app_card.dart`) after this change.

Replace the `AppCard(...)` call with:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 150),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
  ),
  clipBehavior: Clip.antiAlias,
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // 3 px accent stripe
      Container(width: 3, color: _accent),
      // Card body
      Expanded(
        child: widget.onTap != null
            ? Material(
                color: Colors.white,
                child: InkWell(
                  onTap: dragging ? null : widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ...existing card body Column...,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ...existing card body Column...,
              ),
      ),
    ],
  ),
),
```

The `clipBehavior: Clip.antiAlias` on `AnimatedContainer` clips the Row (stripe + content) to the rounded rect, so corners are clean. The `BoxDecoration.boxShadow` is painted outside the clip as usual.

### Done column opacity

`_TaskCard` already receives `dimmed: true` for the Done column, but the field is never applied visually. Wrap the outermost `Padding(padding: EdgeInsets.only(bottom: 2), ...)` in an `Opacity` widget:

```dart
return Opacity(
  opacity: widget.dimmed ? 0.72 : 1.0,
  child: MouseRegion(
    ...existing MouseRegion...
  ),
);
```

---

## 4. Metric Tiles — Outlined Box (`_MetricTile`)

Increase the inner box from 36 × 36 to 38 × 38 and add a 1.5 px colored border outline:

```dart
Container(
  width: 38,
  height: 38,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: bgColor,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: color.withValues(alpha: 0.40), width: 1.5),
  ),
  child: Text('$value', style: AppTextStyles.h3.copyWith(color: color)),
),
```

No other changes to `_MetricBar`.

---

## 5. Entrance Animations (flutter_animate)

Add `import 'package:flutter_animate/flutter_animate.dart';` to `task_board_screen.dart`.

### Column stagger (`_KanbanBoard.build()`)

Wrap each `_KanbanCol(...)` call (and the `Gap` between them is unchanged):

```dart
_KanbanCol(...).animate(delay: 0.ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.05, curve: Curves.easeOut),
// Gap unchanged
_KanbanCol(...).animate(delay: 50.ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.05, curve: Curves.easeOut),
// ... repeat at 100 ms, 150 ms, 200 ms for remaining columns
```

### Card stagger (`_KanbanColState.build()`)

Inside the `for` loop that renders cards, animate each `_TaskCard`:

```dart
_TaskCard(
  task: widget.tasks[i],
  dimmed: widget.dimmed,
  l10n: widget.l10n,
  canDrag: _canDrag(widget.tasks[i]),
  onTap: widget.onTaskTap == null
      ? null
      : () => widget.onTaskTap!(widget.tasks[i]),
).animate(delay: Duration(milliseconds: i * 30))
    .fadeIn(duration: 200.ms)
    .slideY(begin: 0.04, curve: Curves.easeOut),
```

---

## 6. Import Cleanup

After all changes, remove unused imports from `task_board_screen.dart`:

- `import '../../shared/widgets/app_card.dart';` — no longer used
- `import '../../shared/widgets/section_header.dart';` — no longer used

---

## Non-Changes

- All drag-and-drop logic (`DragTarget`, `Draggable`, `onStatusChange`) is unchanged.
- All card data fields (name, description, due date, assignee, required badge, evidence count) are unchanged.
- `_MetricBar` filter dropdown and overdue warning badge are unchanged.
- `_SessionBar`, `_SessionDropdown`, `_FilterDropdown` are unchanged.
- No new providers, models, or routes.
- No new dependencies (flutter_animate already in pubspec).
