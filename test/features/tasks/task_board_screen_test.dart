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
        n.state = {'customerId': 'customer-1', 'role': 'it_executor'};
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
  });
}
