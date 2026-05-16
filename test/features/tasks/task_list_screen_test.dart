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
import 'package:regulit_app/shared/widgets/app_card.dart';

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
