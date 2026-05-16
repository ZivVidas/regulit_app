# Task List Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate `task_list_screen.dart` to match the app's premium SaaS visual language — elevated 3 px left-accent task tiles, stagger entrance animations, and `withValues(alpha:)` API cleanup — without changing any screen behaviour, data flow, or tap logic.

**Architecture:** All changes live in a single file (`lib/features/tasks/task_list_screen.dart`). `_TaskListTile` converts from `StatelessWidget` to `StatefulWidget` to hold a `_hovered` bool. The card body follows the same `AnimatedContainer` + `Clip.antiAlias` + `IntrinsicHeight` + 3 px stripe + `Material > InkWell` pattern used in the Kanban board redesign. `flutter_animate` is already in `pubspec.yaml`; no new dependencies are added.

**Tech Stack:** Flutter 3, Dart, Riverpod 2 (`AutoDisposeProvider`, `StateNotifierProvider`), Dio (HTTP), flutter_animate

---

### Task 1: Elevated left-accent card for `_TaskListTile`

**Files:**
- Modify: `lib/features/tasks/task_list_screen.dart` (lines 22, 559–687)
- Create: `test/features/tasks/task_list_screen_test.dart`

---

- [ ] **Step 1: Create the test file with helper infrastructure**

Create `test/features/tasks/task_list_screen_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/core/api/api_client.dart';
import 'package:regulit_app/core/auth/auth_provider.dart';
import 'package:regulit_app/core/customer/customer_context_provider.dart';
import 'package:regulit_app/features/tasks/task_list_screen.dart';
import 'package:regulit_app/l10n/app_localizations.dart';

// ── Fake HTTP adapter ─────────────────────────────────────────────────────────
// Intercepts Dio requests before any network call.
// Paths containing 'active-sessions' → returns the sessions JSON array.
// All other paths → returns the tasks JSON object.

class _FakeAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> tasks;

  const _FakeAdapter({required this.sessions, required this.tasks});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.contains('active-sessions')) {
      return ResponseBody.fromString(
        jsonEncode(sessions),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'items': tasks}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _sessionJson() => {
      'id': 'session-1',
      'workflowName': 'ISO 27001 Compliance',
    };

Map<String, dynamic> _taskJson({
  String id = 'task-1',
  String taskName = 'GDPR data mapping audit',
  int statusId = 2, // 2 = inProgress
}) =>
    {
      'id': id,
      'workflowId': 'wf-1',
      'workflowAnswerId': 'session-1',
      'taskName': taskName,
      'whatToDo': null,
      'statusId': statusId,
      'statusDescription': null,
      'dueDate': null,
      'assignedToUserId': 'user-99',
      'assignedToUserName': 'Yael Cohen',
      'estimatedFine': null,
      'isRequired': false,
      'risk': null,
      'category': null,
      'createdAt': '2026-01-01T00:00:00Z',
      'modifiedAt': '2026-01-01T00:00:00Z',
      'evidenceCount': 0,
    };

// ── Wrapper ───────────────────────────────────────────────────────────────────

Widget _wrapList({List<Map<String, dynamic>>? tasks}) {
  // baseUrl is required so Dio can build a valid URI; the adapter intercepts
  // before any actual network call is made.
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = _FakeAdapter(
      sessions: [_sessionJson()],
      tasks: tasks ?? [_taskJson()],
    );

  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      customerContextProvider.overrideWith((ref) {
        final n = CustomerContextNotifier(ref);
        n.state = {'customerId': 'customer-1', 'role': 'it_executor'};
        return n;
      }),
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
      home: const TaskListScreen(),
    ),
  );
}

void main() {
  // tests added in subsequent steps
}
```

- [ ] **Step 2: Run the empty test file to confirm infrastructure compiles**

```
flutter test test/features/tasks/task_list_screen_test.dart
```
Expected: `All tests passed!` (no tests yet — just verifies imports compile).

- [ ] **Step 3: Write the failing tests**

Replace `void main() { }` with:

```dart
void main() {
  group('TaskListScreen tile card', () {
    testWidgets('renders the task name', (tester) async {
      await tester.pumpWidget(_wrapList());
      await tester.pumpAndSettle();
      expect(find.text('GDPR data mapping audit'), findsOneWidget);
    });

    testWidgets('tile has no AppCard — replaced with elevated accent card',
        (tester) async {
      await tester.pumpWidget(_wrapList());
      await tester.pumpAndSettle();
      expect(find.byType(AppCard), findsNothing);
    });

    testWidgets('tile wraps in MouseRegion for hover support', (tester) async {
      await tester.pumpWidget(_wrapList());
      await tester.pumpAndSettle();
      expect(find.byType(MouseRegion), findsWidgets);
    });
  });
}
```

- [ ] **Step 4: Run tests and verify 2 fail**

```
flutter test test/features/tasks/task_list_screen_test.dart
```
Expected:
- `renders the task name` → PASS (text is there before and after)
- `tile has no AppCard` → **FAIL** (`AppCard` is still present)
- `tile wraps in MouseRegion` → **FAIL** (no `MouseRegion` yet)

- [ ] **Step 5: Remove the `app_card.dart` import**

In `lib/features/tasks/task_list_screen.dart`, delete line 22:

```dart
// DELETE:
import '../../shared/widgets/app_card.dart';
```

- [ ] **Step 6: Replace the `_TaskListTile` class**

In `lib/features/tasks/task_list_screen.dart`, delete the block from the comment
`// Task tile` through the closing `}` of `_TaskListTile` (roughly lines 555–687 after the import deletion).
Replace it entirely with:

```dart
// ─────────────────────────────────────────────────────────────
// Task tile
// ─────────────────────────────────────────────────────────────

class _TaskListTile extends StatefulWidget {
  final WorkflowTask task;
  /// True when current user is it_executor — tap opens full edit dialog.
  final bool isItExecutor;
  /// True when current user may change this task's status.
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

  @override
  Widget build(BuildContext context) {
    final status = widget.task.status;
    final accent = _statusColor(status);
    final overdue = widget.task.dueDate != null &&
        widget.task.dueDate!.isBefore(DateTime.now()) &&
        status != WorkflowTaskStatus.approved;

    final body = Row(
      children: [
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
              // 3 px accent stripe — status colour
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

  void _openDetail(BuildContext context) {
    if (widget.isItExecutor) {
      showDialog<bool>(
        context: context,
        builder: (_) => TaskEditDialog(task: widget.task, l10n: widget.l10n),
      ).then((refreshed) {
        if (refreshed == true) widget.onRefresh();
      });
    } else {
      showDialog<bool>(
        context: context,
        builder: (_) => TaskEditDialog(
          task: widget.task,
          l10n: widget.l10n,
          readOnly: true,
          canChangeStatus: widget.canChangeStatus,
          canUploadEvidence: widget.canChangeStatus,
          onStatusChanged: widget.onRefresh,
        ),
      ).then((refreshed) {
        if (refreshed == true) widget.onRefresh();
      });
    }
  }

  static Color _statusColor(WorkflowTaskStatus s) => switch (s) {
        WorkflowTaskStatus.todo          => AppColors.muted,
        WorkflowTaskStatus.inProgress    => AppColors.warning,
        WorkflowTaskStatus.pendingReview => AppColors.orange,
        WorkflowTaskStatus.approved      => AppColors.success,
        WorkflowTaskStatus.overdue       => AppColors.danger,
      };
}
```

> **Note on `IntrinsicHeight`:** `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` inside an unbounded-height parent throws `BoxConstraints forces an infinite height` in Flutter. Wrapping with `IntrinsicHeight` forces the row to measure its children's intrinsic heights first, resolving the constraint. This is the same fix used in the Kanban board redesign.

- [ ] **Step 7: Run tests and verify all pass**

```
flutter test test/features/tasks/task_list_screen_test.dart
```
Expected: All 3 tests PASS.

- [ ] **Step 8: Run full suite to catch regressions**

```
flutter test
```
Expected: All tests passed!

- [ ] **Step 9: Commit**

```bash
git add lib/features/tasks/task_list_screen.dart \
        test/features/tasks/task_list_screen_test.dart
git commit -m "feat: elevated left-accent card for task list tiles"
```

---

### Task 2: Stagger entrance animations

**Files:**
- Modify: `lib/features/tasks/task_list_screen.dart` (add import, wrap tiles in `_buildSliver`)

---

- [ ] **Step 1: Write a failing test**

Add this group to `void main()` in `test/features/tasks/task_list_screen_test.dart` (after the existing group):

```dart
group('TaskListScreen animations', () {
  testWidgets('multiple tiles all render after settle', (tester) async {
    await tester.pumpWidget(_wrapList(
      tasks: [
        _taskJson(),
        _taskJson(id: 'task-2', taskName: 'Vendor risk assessment'),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('GDPR data mapping audit'), findsOneWidget);
    expect(find.text('Vendor risk assessment'), findsOneWidget);
  });
});
```

This test is a regression guard: it verifies that adding the stagger animation does not hide or drop tiles after settling.

- [ ] **Step 2: Run to confirm it passes before implementation too**

```
flutter test test/features/tasks/task_list_screen_test.dart
```
Expected: All 4 tests PASS. (This test starts green — it guards against regressions, not a red-green cycle.)

- [ ] **Step 3: Add the `flutter_animate` import**

In `lib/features/tasks/task_list_screen.dart`, add after the existing imports (e.g., after line 12 `import 'package:gap/gap.dart';`):

```dart
import 'package:flutter_animate/flutter_animate.dart';
```

- [ ] **Step 4: Wrap each tile with `.animate()` in `_buildSliver`**

In `_TaskListBody.build()`, find the local function `_buildSliver` (around line 424). Its `SliverChildBuilderDelegate` callback currently returns a `Padding` containing `_TaskListTile(...)`.

Replace the `return Padding(...)` block with:

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

- [ ] **Step 5: Run all tests**

```
flutter test
```
Expected: All tests passed!

- [ ] **Step 6: Commit**

```bash
git add lib/features/tasks/task_list_screen.dart \
        test/features/tasks/task_list_screen_test.dart
git commit -m "feat: stagger entrance animations on task list tiles"
```

---

### Task 3: `withOpacity` → `withValues(alpha:)` cleanup

**Files:**
- Modify: `lib/features/tasks/task_list_screen.dart` (`_SectionHeader` and `_Chip`)

---

- [ ] **Step 1: Fix `_SectionHeader`**

In `lib/features/tasks/task_list_screen.dart`, find `_SectionHeader.build()`. The count badge decoration uses `withOpacity`:

```dart
// FIND (around line 537):
color: accent.withOpacity(0.1),

// REPLACE WITH:
color: accent.withValues(alpha: 0.1),
```

- [ ] **Step 2: Fix `_Chip`**

In the same file, find `_Chip.build()`. The background decoration uses `withOpacity`:

```dart
// FIND (around line 704):
color: color.withOpacity(0.1),

// REPLACE WITH:
color: color.withValues(alpha: 0.1),
```

- [ ] **Step 3: Run full test suite**

```
flutter test
```
Expected: All tests passed!

- [ ] **Step 4: Commit**

```bash
git add lib/features/tasks/task_list_screen.dart
git commit -m "fix: withOpacity → withValues(alpha:) in task list chips and section header"
```
