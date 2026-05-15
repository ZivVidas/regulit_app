# Fancy UI Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade MetricCard to full gradient fill and expand the desktop AppShell sidebar to 160 px with labels, section groups, and a user footer.

**Architecture:** Component-first — two files change, every screen that uses MetricCard or AppShell inherits the upgrade automatically. Three new gradient tokens are added to theme.dart first so both components can reference them.

**Tech Stack:** Flutter 3, Dart, Riverpod 2 (StateNotifierProvider / AutoDisposeProvider), go_router 14, freezed AppUser model, flutter_test for widget tests.

---

## File Map

| File | Change |
|---|---|
| `lib/app/theme.dart` | Add `successHeader`, `warningHeader`, `dangerHeader` to `AppGradients` |
| `lib/shared/widgets/metric_card.dart` | Full rewrite of `build()` — gradient fill, glow orb, white text, colored shadow, remove `tinted` |
| `lib/shared/widgets/app_shell.dart` | `_NavItem` gains `group?`, sidebar expands to 160 px, add `_SidebarNavItem`, `_SidebarSectionLabel`, `_LanguagePickerRow`, `_UserFooter`; remove `_Logo`, `_SidebarIcon`, `_UserAvatar`, `_LanguagePicker` |
| `test/shared/widgets/metric_card_test.dart` | Add variant smoke test + gradient rendering tests |
| `test/shared/widgets/app_shell_test.dart` | New file — desktop sidebar smoke tests |

---

## Task 1: Add gradient tokens to theme.dart

**Files:**
- Modify: `lib/app/theme.dart`

- [ ] **Step 1: Add three gradients to AppGradients**

Open `lib/app/theme.dart`. Find `AppGradients` (around line 150). After the `dangerSubtle` gradient, add:

```dart
  static const LinearGradient successHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF107C10), Color(0xFF0A5C0A)],
  );

  static const LinearGradient warningHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFCA8A04), Color(0xFFD97C0A)],
  );

  static const LinearGradient dangerHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD13438), Color(0xFFA01010)],
  );
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/app/theme.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/app/theme.dart
git commit -m "feat: add successHeader, warningHeader, dangerHeader gradients"
```

---

## Task 2: Upgrade MetricCard to gradient fill

**Files:**
- Modify: `lib/shared/widgets/metric_card.dart`
- Modify: `test/shared/widgets/metric_card_test.dart`

- [ ] **Step 1: Write failing tests**

Replace all content of `test/shared/widgets/metric_card_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/metric_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('MetricCard', () {
    testWidgets('renders label uppercase and value', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Open Gaps', value: '24'),
      ));
      expect(find.text('OPEN GAPS'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
    });

    testWidgets('renders sub text when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Score', value: '82%', sub: '3 new'),
      ));
      expect(find.text('3 new'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        MetricCard(label: 'Tasks', value: '10', onTap: () => tapped = true),
      ));
      await tester.tap(find.text('10'));
      expect(tapped, isTrue);
    });

    testWidgets('renders trend label when trend provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(
          label: 'Tasks',
          value: '10',
          trend: MetricTrend(direction: TrendDirection.up, label: '+3 this week'),
        ),
      ));
      expect(find.text('+3 this week'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Users', value: '42', icon: Icons.people),
      ));
      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('sub text hidden when trend is provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(
          label: 'Score',
          value: '84%',
          sub: 'hidden text',
          trend: MetricTrend(direction: TrendDirection.flat, label: 'no change'),
        ),
      ));
      expect(find.text('hidden text'), findsNothing);
      expect(find.text('no change'), findsOneWidget);
    });

    testWidgets('renders all MetricVariant values without error', (tester) async {
      for (final variant in MetricVariant.values) {
        await tester.pumpWidget(_wrap(
          MetricCard(label: 'Test', value: '42', variant: variant),
        ));
        expect(find.text('TEST'), findsOneWidget, reason: 'variant=$variant');
        expect(find.text('42'), findsOneWidget, reason: 'variant=$variant');
      }
    });

    testWidgets('tappable card uses Ink with non-null gradient', (tester) async {
      await tester.pumpWidget(_wrap(
        MetricCard(label: 'Score', value: '84%', onTap: () {}),
      ));
      final ink = tester.widget<Ink>(find.byType(Ink).first);
      final decoration = ink.decoration as BoxDecoration;
      expect(decoration.gradient, isNotNull);
    });

    testWidgets('non-tappable card has DecoratedBox with gradient', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(label: 'Score', value: '84%'),
      ));
      final allBoxes =
          tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      final hasGradient = allBoxes.any((b) {
        final d = b.decoration;
        return d is BoxDecoration && d.gradient != null;
      });
      expect(hasGradient, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect failures**

Run: `flutter test test/shared/widgets/metric_card_test.dart -v`

Expected: The two new gradient tests fail (`Ink` not found / no gradient decoration). The original five tests pass.

- [ ] **Step 3: Rewrite metric_card.dart**

Replace all content of `lib/shared/widgets/metric_card.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../utils/currency_formatter.dart';

enum MetricVariant { neutral, success, warning, danger }

enum TrendDirection { up, down, flat }

class MetricTrend {
  final TrendDirection direction;
  final String label;
  const MetricTrend({required this.direction, required this.label});
}

extension _MetricVariantX on MetricVariant {
  LinearGradient get gradient => switch (this) {
        MetricVariant.neutral => AppGradients.primaryHeader,
        MetricVariant.success => AppGradients.successHeader,
        MetricVariant.warning => AppGradients.warningHeader,
        MetricVariant.danger  => AppGradients.dangerHeader,
      };

  Color get shadowColor => switch (this) {
        MetricVariant.neutral => const Color(0x400078D4),
        MetricVariant.success => const Color(0x40107C10),
        MetricVariant.warning => const Color(0x40CA8A04),
        MetricVariant.danger  => const Color(0x40D13438),
      };
}

extension _TrendDirectionX on TrendDirection {
  IconData get icon => switch (this) {
        TrendDirection.up   => Icons.trending_up_rounded,
        TrendDirection.down => Icons.trending_down_rounded,
        TrendDirection.flat => Icons.trending_flat_rounded,
      };
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final MetricVariant variant;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;
  final MetricTrend? trend;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.variant = MetricVariant.neutral,
    this.trailing,
    this.onTap,
    this.icon,
    this.trend,
  });

  factory MetricCard.currency({
    Key? key,
    required String label,
    required double amountNIS,
    String? sub,
    MetricVariant variant = MetricVariant.neutral,
    IconData? icon,
    MetricTrend? trend,
    VoidCallback? onTap,
  }) {
    return MetricCard(
      key: key,
      label: label,
      value: CurrencyFormatter.nis(amountNIS),
      sub: sub,
      variant: variant,
      icon: icon,
      trend: trend,
      onTap: onTap,
    );
  }

  factory MetricCard.percent({
    Key? key,
    required String label,
    required double value,
    String? sub,
    MetricVariant variant = MetricVariant.neutral,
    IconData? icon,
    MetricTrend? trend,
    VoidCallback? onTap,
  }) {
    return MetricCard(
      key: key,
      label: label,
      value: '${(value * 100).round()}%',
      sub: sub,
      variant: variant,
      icon: icon,
      trend: trend,
      onTap: onTap,
    );
  }

  // All text is white-palette on gradient backgrounds.
  static const _labelStyle = TextStyle(
    fontFamily: 'Heebo', fontSize: 11, fontWeight: FontWeight.w700,
    letterSpacing: 0.4, color: Color(0xB3FFFFFF), // 70% white
  );
  static const _valueStyle = TextStyle(
    fontFamily: 'Heebo', fontSize: 28, fontWeight: FontWeight.w800,
    color: Colors.white, height: 1,
  );
  static const _trendStyle = TextStyle(
    fontFamily: 'Heebo', fontSize: 11, color: Color(0xCCFFFFFF), // 80% white
  );
  static const _subStyle = TextStyle(
    fontFamily: 'Heebo', fontSize: 11, color: Color(0xBFFFFFFF), // 75% white
  );
  static const _iconColor  = Color(0xCCFFFFFF);
  static const _trendColor = Color(0xCCFFFFFF);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);

    // ── Content ──────────────────────────────────────────────
    Widget content = Padding(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: _labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) Icon(icon, size: 20, color: _iconColor),
              if (trailing != null) trailing!,
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(value, style: _valueStyle),
          if (trend != null) ...[
            const Gap(AppSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trend!.direction.icon, size: 14, color: _trendColor),
                const SizedBox(width: 3),
                Text(trend!.label, style: _trendStyle),
              ],
            ),
          ],
          if (sub != null && trend == null) ...[
            const Gap(AppSpacing.xs),
            Text(sub!, style: _subStyle),
          ],
        ],
      ),
    );

    // ── Glow orb (decorative, no pointer events) ─────────────
    final contentStack = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -25,
          right: -15,
          child: IgnorePointer(
            child: SizedBox(
              width: 90,
              height: 90,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0x1AFFFFFF), // 10% white circle
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        content,
      ],
    );

    final shadow = BoxShadow(
      color: variant.shadowColor,
      blurRadius: 20,
      offset: const Offset(0, 4),
    );

    // ── Tappable: Ink (gradient) on Material (ink canvas) ────
    if (onTap != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [shadow],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              gradient: variant.gradient,
              borderRadius: radius,
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: ClipRRect(borderRadius: radius, child: contentStack),
            ),
          ),
        ),
      );
    }

    // ── Non-tappable: DecoratedBox with gradient ──────────────
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: variant.gradient,
        borderRadius: radius,
        boxShadow: [shadow],
      ),
      child: ClipRRect(borderRadius: radius, child: contentStack),
    );
  }
}

/// Row of metric cards — responsive wrap on small screens.
class MetricRow extends StatelessWidget {
  final List<MetricCard> cards;
  const MetricRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: SizedBox(width: double.infinity, child: c),
                    ))
                .toList(),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const Gap(AppSpacing.md),
              ],
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run tests — expect all pass**

Run: `flutter test test/shared/widgets/metric_card_test.dart -v`
Expected: 9 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/metric_card.dart test/shared/widgets/metric_card_test.dart
git commit -m "feat: MetricCard gradient fill with white text and glow orb"
```

---

## Task 3: Expand AppShell desktop sidebar to 160 px

**Files:**
- Create: `test/shared/widgets/app_shell_test.dart`
- Modify: `lib/shared/widgets/app_shell.dart`

- [ ] **Step 1: Write failing tests**

Create `test/shared/widgets/app_shell_test.dart`:

```dart
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
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('ReguLit'), findsOneWidget);
    });

    testWidgets('shows section labels MAIN, WORKFLOWS, SYSTEM for admin',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('MAIN'), findsOneWidget);
      expect(find.text('WORKFLOWS'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);
    });

    testWidgets('shows nav item labels for admin role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
    });

    testWidgets('shows user name in footer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('Ziv V'), findsOneWidget);
    });

    testWidgets('does not show sidebar on narrow viewport (mobile)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrapDesktop(_adminUser));
      await tester.pumpAndSettle();
      expect(find.text('ReguLit'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect failures**

Run: `flutter test test/shared/widgets/app_shell_test.dart -v`

Expected: All 5 tests fail (sidebar is 56 px with no brand text, no section labels).

- [ ] **Step 3: Update _NavItem with group field**

In `lib/shared/widgets/app_shell.dart`, find the `_NavItem` class (around line 415) and replace it:

```dart
class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final String? group;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.group,
  });
}
```

- [ ] **Step 4: Update _navItemsForRole with groups**

Find `_navItemsForRole` (around line 423) and replace the entire function body:

```dart
List<_NavItem> _navItemsForRole(
  UserRole? role,
  AppLocalizations l10n, {
  bool hasEvaluatedWorkflows = false,
}) {
  if (role == null) return [];
  switch (role) {
    case UserRole.regulitAdmin:
      return [
        _NavItem(icon: Icons.people_outlined,        label: l10n.navUsers,      route: AppRoutes.users,           group: 'Main'),
        _NavItem(icon: Icons.business_outlined,      label: l10n.navCustomers,  route: AppRoutes.customers,       group: 'Main'),
        _NavItem(icon: Icons.quiz_outlined,          label: l10n.navQuizzes,    route: AppRoutes.quizzes,         group: 'Workflows'),
        _NavItem(icon: Icons.account_tree_outlined,  label: l10n.navWorkflows,  route: AppRoutes.workflows,       group: 'Workflows'),
        _NavItem(icon: Icons.smart_toy_outlined,     label: l10n.navAgents,     route: AppRoutes.agents,          group: 'Workflows'),
        _NavItem(icon: Icons.dashboard_rounded,      label: l10n.navAdminDash,  route: AppRoutes.adminDashboard,  group: 'System'),
      ];
    case UserRole.csm:
    case UserRole.analyst:
      return [
        _NavItem(icon: Icons.business_outlined,      label: l10n.navClients,       route: AppRoutes.portfolio,     group: 'Clients'),
        _NavItem(icon: Icons.check_circle_outline,   label: l10n.navEvidenceQueue, route: AppRoutes.evidenceQueue, group: 'Clients'),
        _NavItem(icon: Icons.notifications_outlined, label: l10n.navAlerts,        route: '/alerts',               group: 'Monitoring'),
        _NavItem(icon: Icons.bar_chart_outlined,     label: l10n.navReports,       route: '/reports',              group: 'Monitoring'),
      ];
    case UserRole.clientAdmin:
      if (!hasEvaluatedWorkflows) return [];
      return [
        _NavItem(icon: Icons.dashboard_outlined,   label: l10n.navDashboard,    route: AppRoutes.dashboard,       group: 'Main'),
        _NavItem(icon: Icons.view_kanban_outlined,  label: l10n.navKanban,       route: AppRoutes.tasks,           group: 'Main'),
        _NavItem(icon: Icons.folder_copy_outlined,  label: l10n.navSessionFiles, route: AppRoutes.sessionFilesNav, group: 'Manage'),
        _NavItem(icon: Icons.group_outlined,        label: l10n.navUsers,        route: AppRoutes.clientUsers,     group: 'Manage'),
      ];
    case UserRole.itExecutor:
      return [
        _NavItem(icon: Icons.view_kanban_outlined,  label: l10n.navKanban,       route: AppRoutes.tasks),
        _NavItem(icon: Icons.folder_copy_outlined,  label: l10n.navSessionFiles, route: AppRoutes.sessionFilesNav),
      ];
    case UserRole.employee:
      return [
        _NavItem(icon: Icons.list_alt_outlined, label: l10n.navMyTasks, route: AppRoutes.taskList),
      ];
  }
}
```

- [ ] **Step 5: Replace _DesktopSidebar, _Logo, _SidebarIcon, _UserAvatar, _LanguagePicker with new widgets**

Replace the entire section from `// ── Desktop Sidebar ──` through the end of `_LanguagePicker` (all private sidebar widgets) with the following. Keep `_CustomerTopBar` and the nav helpers (`_roleFromContext`, `_NavItem`, `_navItemsForRole`) unchanged.

The new private widgets to add (replace the old `_DesktopSidebar`, `_Logo`, `_LanguagePicker`, `_SidebarIcon`, `_UserAvatar` sections entirely):

```dart
// ── Desktop Sidebar ──────────────────────────────────────────────────────────
class _DesktopSidebar extends ConsumerWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final AppUser user;

  const _DesktopSidebar({
    required this.items,
    required this.selectedIndex,
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    // Build nav item list with optional section labels
    final List<Widget> navWidgets = [];
    String? lastGroup;
    final hasGroups = items.any((item) => item.group != null);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (hasGroups && item.group != null && item.group != lastGroup) {
        navWidgets.add(_SidebarSectionLabel(label: item.group!));
        lastGroup = item.group;
      }
      navWidgets.add(_SidebarNavItem(
        item: item,
        isActive: i == selectedIndex,
        onTap: () => context.go(item.route),
      ));
    }

    return Container(
      width: 160,
      color: AppColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Brand row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/newlogo.png',
                  width: 28,
                  height: 28,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ReguLit',
                  style: TextStyle(
                    fontFamily: 'Heebo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Nav items (with optional section group labels)
          ...navWidgets,
          const Spacer(),
          // Language picker row
          _LanguagePickerRow(currentLocale: currentLocale),
          // Settings
          _SidebarNavItem(
            item: _NavItem(
              icon: Icons.settings_outlined,
              label: l10n.settings,
              route: '/settings',
            ),
            isActive: false,
            onTap: () {},
          ),
          const SizedBox(height: 4),
          const Divider(color: Color(0x1FFFFFFF), height: 1),
          // User footer
          _UserFooter(user: user, ref: ref),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Sidebar Nav Item ─────────────────────────────────────────────────────────
class _SidebarNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? const Color(0x21FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 18,
              color: isActive ? Colors.white : const Color(0x8CFFFFFF),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontFamily: 'Heebo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0x8CFFFFFF),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar Section Label ────────────────────────────────────────────────────
class _SidebarSectionLabel extends StatelessWidget {
  final String label;
  const _SidebarSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Heebo',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Color(0x59FFFFFF), // 35% white
        ),
      ),
    );
  }
}

// ── Language Picker Row ──────────────────────────────────────────────────────
class _LanguagePickerRow extends ConsumerWidget {
  final Locale currentLocale;
  const _LanguagePickerRow({required this.currentLocale});

  static const _languages = [
    (locale: Locale('en'), flag: '🇬🇧', name: 'English'),
    (locale: Locale('he'), flag: '🇮🇱', name: 'עברית'),
    (locale: Locale('es'), flag: '🇪🇸', name: 'Español'),
    (locale: Locale('fr'), flag: '🇫🇷', name: 'Français'),
    (locale: Locale('ru'), flag: '🇷🇺', name: 'Русский'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Locale>(
      padding: EdgeInsets.zero,
      offset: const Offset(160, 0),
      tooltip: '',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        child: Row(
          children: const [
            Icon(Icons.translate, size: 18, color: Color(0x8CFFFFFF)),
            SizedBox(width: 10),
            Text(
              'Language',
              style: TextStyle(
                fontFamily: 'Heebo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0x8CFFFFFF),
              ),
            ),
          ],
        ),
      ),
      onSelected: (locale) =>
          ref.read(localeProvider.notifier).setLocale(locale),
      itemBuilder: (_) => _languages
          .map(
            (lang) => PopupMenuItem<Locale>(
              value: lang.locale,
              child: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(
                    lang.name,
                    style: TextStyle(
                      fontWeight:
                          currentLocale.languageCode == lang.locale.languageCode
                              ? FontWeight.w700
                              : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── User Footer ──────────────────────────────────────────────────────────────
class _UserFooter extends StatelessWidget {
  final AppUser user;
  final WidgetRef ref;
  const _UserFooter({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final initials = user.name.isNotEmpty
        ? user.name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';

    return GestureDetector(
      onTap: () => _showLogoutMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.orange,
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontFamily: 'Heebo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.role?.displayName ?? '',
                    style: const TextStyle(
                      fontFamily: 'Heebo',
                      fontSize: 9,
                      color: Color(0x80FFFFFF), // 50% white
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user.name),
        content: Text(user.email),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authStateProvider.notifier).logout();
            },
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run tests — expect all pass**

Run: `flutter test test/shared/widgets/app_shell_test.dart -v`
Expected: 5 tests pass.

- [ ] **Step 7: Run all widget tests**

Run: `flutter test test/shared/widgets/ -v`
Expected: All tests pass (no regressions).

- [ ] **Step 8: Commit**

```bash
git add lib/shared/widgets/app_shell.dart test/shared/widgets/app_shell_test.dart
git commit -m "feat: expand desktop sidebar to 160px with labels, groups, user footer"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ Task 1: `successHeader`, `warningHeader`, `dangerHeader` added to `AppGradients`
- ✅ Task 2: Gradient fill per variant, glow orb, white text palette, colored shadow, `tinted` removed
- ✅ Task 2: `MetricCard.currency`, `MetricCard.percent`, `MetricRow`, `MetricTrend`, `TrendDirection` unchanged
- ✅ Task 3: 160 px width, brand row (logo + "ReguLit"), section labels per role, `_SidebarNavItem` with icon+label, user footer with name/role
- ✅ Task 3: Active indicator = white glass (`0x21FFFFFF` rounded rect), not orange chip
- ✅ Task 3: Mobile `BottomNavigationBar` untouched
- ✅ Task 3: Language picker expanded to icon+label row

**No call-site cleanup needed**: No existing call sites pass `tinted:`.
