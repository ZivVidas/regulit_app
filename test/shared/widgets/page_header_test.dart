import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/page_header.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('PageHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(_wrap(
        const PageHeader(title: 'Dashboard'),
      ));
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const PageHeader(title: 'Dashboard', subtitle: 'System overview'),
      ));
      expect(find.text('System overview'), findsOneWidget);
    });

    testWidgets('subtitle absent when not provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const PageHeader(title: 'Dashboard'),
      ));
      expect(find.text('System overview'), findsNothing);
    });

    testWidgets('renders action widgets', (tester) async {
      await tester.pumpWidget(_wrap(
        PageHeader(
          title: 'Customers',
          actions: [
            ElevatedButton(onPressed: () {}, child: const Text('Add')),
          ],
        ),
      ));
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('gradient variant uses DecoratedBox with gradient', (tester) async {
      await tester.pumpWidget(_wrap(
        const PageHeader(
          title: 'Reports',
          variant: PageHeaderVariant.gradient,
        ),
      ));
      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasGradient = decorated.any((d) {
        final deco = d.decoration;
        return deco is BoxDecoration && deco.gradient != null;
      });
      expect(hasGradient, isTrue);
    });
  });
}
