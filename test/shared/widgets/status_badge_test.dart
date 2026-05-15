import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/core/models/gap.dart';
import 'package:regulit_app/core/models/task.dart';
import 'package:regulit_app/core/models/user.dart';
import 'package:regulit_app/shared/widgets/status_badge.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('StatusBadge', () {
    testWidgets('gapStatus.open renders Open label', (tester) async {
      await tester.pumpWidget(_wrap(StatusBadge.gapStatus(GapStatus.open)));
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('taskStatus.overdue renders Overdue label', (tester) async {
      await tester.pumpWidget(_wrap(
        StatusBadge.taskStatus(TaskStatus.overdue),
      ));
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('severity.critical renders Critical label', (tester) async {
      await tester.pumpWidget(_wrap(
        StatusBadge.severity(GapSeverity.critical),
      ));
      expect(find.text('Critical'), findsOneWidget);
    });

    testWidgets('tier.enterprise renders Enterprise label', (tester) async {
      await tester.pumpWidget(_wrap(
        StatusBadge.tier(CustomerTier.enterprise),
      ));
      expect(find.text('Enterprise'), findsOneWidget);
    });

    testWidgets('tier.starter renders Starter label', (tester) async {
      await tester.pumpWidget(_wrap(
        StatusBadge.tier(CustomerTier.starter),
      ));
      expect(find.text('Starter'), findsOneWidget);
    });
  });
}
