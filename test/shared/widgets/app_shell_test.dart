import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/core/auth/auth_provider.dart';
import 'package:regulit_app/core/customer/customer_context_provider.dart';
import 'package:regulit_app/core/locale/locale_provider.dart';
import 'package:regulit_app/core/models/user.dart';
import 'package:regulit_app/l10n/app_localizations.dart';
import 'package:regulit_app/shared/widgets/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _adminUser = AppUser(
  id: 'u1',
  tenantId: 't1',
  email: 'admin@test.com',
  name: 'Ziv V',
  role: UserRole.regulitAdmin,
);

Widget _wrapDesktop(AppUser user) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => AppShell(child: const SizedBox.shrink()),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      customerContextProvider.overrideWith(
          (ref) => CustomerContextNotifier(ref)),
      clientHasEvaluatedWorkflowsProvider.overrideWith((ref) => false),
      localeProvider.overrideWith((ref) => LocaleNotifier()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      routerConfig: router,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppShell desktop sidebar', () {
    testWidgets('shows ReguLit brand text at 160 px width', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('ReguLit'), findsOneWidget);
    });

    testWidgets('shows section labels MAIN, WORKFLOWS, SYSTEM for admin',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('MAIN'), findsOneWidget);
      expect(find.text('WORKFLOWS'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);
    });

    testWidgets('shows nav item labels for admin role', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
    });

    testWidgets('shows user name in footer', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('Ziv V'), findsOneWidget);
    });

    testWidgets('does not show sidebar on narrow viewport (mobile)',
        (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('ReguLit'), findsNothing);
    });
  });
}
