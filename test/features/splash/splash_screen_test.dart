import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/features/splash/splash_screen.dart';

void main() {
  // The breathing animation and pulsing "Loading…" text loop forever.
  // pumpAndSettle would time out — use pump(Duration) throughout.

  testWidgets('SplashScreen renders without error', (tester) async {
    await tester.pumpWidget(const SplashScreen());
    // Pump past the latest entrance delay (footer at 800 ms) so all
    // flutter_animate delay Timers fire and no pending timers remain at
    // widget disposal.
    await tester.pump(const Duration(milliseconds: 1500));
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
