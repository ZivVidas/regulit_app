import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/section_header.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  group('SectionHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Overview')));
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const SectionHeader(title: 'Overview', subtitle: 'Last 30 days'),
      ));
      expect(find.text('Last 30 days'), findsOneWidget);
    });

    testWidgets('subtitle absent when not provided', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Overview')));
      expect(find.text('Last 30 days'), findsNothing);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        SectionHeader(
          title: 'Risks',
          trailing: TextButton(onPressed: () {}, child: const Text('See all')),
        ),
      ));
      expect(find.text('See all'), findsOneWidget);
    });
  });
}
