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
  });
}
