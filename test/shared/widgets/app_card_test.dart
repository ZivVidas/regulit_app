import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/app_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('AppCard', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppCard(child: Text('hello')),
      ));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(
        AppCard(onTap: () => called = true, child: const Text('tap')),
      ));
      await tester.tap(find.text('tap'));
      expect(called, isTrue);
    });

    testWidgets('elevated variant has boxShadow', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppCard(
          variant: AppCardVariant.elevated,
          child: Text('x'),
        ),
      ));
      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasShadow = decorated.any((d) {
        final deco = d.decoration;
        return deco is BoxDecoration && (deco.boxShadow?.isNotEmpty ?? false);
      });
      expect(hasShadow, isTrue);
    });

    testWidgets('flat variant has no shadow', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppCard(
          variant: AppCardVariant.flat,
          child: Text('x'),
        ),
      ));
      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasShadow = decorated.any((d) {
        final deco = d.decoration;
        return deco is BoxDecoration && (deco.boxShadow?.isNotEmpty ?? false);
      });
      expect(hasShadow, isFalse);
    });

    testWidgets('renders header and footer when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppCard(
          header: Text('HEADER'),
          footer: Text('FOOTER'),
          child: Text('BODY'),
        ),
      ));
      expect(find.text('HEADER'), findsOneWidget);
      expect(find.text('BODY'), findsOneWidget);
      expect(find.text('FOOTER'), findsOneWidget);
    });
  });
}
