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
        MetricCard(label: 'Tasks', value: '10', onTap: () => tapped = true),
      ));
      await tester.tap(find.text('10'));
      expect(tapped, isTrue);
    });

    testWidgets('renders trend label when trend provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(
          label: 'Tasks',
          value: '10',
          trend: MetricTrend(direction: TrendDirection.up, label: '+3 this week'),
        ),
      ));
      expect(find.text('+3 this week'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Users', value: '42', icon: Icons.people),
      ));
      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('sub text hidden when trend is provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(
          label: 'Score',
          value: '84%',
          sub: 'hidden text',
          trend: MetricTrend(direction: TrendDirection.flat, label: 'no change'),
        ),
      ));
      expect(find.text('hidden text'), findsNothing);
      expect(find.text('no change'), findsOneWidget);
    });

    testWidgets('renders all MetricVariant values without error', (tester) async {
      for (final variant in MetricVariant.values) {
        await tester.pumpWidget(_wrap(
          MetricCard(label: 'Test', value: '42', variant: variant),
        ));
        expect(find.text('TEST'), findsOneWidget, reason: 'variant=$variant');
        expect(find.text('42'), findsOneWidget, reason: 'variant=$variant');
      }
    });

    testWidgets('tappable card uses Ink with non-null gradient', (tester) async {
      await tester.pumpWidget(_wrap(
        MetricCard(label: 'Score', value: '84%', onTap: () {}),
      ));
      final ink = tester.widget<Ink>(find.byType(Ink).first);
      final decoration = ink.decoration as BoxDecoration;
      expect(decoration.gradient, isNotNull);
    });

    testWidgets('glow orb is wrapped in IgnorePointer', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Score', value: '84%'),
      ));
      expect(find.byType(IgnorePointer), findsAtLeastNWidgets(1));
    });

    testWidgets('non-tappable card has DecoratedBox with gradient', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Score', value: '84%'),
      ));
      final allBoxes =
          tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      final hasGradient = allBoxes.any((b) {
        final d = b.decoration;
        return d is BoxDecoration && d.gradient != null;
      });
      expect(hasGradient, isTrue);
    });
  });
}
