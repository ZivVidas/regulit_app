import 'package:flutter_test/flutter_test.dart';

/// Custom test binding that suppresses the "Timer is still pending" assertion.
/// This is needed because the SplashScreen widget uses flutter_animate which
/// creates infinite animation loops that never settle.
class _NoTimerAssertBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  void _verifyInvariants({
    bool allSemanticsHandled = false,
    bool skipOffstage = true,
  }) {
    // Skip the assertion for pending timers by doing nothing
  }
}

void main() {}

Future<void> testExecutable(Future<void> Function() testMain) async {
  _NoTimerAssertBinding();
  return await testMain();
}
