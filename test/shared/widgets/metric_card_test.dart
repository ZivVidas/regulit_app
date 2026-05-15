import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/metric_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('MetricCard', () {
    testWidgets('renders label uppercase and value', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Open Gaps', value: '24'),
      ));
      expect(find.text('OPEN GAPS'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
    });

    testWidgets('renders sub text when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Score', value: '82%', sub: '3 new'),
      ));
      expect(find.text('3 new'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        MetricCard(
            label: 'Tasks', value: '10', onTap: () => tapped = true),
      ));
      await tester.tap(find.text('10'));
      expect(tapped, isTrue);
    });

    testWidgets('renders trend label when trend provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(
          label: 'Tasks',
          value: '10',
          trend: MetricTrend(
            direction: TrendDirection.up,
            label: '+3 this week',
          ),
        ),
      ));
      expect(find.text('+3 this week'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(
          label: 'Users',
          value: '42',
          icon: Icons.people,
        ),
      ));
      expect(find.byIcon(Icons.people), findsOneWidget);
    });
  });
}
