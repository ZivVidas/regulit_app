# Kanban Board Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate the Kanban board visually — gradient column headers, 3 px left-accent task cards, outlined metric tiles, and staggered entrance animations — touching `theme.dart` and `task_board_screen.dart` only with zero behavioural changes.

**Architecture:** Purely presentational — no providers, models, routes, or drag logic change. `_KanbanCol` loses two Color params and gains one LinearGradient. `_TaskCard` replaces an `AppCard` wrapper with a manual `AnimatedContainer`+`Row` for left-border support. `flutter_animate` (already a dep) wraps columns and cards for stagger effects.

**Tech Stack:** Flutter 3, flutter_animate, Riverpod 2 (test overrides only), mocktail (tests)

---

## File Map

| File | Change |
|---|---|
| `lib/app/theme.dart` | Add `AppGradients.neutralHeader` |
| `lib/features/tasks/task_board_screen.dart` | Remove `headerColor`/`headerBg`, add `gradient` to `_KanbanCol`; replace `AppCard` in `_TaskCard`; polish `_MetricTile`; add flutter_animate stagger |
| `test/features/tasks/task_board_screen_test.dart` | New — smoke tests verifying board renders after each change |

---

### Task 1: Add `AppGradients.neutralHeader` to theme.dart

**Files:**
- Modify: `lib/app/theme.dart`
- Test: `test/app/theme_test.dart`

The To Do column needs a neutral grey gradient. All other column gradients already exist in `AppGradients`. This task adds the missing one.

- [ ] **Step 1: Write the failing test**

Create `test/app/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';

void main() {
  group('AppGradients.neutralHeader', () {
    test('is a LinearGradient with the correct two grey colors', () {
      expect(AppGradients.neutralHeader, isA<LinearGradient>());
      expect(AppGradients.neutralHeader.colors.length, 2);
      expect(AppGradients.neutralHeader.colors[0], const Color(0xFF8A8886));
      expect(AppGradients.neutralHeader.colors[1], const Color(0xFF605E5C));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/app/theme_test.dart
```

Expected: FAIL — `getter 'neutralHeader' isn't defined`

- [ ] **Step 3: Add the gradient constant**

In `lib/app/theme.dart`, inside `abstract class AppGradients`, add after the `primaryHeader` entry:

```dart
  static const LinearGradient neutralHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8A8886), Color(0xFF605E5C)],
  );
```

- [ ] **Step 4: Run test to verify it passes**

```
flutter test test/app/theme_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```
git add lib/app/theme.dart test/app/theme_test.dart
git commit -m "feat: add AppGradients.neutralHeader for kanban To Do column"
```

---

### Task 2: Gradient column headers (`_KanbanCol` refactor)

**Files:**
- Modify: `lib/features/tasks/task_board_screen.dart`
- Test: `test/features/tasks/task_board_screen_test.dart` (create)

This task replaces the flat `headerColor`/`headerBg` pair on `_KanbanCol` with a single `LinearGradient`, rebuilds the header `Container` to use that gradient with white text, and removes the `SectionHeader` usage.

**Understand the current structure first:**  
Open `lib/features/tasks/task_board_screen.dart` and find `class _KanbanCol extends StatefulWidget` (~line 782). The widget has fields `headerColor` and `headerBg` and a `SectionHeader` call inside `_KanbanColState.build()`. You'll be removing those two fields and the `SectionHeader` widget, and replacing with a `gradient` field.

- [ ] **Step 1: Create the smoke test file**

Create `test/features/tasks/task_board_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/core/auth/auth_provider.dart';
import 'package:regulit_app/core/customer/customer_context_provider.dart';
import 'package:regulit_app/core/models/workflow_task.dart';
import 'package:regulit_app/features/tasks/task_board_screen.dart';
import 'package:regulit_app/l10n/app_localizations.dart';

// ── Minimal WorkflowTask factory for tests ────────────────────────────────────
WorkflowTask _task({
  String id = 'task-1',
  String name = 'Test Task',
  int statusId = 1, // 1=todo
}) =>
    WorkflowTask(
      id: id,
      workflowId: 'wf-1',
      taskName: name,
      statusId: statusId,
      isRequired: false,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 1),
    );

// ── Minimal ActiveSession factory for tests ───────────────────────────────────
ActiveSession _session() => const ActiveSession(
      id: 'session-1',
      workflowId: 'wf-1',
      workflowName: 'Test Workflow',
    );

Widget _wrapBoard({List<WorkflowTask>? tasks}) {
  return ProviderScope(
    overrides: [
      // customerContextProvider is StateNotifierProvider<CustomerContextNotifier, ...>.
      // state setter is @visibleForTesting so it is valid to call from test files.
      customerContextProvider.overrideWith((ref) {
        final n = CustomerContextNotifier(ref);
        n.state = {'customerId': 'customer-1', 'role': 'employee'};
        return n;
      }),
      activeSessionsProvider.overrideWith(
        (ref, customerId) async => [_session()],
      ),
      sessionTasksProvider.overrideWith(
        (ref, sessionId) async => tasks ?? [_task()],
      ),
      isItExecutorProvider.overrideWithValue(false),
      currentUserProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const TaskBoardScreen(),
    ),
  );
}

void main() {
  group('TaskBoardScreen smoke', () {
    testWidgets('renders without throwing and shows column headers',
        (tester) async {
      await tester.pumpWidget(_wrapBoard());
      await tester.pumpAndSettle();

      // Session bar + page header visible
      expect(find.text('Test Workflow'), findsOneWidget);
      // Column headers visible (text comes from l10n)
      expect(find.textContaining('TO DO'), findsOneWidget);
      expect(find.textContaining('IN PROGRESS'), findsOneWidget);
      expect(find.textContaining('DONE'), findsOneWidget);
    });

    testWidgets('renders task card with task name', (tester) async {
      await tester.pumpWidget(_wrapBoard());
      await tester.pumpAndSettle();

      expect(find.text('Test Task'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the smoke test — it should PASS (current code, baseline)**

```
flutter test test/features/tasks/task_board_screen_test.dart
```

Expected: PASS (establishes baseline before any changes)

- [ ] **Step 3: Remove `headerColor`/`headerBg` fields; add `gradient` to `_KanbanCol`**

In `lib/features/tasks/task_board_screen.dart`, find `class _KanbanCol extends StatefulWidget`. Replace the two color fields and constructor params:

```dart
// REMOVE these two lines from the field declarations:
//   final Color headerColor;
//   final Color headerBg;

// ADD this field instead:
final LinearGradient gradient;
```

In the `const _KanbanCol({...})` constructor, remove `required this.headerColor,` and `required this.headerBg,`, then add `required this.gradient,`.

Also remove the import at the top of the file:
```dart
// REMOVE:
import '../../shared/widgets/section_header.dart';
```

- [ ] **Step 4: Update `_KanbanColState.build()` — column outer decoration**

Find the `AnimatedContainer` inside `_KanbanColState.build()`. Its current `decoration` uses `widget.headerColor`. Replace:

```dart
// OLD:
decoration: BoxDecoration(
  color: isHovering
      ? widget.headerColor.withOpacity(0.06)
      : AppColors.surface,
  borderRadius: BorderRadius.circular(10),
  border: Border.all(
    color: isHovering
        ? widget.headerColor.withOpacity(0.65)
        : widget.headerColor.withOpacity(0.3),
    width: isHovering ? 2 : 1,
  ),
),

// NEW:
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

- [ ] **Step 5: Replace the header `Container` + `SectionHeader` with gradient header**

Find the header `Container` (it has `padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9)` and `SectionHeader` inside). Replace the entire `Container(...)` block with:

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
        const Padding(
          padding: EdgeInsets.only(right: 6),
          child: Icon(
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

- [ ] **Step 6: Update `_KanbanBoard.build()` callsites — swap params**

Find the 5 `_KanbanCol(...)` calls in `_KanbanBoard.build()`. Remove `headerColor:` and `headerBg:` from each and add `gradient:` with the correct value:

```dart
// To Do
_KanbanCol(
  title: l10n.taskToDo,
  status: WorkflowTaskStatus.todo,
  tasks: todo,
  gradient: AppGradients.neutralHeader,   // ← new
  l10n: l10n,
  isItExecutor: isItExecutor,
  currentUserId: currentUserId,
  onStatusChange: onStatusChange,
  onTaskTap: onTaskTap,
),

// In Progress
_KanbanCol(
  title: l10n.taskInProgress,
  status: WorkflowTaskStatus.inProgress,
  tasks: inProgress,
  gradient: AppGradients.warningHeader,   // ← new
  l10n: l10n,
  isItExecutor: isItExecutor,
  currentUserId: currentUserId,
  onStatusChange: onStatusChange,
  onTaskTap: onTaskTap,
),

// Pending Review
_KanbanCol(
  title: l10n.taskPendingReview,
  status: WorkflowTaskStatus.pendingReview,
  tasks: pendingReview,
  gradient: AppGradients.secondaryHeader, // ← new
  l10n: l10n,
  isItExecutor: isItExecutor,
  currentUserId: currentUserId,
  onStatusChange: onStatusChange,
  onTaskTap: onTaskTap,
),

// Done
_KanbanCol(
  title: l10n.taskDone,
  status: WorkflowTaskStatus.approved,
  tasks: done,
  gradient: AppGradients.successHeader,   // ← new
  dimmed: true,
  l10n: l10n,
  isItExecutor: isItExecutor,
  currentUserId: currentUserId,
  onStatusChange: onStatusChange,
  onTaskTap: onTaskTap,
),

// Overdue
_KanbanCol(
  title: l10n.taskOverdue,
  status: WorkflowTaskStatus.overdue,
  tasks: overdue,
  gradient: AppGradients.dangerHeader,    // ← new
  l10n: l10n,
  isItExecutor: isItExecutor,
  currentUserId: currentUserId,
  onStatusChange: onStatusChange,
  onTaskTap: onTaskTap,
),
```

- [ ] **Step 7: Run tests and static analysis**

```
flutter analyze lib/features/tasks/task_board_screen.dart lib/app/theme.dart
flutter test test/features/tasks/task_board_screen_test.dart
```

Expected: no analysis errors, tests PASS

- [ ] **Step 8: Commit**

```
git add lib/app/theme.dart lib/features/tasks/task_board_screen.dart test/features/tasks/task_board_screen_test.dart
git commit -m "feat: gradient column headers on kanban board"
```

---

### Task 3: Left-accent task cards + Done column opacity

**Files:**
- Modify: `lib/features/tasks/task_board_screen.dart`

Replace the `AppCard` wrapper in `_TaskCard._buildCard()` with a manual `AnimatedContainer` + `Row` that allows a 3 px left accent stripe. Add `Opacity` wrapping for the Done column's `dimmed` state (currently tracked but never applied visually).

**Why not use `AppCard`:** Flutter's `BoxDecoration` does not allow non-uniform `border` (e.g. left-only) combined with `borderRadius`. The accent stripe is implemented as a literal 3 px wide `Container` as the first child of a `Row` inside a clipped container.

- [ ] **Step 1: Add a failing test for Done opacity**

Add to `test/features/tasks/task_board_screen_test.dart`, inside `main()`:

```dart
testWidgets('done column task renders at reduced opacity', (tester) async {
  // Put a task in the Done (approved, statusId=4) column
  await tester.pumpWidget(
    _wrapBoard(tasks: [_task(statusId: 4, name: 'Done Task')]),
  );
  await tester.pumpAndSettle();

  // The 'Done Task' card must exist
  expect(find.text('Done Task'), findsOneWidget);

  // The card must be inside an Opacity widget with opacity < 1.0
  final opacityFinder = find.ancestor(
    of: find.text('Done Task'),
    matching: find.byType(Opacity),
  );
  final opacityWidget = tester.widget<Opacity>(opacityFinder.first);
  expect(opacityWidget.opacity, lessThan(1.0));
});
```

- [ ] **Step 2: Run the failing test**

```
flutter test test/features/tasks/task_board_screen_test.dart --name "done column"
```

Expected: FAIL — `Expected: a value less than <1.0>` (no Opacity widget currently)

- [ ] **Step 3: Replace `AppCard` in `_TaskCard._buildCard()`**

In `lib/features/tasks/task_board_screen.dart`, find `_TaskCard._buildCard({bool dragging = false})`. 

The method currently opens with `return MouseRegion(...)`. Replace the entire return statement with the following. The card body `Column` (everything that was inside `AppCard(child: Column(...))`) is unchanged — only the wrapper changes:

```dart
Widget _buildCard({bool dragging = false}) {
  final task = widget.task;
  final isOverdue = task.status == WorkflowTaskStatus.overdue;

  // Card body — unchanged content
  final body = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              task.taskName.isEmpty ? widget.l10n.noTaskName : task.taskName,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.canDrag) ...[
            const Gap(4),
            Tooltip(
              message: widget.l10n.dragToChangeStatus,
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 15,
                color: _hovered
                    ? _accent
                    : AppColors.muted.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
      if (task.whatToDo != null && task.whatToDo!.isNotEmpty) ...[
        const Gap(4),
        Text(
          task.whatToDo!,
          style: AppTextStyles.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      if (task.risk != null && task.risk!.isNotEmpty) ...[
        const Gap(4),
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 11, color: AppColors.orange),
            const Gap(3),
            Expanded(
              child: Text(
                task.risk!,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.orange, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
      const Gap(8),
      if (task.dueDate != null)
        Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 11,
                color: isOverdue ? AppColors.danger : AppColors.muted),
            const Gap(3),
            Expanded(
              child: Text(
                '${widget.l10n.taskDueLabel} ${_fmtDate(task.dueDate!)}',
                style: AppTextStyles.caption.copyWith(
                  color: isOverdue ? AppColors.danger : AppColors.muted,
                  fontWeight:
                      isOverdue ? FontWeight.w700 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      if (task.assignedToUserName != null &&
          task.assignedToUserName!.isNotEmpty) ...[
        const Gap(4),
        Row(
          children: [
            const Icon(Icons.person_outline,
                size: 11, color: AppColors.muted),
            const Gap(3),
            Expanded(
              child: Text(
                task.assignedToUserName!,
                style: AppTextStyles.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
      const Gap(6),
      Row(
        children: [
          if (task.isRequired)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.l10n.taskRequired,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.danger, fontSize: 9),
              ),
            ),
          const Spacer(),
          if (task.evidenceCount > 0) ...[
            Icon(Icons.attach_file_rounded,
                size: 11, color: AppColors.muted),
            Text('${task.evidenceCount}', style: AppTextStyles.caption),
          ],
          if (_hovered && widget.onTap != null && !widget.canDrag)
            Icon(Icons.edit_outlined,
                size: 11, color: _accent.withValues(alpha: 0.7)),
        ],
      ),
    ],
  );

  return Opacity(
    opacity: widget.dimmed ? 0.72 : 1.0,
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.canDrag
          ? SystemMouseCursors.grab
          : SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: AnimatedContainer(
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
              Container(width: 3, color: _accent),
              Expanded(
                child: widget.onTap != null
                    ? Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: dragging ? null : widget.onTap,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: body,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: body,
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Remove the `app_card.dart` import**

At the top of `task_board_screen.dart`, delete:
```dart
import '../../shared/widgets/app_card.dart';
```

- [ ] **Step 5: Run all task board tests**

```
flutter test test/features/tasks/task_board_screen_test.dart
flutter analyze lib/features/tasks/task_board_screen.dart
```

Expected: all 3 tests PASS, no analysis errors

- [ ] **Step 6: Commit**

```
git add lib/features/tasks/task_board_screen.dart test/features/tasks/task_board_screen_test.dart
git commit -m "feat: 3px left-accent border on task cards, opacity for done column"
```

---

### Task 4: Metric tile outlined box

**Files:**
- Modify: `lib/features/tasks/task_board_screen.dart`

Small targeted change: enlarge `_MetricTile`'s inner box from 36×36 to 38×38 and add a 1.5 px coloured border outline.

- [ ] **Step 1: Locate `_MetricTile.build()`**

Find class `_MetricTile` in `task_board_screen.dart`. The inner box is a `Container` with `width: 36, height: 36`.

- [ ] **Step 2: Replace the inner Container**

```dart
// OLD:
Container(
  width: 36,
  height: 36,
  alignment: Alignment.center,
  decoration: BoxDecoration(
      color: bgColor, borderRadius: BorderRadius.circular(8)),
  child: Text('$value',
      style: AppTextStyles.h3.copyWith(color: color)),
),

// NEW:
Container(
  width: 38,
  height: 38,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: bgColor,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: color.withValues(alpha: 0.40),
      width: 1.5,
    ),
  ),
  child: Text('$value',
      style: AppTextStyles.h3.copyWith(color: color)),
),
```

- [ ] **Step 3: Run tests**

```
flutter test test/features/tasks/task_board_screen_test.dart
flutter analyze lib/features/tasks/task_board_screen.dart
```

Expected: PASS

- [ ] **Step 4: Commit**

```
git add lib/features/tasks/task_board_screen.dart
git commit -m "feat: outlined metric tiles on kanban board (38px with border)"
```

---

### Task 5: Entrance animations + final cleanup

**Files:**
- Modify: `lib/features/tasks/task_board_screen.dart`

Add `flutter_animate` import and stagger-fadeIn animations to columns (0–200 ms) and cards (0–120 ms per column). Then verify no unused imports remain.

- [ ] **Step 1: Add the `flutter_animate` import**

At the top of `lib/features/tasks/task_board_screen.dart`, add after the existing Flutter imports:

```dart
import 'package:flutter_animate/flutter_animate.dart';
```

- [ ] **Step 2: Animate columns in `_KanbanBoard.build()`**

Find the 5 `_KanbanCol(...)` calls inside `_KanbanBoard.build()`. Chain `.animate().fadeIn().slideY()` onto each, with increasing `delay`. The `Gap` widgets between columns are unchanged.

```dart
// To Do (delay 0)
_KanbanCol(
  title: l10n.taskToDo,
  ...
).animate(delay: 0.ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.05, curve: Curves.easeOut),

// In Progress (delay 50)
_KanbanCol(
  title: l10n.taskInProgress,
  ...
).animate(delay: 50.ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.05, curve: Curves.easeOut),

// Pending Review (delay 100)
_KanbanCol(
  title: l10n.taskPendingReview,
  ...
).animate(delay: 100.ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.05, curve: Curves.easeOut),

// Done (delay 150)
_KanbanCol(
  title: l10n.taskDone,
  ...
).animate(delay: 150.ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.05, curve: Curves.easeOut),

// Overdue (delay 200)
_KanbanCol(
  title: l10n.taskOverdue,
  ...
).animate(delay: 200.ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.05, curve: Curves.easeOut),
```

- [ ] **Step 3: Animate cards in `_KanbanColState.build()`**

Find the `for` loop inside `_KanbanColState.build()` that builds the card list:

```dart
for (int i = 0; i < widget.tasks.length; i++) ...[
  _TaskCard(
    task: widget.tasks[i],
    dimmed: widget.dimmed,
    l10n: widget.l10n,
    canDrag: _canDrag(widget.tasks[i]),
    onTap: widget.onTaskTap == null
        ? null
        : () => widget.onTaskTap!(widget.tasks[i]),
  ),
  if (i < widget.tasks.length - 1) const Gap(6),
],
```

Replace with:

```dart
for (int i = 0; i < widget.tasks.length; i++) ...[
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
  if (i < widget.tasks.length - 1) const Gap(6),
],
```

- [ ] **Step 4: Run analyzer to confirm no unused imports**

```
flutter analyze lib/features/tasks/task_board_screen.dart
```

Expected: 0 errors, 0 warnings. If `app_card.dart` or `section_header.dart` import warnings appear (should have been removed in Tasks 2 and 3 — remove them now if not already done).

- [ ] **Step 5: Run all tests**

```
flutter test test/features/tasks/task_board_screen_test.dart
flutter test test/app/theme_test.dart
```

Expected: all tests PASS

- [ ] **Step 6: Commit**

```
git add lib/features/tasks/task_board_screen.dart
git commit -m "feat: stagger entrance animations on kanban columns and cards"
```
