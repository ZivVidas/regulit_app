import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/empty_state.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('EmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(icon: Icons.inbox, title: 'No items found'),
      ));
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          icon: Icons.search_off,
          title: 'No results',
          description: 'Try adjusting your filters',
        ),
      ));
      expect(find.text('Try adjusting your filters'), findsOneWidget);
    });

    testWidgets('renders action when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        EmptyState(
          icon: Icons.add,
          title: 'No customers',
          action:
              ElevatedButton(onPressed: () {}, child: const Text('Add Customer')),
        ),
      ));
      expect(find.text('Add Customer'), findsOneWidget);
    });

    testWidgets('action absent when not provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(icon: Icons.inbox, title: 'Empty'),
      ));
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
