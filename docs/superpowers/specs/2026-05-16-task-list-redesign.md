# Task List Screen Redesign

## Goal

Elevate the task list screen (`task_list_screen.dart`) to match the app's premium SaaS visual language — elevated left-accent task tiles, stagger entrance animations, and `withValues(alpha:)` API cleanup — without changing any screen behaviour, data flow, or tap logic.

## Files Changed

| File | Change |
|---|---|
| `lib/features/tasks/task_list_screen.dart` | All visual changes |

No new dependencies. `flutter_animate` is already in `pubspec.yaml`.

---

## 1. `_TaskListTile` — Elevated Left-Accent Card

### Convert to StatefulWidget

`_TaskListTile` must become a `StatefulWidget` to hold hover state:

```dart
class _TaskListTile extends StatefulWidget {
  final WorkflowTask task;
  final bool isItExecutor;
  final bool canChangeStatus;
  final AppLocalizations l10n;
  final VoidCallback onRefresh;

  const _TaskListTile({
    required this.task,
    required this.isItExecutor,
    required this.canChangeStatus,
    required this.l10n,
    required this.onRefresh,
  });

  @override
  State<_TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<_TaskListTile> {
  bool _hovered = false;
  // ...existing _openDetail, _statusColor, build
}
```

All references to `task`, `isItExecutor`, `canChangeStatus`, `l10n`, `onRefresh` change from direct field access to `widget.task`, `widget.isItExecutor`, etc.

### Replace `AppCard` with accent card

Remove the `AppCard(variant: AppCardVariant.flat, ...)` wrapper. Replace the entire `build` return with:

```dart
@override
Widget build(BuildContext context) {
  final status = widget.task.status;
  final accent = _statusColor(status);
  final overdue = widget.task.dueDate != null &&
      widget.task.dueDate!.isBefore(DateTime.now()) &&
      status != WorkflowTaskStatus.approved;

  final body = Row(
    children: [
      // Title + meta
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.taskName,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Chip(label: status.label, color: accent),
                if (widget.task.assignedToUserName != null)
                  _Chip(
                    label: widget.task.assignedToUserName!,
                    color: AppColors.blue,
                    icon: Icons.person_outline,
                  ),
                if (widget.task.dueDate != null)
                  _Chip(
                    label: DateFormat('dd MMM yyyy')
                        .format(widget.task.dueDate!),
                    color: overdue ? AppColors.danger : AppColors.muted,
                    icon: Icons.calendar_today_outlined,
                  ),
                if (widget.task.estimatedFine != null)
                  _Chip(
                    label:
                        '₪${NumberFormat.compact().format(widget.task.estimatedFine)}',
                    color: AppColors.orange,
                    icon: Icons.account_balance_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
      // Chevron
      const Icon(Icons.chevron_right, color: AppColors.muted),
    ],
  );

  return MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    cursor: SystemMouseCursors.click,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3 px accent stripe
            Container(width: 3, color: accent),
            // Card body
            Expanded(
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () => _openDetail(context),
                  child: Padding(
                    padding: AppSpacing.listTilePadding,
                    child: body,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**Note:** `IntrinsicHeight` is required because `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` inside an unbounded-height context would otherwise throw `BoxConstraints forces an infinite height`. This is the same fix used in the Kanban card redesign.

The 10 × 10 status dot (`Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, ...))`) is **removed** — the 3 px left stripe carries the status colour signal.

### Remove `app_card.dart` import

```dart
// remove this line:
import '../../shared/widgets/app_card.dart';
```

---

## 2. Entrance Animations (flutter_animate)

Add import:

```dart
import 'package:flutter_animate/flutter_animate.dart';
```

### Tile stagger in `_buildSliver`

Inside the `SliverChildBuilderDelegate` callback in `_TaskListBody._buildSliver()`, wrap the `_TaskListTile` with an animation:

```dart
return Padding(
  padding: EdgeInsets.only(
    bottom: i < items.length - 1 ? 8 : 0,
  ),
  child: _TaskListTile(
    task: task,
    isItExecutor: isItExecutor,
    canChangeStatus: canChangeStatus,
    l10n: l10n,
    onRefresh: refresh,
  ).animate(delay: Duration(milliseconds: i * 40))
      .fadeIn(duration: 200.ms)
      .slideX(begin: -0.04, curve: Curves.easeOut),
);
```

`slideX` (from left) feels natural for a vertical list, matching the horizontal reading direction.

---

## 3. `withOpacity` → `withValues(alpha:)` Cleanup

### `_SectionHeader.build()`

```dart
// was:
color: accent.withOpacity(0.1),
// becomes:
color: accent.withValues(alpha: 0.1),
```

### `_Chip.build()`

```dart
// was:
color: color.withOpacity(0.1),
// becomes:
color: color.withValues(alpha: 0.1),
```

---

## Non-Changes

- All tap handlers (`_openDetail`, `TaskEditDialog`, `showDialog`) are unchanged.
- `_SessionBar` (session dropdown) is unchanged.
- Search box (`TextField`, `_searchCtrl`) is unchanged.
- Role / permission logic (`isItExecutor`, `canChangeStatus`, `canEditTasks`) is unchanged.
- `_SectionHeader` structure (icon, label, count badge, 3 px vertical bar) is unchanged — only the deprecated API call is fixed.
- `_TaskListBody` error and loading states are unchanged.
- No new providers, models, or routes.
- No new dependencies (`flutter_animate` already in `pubspec.yaml`).
