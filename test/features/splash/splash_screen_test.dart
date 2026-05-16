import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/features/splash/splash_screen.dart';

void main() {
  // The breathing animation and pulsing "Loading…" text loop forever.
  // pumpAndSettle would time out — use pump(Duration) throughout.

  testWidgets('SplashScreen renders without error', (tester) async {
    await tester.pumpWidget(const SplashScreen());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('Loading text appears after entrance delay', (tester) async {
    await tester.pumpWidget(const SplashScreen());
    // Progress bar delay 600 ms + animation 400 ms → pump past 1100 ms.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('Compliance tagline appears', (tester) async {
    await tester.pumpWidget(const SplashScreen());
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Compliance that protects.'), findsOneWidget);
  });
}
