// test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/core/api/api_client.dart';
import 'package:regulit_app/core/auth/auth_provider.dart';
import 'package:regulit_app/core/models/user.dart';
import 'package:regulit_app/features/auth/login_screen.dart';
import 'package:regulit_app/l10n/app_localizations.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

// Minimal AuthState that returns null (logged out) without hitting the network.
class _LoggedOutAuthState extends AuthState {
  @override
  Future<AppUser?> build() async => null;
}

class _SlowAuthState extends AuthState {
  @override
  Future<AppUser?> build() async => null;

  @override
  Future<void> loginAndHold({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    // Never completes — simulates a slow API call
    await Future<void>.delayed(const Duration(hours: 1));
  }

  @override
  void completeLogin() {}
}

// Simulates loginAndHold() that completes instantly with success.
class _SuccessAuthState extends AuthState {
  @override
  Future<AppUser?> build() async => null;

  @override
  Future<void> loginAndHold({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    // Returns immediately — simulates instant API success
  }

  @override
  void completeLogin() {
    state = AsyncData(AppUser(
      id: 'u1',
      tenantId: 'ten',
      email: 'alice@test.com',
      name: 'Alice',
      role: UserRole.employee,
    ));
  }
}

Widget _wrap(WidgetTester tester, {required Size size}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final storage = _MockStorage();
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authStateProvider.overrideWith(_LoggedOutAuthState.new),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const LoginScreen(),
    ),
  );
}

Widget _wrapSuccess(WidgetTester tester, {required Size size}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final storage = _MockStorage();
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authStateProvider.overrideWith(_SuccessAuthState.new),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const LoginScreen(),
    ),
  );
}

Widget _wrapSlow(WidgetTester tester, {required Size size}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final storage = _MockStorage();
  when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authStateProvider.overrideWith(_SlowAuthState.new),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const LoginScreen(),
    ),
  );
}

void main() {
  group('LoginScreen — desktop layout (≥ 700 px)', () {
    testWidgets('shows brand panel with ReguLit name and headline',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(900, 700)));
      await tester.pumpAndSettle();

      expect(find.text('ReguLit'), findsOneWidget);
      expect(find.textContaining('Compliance made'), findsOneWidget);
    });

    testWidgets('shows "Welcome back" heading and two form fields',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(900, 700)));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  group('LoginScreen — mobile layout (< 700 px)', () {
    testWidgets('hides brand panel headline, shows ReguLit in mobile header',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(400, 700)));
      await tester.pumpAndSettle();

      // Brand panel headline is desktop-only.
      expect(find.textContaining('Compliance made'), findsNothing);
      // Mobile header still shows the brand name.
      expect(find.text('ReguLit'), findsOneWidget);
    });

    testWidgets('shows two form fields on mobile', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(400, 700)));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  group('LoginScreen — button phase transitions', () {
    testWidgets('idle state: Sign In label visible, no spinner', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(400, 800)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sign in'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loading phase: spinner visible, label gone', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrapSlow(tester, size: const Size(400, 800)));
      await tester.pumpAndSettle();

      // Fill form to pass validation
      await tester.enterText(find.byType(TextFormField).first, 'alice@test.com');
      await tester.enterText(find.byType(TextFormField).last, 'password1');
      await tester.tap(find.byType(FilledButton));
      await tester.pump(); // process the tap + setState — spinner enters tree
      await tester.pump(const Duration(milliseconds: 250)); // finish AnimatedSwitcher fade

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Sign in'), findsNothing);

      // Drain the pending 1-hour timer so the test framework doesn't complain
      // about pending timers when the widget tree is disposed.
      await tester.pump(const Duration(hours: 1));
    });
  });

  group('LoginScreen — fade overlay', () {
    testWidgets('white overlay not visible in idle state', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(tester, size: const Size(400, 800)));
      await tester.pumpAndSettle();

      // AnimatedOpacity from _FadeToWhiteOverlay should be at opacity 0.0
      final overlayFinder = find.byKey(const Key('fadeToWhiteOverlay'));
      // The _FadeToWhiteOverlay AnimatedOpacity must exist
      expect(overlayFinder, findsOneWidget);
      final overlay = tester.widget<AnimatedOpacity>(overlayFinder);
      // In idle state the overlay must be invisible
      expect(overlay.opacity, 0.0);
    });
  });
}
