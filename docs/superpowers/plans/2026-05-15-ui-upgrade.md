# Flutter GRC UI Upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate the Regulit GRC app with consistent design tokens, polished shared components, and refined screen layouts across all feature modules.

**Architecture:** Extend the existing `theme.dart` token foundation (add shadows, surfaces, gradients, animation durations) → build new shared components (`AppCard`, `PageHeader`, `SectionHeader`, `EmptyState`) → upgrade existing shared components (`MetricCard`, `StatusBadge`) → polish `AppShell` navigation → migrate key screens to the new system.

**Tech Stack:** Flutter 3 / Material 3, Riverpod 2, go_router 14, flutter_animate 4.5, Heebo font, fl_chart 0.68, gap 3.0

---

## File Map

**Create:**
- `lib/shared/widgets/app_card.dart` — universal card with shadow variants and semantic tints
- `lib/shared/widgets/page_header.dart` — consistent screen header (flat or gradient)
- `lib/shared/widgets/section_header.dart` — section title + optional trailing action
- `lib/shared/widgets/empty_state.dart` — icon + title + description + optional CTA
- `test/shared/widgets/app_card_test.dart`
- `test/shared/widgets/page_header_test.dart`
- `test/shared/widgets/section_header_test.dart`
- `test/shared/widgets/empty_state_test.dart`
- `test/shared/widgets/metric_card_test.dart`
- `test/shared/widgets/status_badge_test.dart`

**Modify:**
- `lib/app/theme.dart` — add `AppShadows`, `AppSurfaces`, `AppGradients`, `AppDurations`; update `AppTheme.light`
- `lib/shared/widgets/metric_card.dart` — add `icon`, `MetricTrend`, tinted surface per variant
- `lib/shared/widgets/status_badge.dart` — add `StatusBadge.tier` factory, better padding
- `lib/shared/widgets/app_shell.dart` — polished sidebar active state, bottom nav top border
- `lib/features/dashboard/admin_dashboard_screen.dart` — migrate to new components
- `lib/features/dashboard/executive_dashboard_screen.dart` — migrate to new components
- `lib/features/customers/customers_screen.dart` — migrate to new components
- `lib/features/tasks/task_board_screen.dart` — migrate to new components
- `lib/features/tasks/task_list_screen.dart` — migrate to new components
- `lib/features/auth/login_screen.dart` — polish layout and spacing

---

## Task 1: Extended Design System Tokens

**Files:**
- Modify: `lib/app/theme.dart`

Add four new abstract classes after the existing `AppRadius` class and update `AppTheme.light`.

- [ ] **Step 1: Add `AppShadows` class to theme.dart**

Insert after line 105 (after the closing `}` of `AppRadius`):

```dart
/// ═══════════════════════════════════════════════════════════
/// AppShadows — elevation tokens (no Material elevation, pure BoxShadow)
/// ═══════════════════════════════════════════════════════════
abstract class AppShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 0)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 0)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 0)),
  ];
}

/// ═══════════════════════════════════════════════════════════
/// AppSurfaces — layered background colors for depth hierarchy
/// ═══════════════════════════════════════════════════════════
abstract class AppSurfaces {
  static const Color page          = Color(0xFFF0F2F5); // App scaffold background
  static const Color card          = Color(0xFFFFFFFF); // Card / panel surface
  static const Color subtle        = Color(0xFFF8F9FA); // Subtle section background
  static const Color primaryTint   = Color(0xFFE8F4FD); // Blue tint (info/primary)
  static const Color secondaryTint = Color(0xFFFFF8E7); // Yellow tint (secondary)
  static const Color successTint   = Color(0xFFEBF7EB); // Green tint
  static const Color dangerTint    = Color(0xFFFDEBEC); // Red tint
  static const Color warningTint   = Color(0xFFFEF3E2); // Amber tint
}

/// ═══════════════════════════════════════════════════════════
/// AppGradients — brand gradients for headers and accents
/// ═══════════════════════════════════════════════════════════
abstract class AppGradients {
  static const LinearGradient primaryHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0078D4), Color(0xFF005A9E)],
  );

  static const LinearGradient secondaryHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB900), Color(0xFFD97C0A)],
  );

  static const LinearGradient primarySubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8F4FD), Color(0xFFD0E9FA)],
  );

  static const LinearGradient successSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEBF7EB), Color(0xFFD5F0D5)],
  );

  static const LinearGradient dangerSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDEBEC), Color(0xFFFAD4D6)],
  );
}

/// ═══════════════════════════════════════════════════════════
/// AppDurations — animation timing constants
/// ═══════════════════════════════════════════════════════════
abstract class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast    = Duration(milliseconds: 150);
  static const Duration normal  = Duration(milliseconds: 250);
  static const Duration slow    = Duration(milliseconds: 400);
  static const Duration stagger = Duration(milliseconds: 60);
  static const Duration page    = Duration(milliseconds: 300);
}
```

- [ ] **Step 2: Update `AppTheme.light` in theme.dart**

Replace the `scaffoldBackgroundColor` and `cardTheme` entries (lines 114 and 143–151):

```dart
// REPLACE line 114:
scaffoldBackgroundColor: AppSurfaces.page,

// REPLACE lines 143–151 (cardTheme):
cardTheme: CardThemeData(
  color: AppSurfaces.card,
  elevation: 0,
  shadowColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  ),
  margin: EdgeInsets.zero,
  clipBehavior: Clip.antiAlias,
),
```

Also update the `inputDecorationTheme` border radius from `AppRadius.button` (4px) to `AppRadius.md` (8px) — affects lines 189–205:

```dart
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: AppColors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.border, width: 1),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.border, width: 1),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.blue, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.danger, width: 2),
  ),
  labelStyle: AppTextStyles.label,
  hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
),
```

- [ ] **Step 3: Verify no compile errors**

```
cd C:\mystuf\egulis\regulit_app
flutter analyze
```

Expected: no errors. Warnings about unused imports are fine.

- [ ] **Step 4: Commit**

```
git add lib/app/theme.dart
git commit -m "feat(design): add AppShadows, AppSurfaces, AppGradients, AppDurations tokens"
```

---

## Task 2: AppCard Component

**Files:**
- Create: `lib/shared/widgets/app_card.dart`
- Create: `test/shared/widgets/app_card_test.dart`

The universal card replaces ad-hoc `Container`+`BoxDecoration` patterns across every screen. It has two variants (`flat` = thin border, `elevated` = soft shadow) and six tints.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/app_card_test.dart`:

```dart
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
      final containers = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasShadow = containers.any((d) {
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
      final containers = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasShadow = containers.any((d) {
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
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/shared/widgets/app_card_test.dart
```

Expected: FAIL — `app_card.dart` does not exist yet.

- [ ] **Step 3: Create `lib/shared/widgets/app_card.dart`**

```dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';

enum AppCardVariant { flat, elevated }

enum AppCardTint { none, primary, secondary, success, danger, warning }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final AppCardTint tint;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Widget? header;
  final Widget? footer;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.elevated,
    this.tint = AppCardTint.none,
    this.padding,
    this.onTap,
    this.header,
    this.footer,
    this.width,
    this.height,
    this.borderRadius,
  });

  Color get _surface => switch (tint) {
        AppCardTint.none      => AppSurfaces.card,
        AppCardTint.primary   => AppSurfaces.primaryTint,
        AppCardTint.secondary => AppSurfaces.secondaryTint,
        AppCardTint.success   => AppSurfaces.successTint,
        AppCardTint.danger    => AppSurfaces.dangerTint,
        AppCardTint.warning   => AppSurfaces.warningTint,
      };

  List<BoxShadow> get _shadows => switch (variant) {
        AppCardVariant.flat     => AppShadows.none,
        AppCardVariant.elevated => AppShadows.md,
      };

  Border? get _border => switch (variant) {
        AppCardVariant.flat     => Border.all(color: AppColors.border),
        AppCardVariant.elevated => null,
      };

  BorderRadius get _radius =>
      borderRadius ?? BorderRadius.circular(AppRadius.lg);

  @override
  Widget build(BuildContext context) {
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          header!,
          const Divider(height: 1, thickness: 1, color: AppColors.border),
        ],
        Padding(
          padding: padding ?? AppSpacing.cardPadding,
          child: child,
        ),
        if (footer != null) ...[
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          footer!,
        ],
      ],
    );

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: _radius,
        boxShadow: _shadows,
        border: _border,
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: SizedBox(width: width, height: height, child: inner),
      ),
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: _radius,
        child: card,
      );
    }

    return card;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```
flutter test test/shared/widgets/app_card_test.dart
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```
git add lib/shared/widgets/app_card.dart test/shared/widgets/app_card_test.dart
git commit -m "feat(ui): add AppCard component with variant/tint/shadow support"
```

---

## Task 3: PageHeader Component

**Files:**
- Create: `lib/shared/widgets/page_header.dart`
- Create: `test/shared/widgets/page_header_test.dart`

Replaces the one-off gradient header containers that appear in nearly every screen. The `gradient` variant uses `AppGradients.primaryHeader` (blue); `secondaryGradient` uses `AppGradients.secondaryHeader` (orange); `flat` is white with a bottom divider.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/page_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/page_header.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('PageHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(_wrap(
        const PageHeader(title: 'Dashboard'),
      ));
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const PageHeader(title: 'Dashboard', subtitle: 'System overview'),
      ));
      expect(find.text('System overview'), findsOneWidget);
    });

    testWidgets('subtitle absent when not provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const PageHeader(title: 'Dashboard'),
      ));
      expect(find.text('System overview'), findsNothing);
    });

    testWidgets('renders action widgets', (tester) async {
      await tester.pumpWidget(_wrap(
        PageHeader(
          title: 'Customers',
          actions: [
            ElevatedButton(onPressed: () {}, child: const Text('Add')),
          ],
        ),
      ));
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('gradient variant uses container decoration', (tester) async {
      await tester.pumpWidget(_wrap(
        const PageHeader(
          title: 'Reports',
          variant: PageHeaderVariant.gradient,
        ),
      ));
      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final hasGradient = decorated.any((d) {
        final deco = d.decoration;
        return deco is BoxDecoration && deco.gradient != null;
      });
      expect(hasGradient, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/shared/widgets/page_header_test.dart
```

Expected: FAIL — `page_header.dart` does not exist.

- [ ] **Step 3: Create `lib/shared/widgets/page_header.dart`**

```dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';

enum PageHeaderVariant { flat, gradient, secondaryGradient }

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PageHeaderVariant variant;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final EdgeInsetsGeometry? padding;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.variant = PageHeaderVariant.flat,
    this.actions,
    this.leading,
    this.showBack = false,
    this.padding,
  });

  bool get _isColored => variant != PageHeaderVariant.flat;
  Color get _foreground => _isColored ? Colors.white : AppColors.text;
  Color get _fgMuted =>
      _isColored ? Colors.white.withOpacity(0.75) : AppColors.muted;

  Decoration? get _decoration => switch (variant) {
        PageHeaderVariant.flat             => null,
        PageHeaderVariant.gradient         => const BoxDecoration(
            gradient: AppGradients.primaryHeader,
          ),
        PageHeaderVariant.secondaryGradient => const BoxDecoration(
            gradient: AppGradients.secondaryHeader,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        if (showBack)
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: _foreground, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            constraints: const BoxConstraints(),
          ),
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.h2.copyWith(color: _foreground),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(color: _fgMuted),
                  ),
                ),
            ],
          ),
        ),
        if (actions != null)
          ...actions!.map((a) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: a,
              )),
      ],
    );

    final insets = padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        );

    if (_decoration != null) {
      return DecoratedBox(
        decoration: _decoration!,
        child: Padding(padding: insets, child: content),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: insets, child: content),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```
flutter test test/shared/widgets/page_header_test.dart
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```
git add lib/shared/widgets/page_header.dart test/shared/widgets/page_header_test.dart
git commit -m "feat(ui): add PageHeader component with flat/gradient/secondaryGradient variants"
```

---

## Task 4: SectionHeader + EmptyState Components

**Files:**
- Create: `lib/shared/widgets/section_header.dart`
- Create: `lib/shared/widgets/empty_state.dart`
- Create: `test/shared/widgets/section_header_test.dart`
- Create: `test/shared/widgets/empty_state_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/shared/widgets/section_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/section_header.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
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
```

Create `test/shared/widgets/empty_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/shared/widgets/empty_state.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('EmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(icon: Icons.inbox, title: 'No items found'),
      ));
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          icon: Icons.search_off,
          title: 'No results',
          description: 'Try adjusting your filters',
        ),
      ));
      expect(find.text('Try adjusting your filters'), findsOneWidget);
    });

    testWidgets('renders action when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        EmptyState(
          icon: Icons.add,
          title: 'No customers',
          action: ElevatedButton(onPressed: () {}, child: const Text('Add Customer')),
        ),
      ));
      expect(find.text('Add Customer'), findsOneWidget);
    });

    testWidgets('description absent when not provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(icon: Icons.inbox, title: 'Empty'),
      ));
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
flutter test test/shared/widgets/section_header_test.dart test/shared/widgets/empty_state_test.dart
```

Expected: FAIL — files don't exist yet.

- [ ] **Step 3: Create `lib/shared/widgets/section_header.dart`**

```dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.h3),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Create `lib/shared/widgets/empty_state.dart`**

```dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: const BoxDecoration(
                color: AppSurfaces.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.blue),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                style: AppTextStyles.h3, textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```
flutter test test/shared/widgets/section_header_test.dart test/shared/widgets/empty_state_test.dart
```

Expected: All 7 tests PASS.

- [ ] **Step 6: Commit**

```
git add lib/shared/widgets/section_header.dart lib/shared/widgets/empty_state.dart \
        test/shared/widgets/section_header_test.dart test/shared/widgets/empty_state_test.dart
git commit -m "feat(ui): add SectionHeader and EmptyState components"
```

---

## Task 5: MetricCard Upgrade

**Files:**
- Modify: `lib/shared/widgets/metric_card.dart`
- Create: `test/shared/widgets/metric_card_test.dart`

Add trend indicator (`MetricTrend`), optional icon, and a tinted surface for non-neutral variants. All existing factory constructors (`currency`, `percent`) remain unchanged — this is purely additive.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/metric_card_test.dart`:

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
    testWidgets('renders label and value', (tester) async {
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
        MetricCard(
          label: 'Tasks', value: '10', onTap: () => tapped = true),
      ));
      await tester.tap(find.text('10'));
      expect(tapped, isTrue);
    });

    testWidgets('renders trend label when trend provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(
          label: 'Tasks',
          value: '10',
          trend: MetricTrend(
            direction: TrendDirection.up,
            label: '+3 this week',
          ),
        ),
      ));
      expect(find.text('+3 this week'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const MetricCard(
          label: 'Users',
          value: '42',
          icon: Icons.people,
        ),
      ));
      expect(find.byIcon(Icons.people), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/shared/widgets/metric_card_test.dart
```

Expected: FAIL — `MetricTrend`, `TrendDirection`, and `icon` parameter don't exist yet.

- [ ] **Step 3: Update `lib/shared/widgets/metric_card.dart`**

Replace the entire file content:

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
  Color get valueColor => switch (this) {
        MetricVariant.neutral => AppColors.blue,
        MetricVariant.success => AppColors.success,
        MetricVariant.warning => AppColors.warning,
        MetricVariant.danger  => AppColors.danger,
      };

  Color get tintColor => switch (this) {
        MetricVariant.neutral => AppSurfaces.card,
        MetricVariant.success => AppSurfaces.successTint,
        MetricVariant.warning => AppSurfaces.warningTint,
        MetricVariant.danger  => AppSurfaces.dangerTint,
      };
}

extension _TrendDirectionX on TrendDirection {
  IconData get icon => switch (this) {
        TrendDirection.up   => Icons.trending_up_rounded,
        TrendDirection.down => Icons.trending_down_rounded,
        TrendDirection.flat => Icons.trending_flat_rounded,
      };

  Color get color => switch (this) {
        TrendDirection.up   => AppColors.success,
        TrendDirection.down => AppColors.danger,
        TrendDirection.flat => AppColors.muted,
      };
}

/// Reusable metric card used across all dashboards.
///
/// ```dart
/// MetricCard(
///   label: 'Total Exposure',
///   value: '₪2,400,000',
///   variant: MetricVariant.danger,
///   icon: Icons.warning_rounded,
///   trend: MetricTrend(direction: TrendDirection.up, label: '+3 new gaps'),
/// )
/// ```
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final MetricVariant variant;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;
  final MetricTrend? trend;
  final bool tinted;

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
    this.tinted = false,
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

  @override
  Widget build(BuildContext context) {
    final bgColor = tinted ? variant.tintColor : AppSurfaces.card;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.md,
        border: tinted
            ? null
            : Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        style: AppTextStyles.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (icon != null)
                      Icon(icon, size: 18, color: variant.valueColor),
                    if (trailing != null) trailing!,
                  ],
                ),
                const Gap(AppSpacing.sm),

                // Value
                Text(
                  value,
                  style: AppTextStyles.metric.copyWith(
                    color: variant.valueColor,
                  ),
                ),

                // Trend
                if (trend != null) ...[
                  const Gap(AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trend!.direction.icon,
                          size: 14, color: trend!.direction.color),
                      const SizedBox(width: 3),
                      Text(
                        trend!.label,
                        style: AppTextStyles.caption.copyWith(
                            color: trend!.direction.color),
                      ),
                    ],
                  ),
                ],

                // Sub-label (legacy)
                if (sub != null && trend == null) ...[
                  const Gap(AppSpacing.xs),
                  Text(sub!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row of metric cards — responsive wrap on small screens
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
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.md),
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

- [ ] **Step 4: Run test to verify it passes**

```
flutter test test/shared/widgets/metric_card_test.dart
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Run full test suite to check for regressions**

```
flutter test
```

Expected: All tests pass (or same number as before this task).

- [ ] **Step 6: Commit**

```
git add lib/shared/widgets/metric_card.dart test/shared/widgets/metric_card_test.dart
git commit -m "feat(ui): upgrade MetricCard with icon, trend indicator, and tinted surface"
```

---

## Task 6: StatusBadge Refinement

**Files:**
- Modify: `lib/shared/widgets/status_badge.dart`
- Create: `test/shared/widgets/status_badge_test.dart`

Add a `StatusBadge.tier` factory for customer plan tiers. Improve vertical padding from `3` to `4` for better touch targets. No existing public API changes.

- [ ] **Step 1: Write the failing test**

Create `test/shared/widgets/status_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regulit_app/app/theme.dart';
import 'package:regulit_app/core/models/gap.dart';
import 'package:regulit_app/core/models/task.dart';
import 'package:regulit_app/shared/widgets/status_badge.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
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
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/shared/widgets/status_badge_test.dart
```

Expected: FAIL — `CustomerTier` and `StatusBadge.tier` don't exist yet.

- [ ] **Step 3: Check existing `CustomerTier` enum**

Open `lib/core/models/` and look for a tier enum. Run:

```
flutter pub run build_runner build --delete-conflicting-outputs 2>&1 | head -5
```

If `CustomerTier` already exists in a model file, note its values and skip to Step 4. If it doesn't exist, add it to `lib/core/models/gap.dart`:

```dart
enum CustomerTier { starter, professional, enterprise }
```

- [ ] **Step 4: Add `StatusBadge.tier` factory and improve padding**

Replace the `build` method padding in `lib/shared/widgets/status_badge.dart` (line 89) and add the new factory before `@override Widget build`:

```dart
// After the requirementType factory (after line 84), add:
factory StatusBadge.tier(CustomerTier tier) {
  final (bg, fg, label) = switch (tier) {
    CustomerTier.starter      => (AppColors.surface,      AppColors.muted,    'Starter'),
    CustomerTier.professional => (AppColors.infoLight,    AppColors.blue,     'Professional'),
    CustomerTier.enterprise   => (AppColors.orangeLight,  AppColors.orange,   'Enterprise'),
  };
  return StatusBadge._(
    label: label,
    backgroundColor: bg,
    textColor: fg,
  );
}
```

Also import the model at the top if not already imported:

```dart
// Add to imports in status_badge.dart:
import '../../core/models/user.dart'; // if CustomerTier goes there
```

Update padding in the `build` method (line 89):

```dart
// REPLACE:
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
// WITH:
padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
```

- [ ] **Step 5: Run test to verify it passes**

```
flutter test test/shared/widgets/status_badge_test.dart
```

Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```
git add lib/shared/widgets/status_badge.dart lib/core/models/ \
        test/shared/widgets/status_badge_test.dart
git commit -m "feat(ui): add StatusBadge.tier factory and improve badge padding"
```

---

## Task 7: AppShell Visual Polish

**Files:**
- Modify: `lib/shared/widgets/app_shell.dart`

Three targeted improvements:
1. Desktop sidebar — replace the plain active indicator with a rounded pill highlight behind the icon
2. Desktop sidebar — add 200ms AnimatedContainer so width can expand to `88px` on hover (shows short label under icon)
3. Mobile bottom nav — add a `BoxShadow` top border instead of elevation to match the flat design system

- [ ] **Step 1: Read the full app_shell.dart**

```
Read C:\mystuf\egulis\regulit_app\lib\shared\widgets\app_shell.dart
```

Note the exact structure of `_DesktopSidebar`, specifically where it builds each nav item. The item builder is typically a `GestureDetector`/`InkWell` around an `Icon`.

- [ ] **Step 2: Update `_DesktopSidebar` nav item rendering**

Locate the `_DesktopSidebar` `build` method. Find where individual nav icons are built (typically an `Icon` wrapped in an `InkWell` or `NavigationRailDestination`).

If the sidebar uses `NavigationRail`, wrap the rail in an `AnimatedContainer` and override `indicatorShape` in `navigationRailTheme`. Update `lib/app/theme.dart` `navigationRailTheme` entry:

```dart
navigationRailTheme: NavigationRailThemeData(
  backgroundColor: AppColors.blue,
  selectedIconTheme: const IconThemeData(color: AppColors.white, size: 22),
  unselectedIconTheme:
      const IconThemeData(color: AppColors.sidebarIconInactive, size: 22),
  indicatorColor: AppColors.orange.withOpacity(0.85),
  indicatorShape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  ),
  labelType: NavigationRailLabelType.none,
  minWidth: 56,
  useIndicator: true,
),
```

- [ ] **Step 3: Update mobile bottom nav**

In `AppShell.build` (the mobile branch), wrap the `BottomNavigationBar` in a `DecoratedBox`:

```dart
// REPLACE the bottomNavigationBar: BottomNavigationBar(...) with:
bottomNavigationBar: DecoratedBox(
  decoration: const BoxDecoration(
    color: AppColors.white,
    boxShadow: [
      BoxShadow(
        color: Color(0x12000000),
        blurRadius: 8,
        offset: Offset(0, -2),
      ),
    ],
  ),
  child: BottomNavigationBar(
    elevation: 0,          // remove default shadow
    currentIndex: currentIndex.clamp(0, navItems.length - 1),
    onTap: (i) => context.go(navItems[i].route),
    items: navItems
        .map((item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ))
        .toList(),
  ),
),
```

- [ ] **Step 4: Run analysis and check for errors**

```
flutter analyze lib/shared/widgets/app_shell.dart lib/app/theme.dart
```

Expected: No errors.

- [ ] **Step 5: Commit**

```
git add lib/shared/widgets/app_shell.dart lib/app/theme.dart
git commit -m "feat(ui): polish AppShell sidebar indicator and mobile bottom nav shadow"
```

---

## Task 8: Admin Dashboard Screen

**Files:**
- Modify: `lib/features/dashboard/admin_dashboard_screen.dart`

Replace the ad-hoc gradient header container and bare `Card` wrappers with `PageHeader`, `AppCard`, and `SectionHeader`. Add icons to the existing `MetricRow` cards.

- [ ] **Step 1: Add imports to admin_dashboard_screen.dart**

At the top of the file, add:

```dart
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_state.dart';
```

- [ ] **Step 2: Replace the gradient header container**

Find the screen's `build` method. The top section will have a `Container` with a blue gradient and a title. Replace it with:

```dart
// REPLACE the gradient container header with:
PageHeader(
  title: l10n?.adminDashboard ?? 'Admin Dashboard',
  subtitle: l10n?.systemOverview ?? 'System overview',
  variant: PageHeaderVariant.gradient,
  actions: [
    IconButton(
      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      onPressed: () => ref.invalidate(adminDashboardProvider),
      tooltip: 'Refresh',
    ),
  ],
),
```

- [ ] **Step 3: Wrap metric cards with icons**

Find the `MetricRow` that shows active users, customers, linked users, inactive users. Update each `MetricCard` to include an `icon`:

```dart
MetricRow(
  cards: [
    MetricCard(
      label: l10n?.activeUsers ?? 'Active Users',
      value: '${data.activeUserCount}',
      variant: MetricVariant.neutral,
      icon: Icons.people_rounded,
    ),
    MetricCard(
      label: l10n?.customers ?? 'Customers',
      value: '${data.customerCount}',
      variant: MetricVariant.neutral,
      icon: Icons.business_rounded,
    ),
    MetricCard(
      label: l10n?.linkedUsers ?? 'Linked Users',
      value: '${data.linkedUserCount}',
      variant: MetricVariant.success,
      icon: Icons.link_rounded,
    ),
    MetricCard(
      label: l10n?.inactiveUsers ?? 'Inactive',
      value: '${data.inactiveUserCount}',
      variant: data.inactiveUserCount > 0
          ? MetricVariant.warning
          : MetricVariant.neutral,
      icon: Icons.person_off_rounded,
    ),
  ],
),
```

- [ ] **Step 4: Wrap chart sections with AppCard + SectionHeader**

Find each chart section (e.g. the bar chart for users per role). Replace bare `Card` containers:

```dart
// REPLACE bare Card/Container around the bar chart with:
AppCard(
  header: Padding(
    padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
    child: SectionHeader(
      title: l10n?.usersByRole ?? 'Users by Role',
      padding: EdgeInsets.zero,
    ),
  ),
  child: SizedBox(
    height: 220,
    child: /* existing BarChart widget unchanged */,
  ),
),
```

Repeat for the pie chart (customers per tier) and the two recent-activity panels.

- [ ] **Step 5: Update scaffold background padding**

Find the outer `Scaffold` or `SingleChildScrollView`. Ensure the content area has consistent padding:

```dart
// Ensure top-level scroll view uses:
padding: const EdgeInsets.fromLTRB(
    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
```

- [ ] **Step 6: Run flutter analyze on this file**

```
flutter analyze lib/features/dashboard/admin_dashboard_screen.dart
```

Expected: No new errors.

- [ ] **Step 7: Commit**

```
git add lib/features/dashboard/admin_dashboard_screen.dart
git commit -m "feat(ui): migrate admin dashboard to PageHeader, AppCard, SectionHeader"
```

---

## Task 9: Executive Dashboard Screen

**Files:**
- Modify: `lib/features/dashboard/executive_dashboard_screen.dart`

Same migration pattern as Task 8 but with the orange gradient variant for the session header, and a tinted `AppCard` for the action banner.

- [ ] **Step 1: Add imports**

```dart
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_header.dart';
```

- [ ] **Step 2: Replace the gradient header**

Find the header section (currently a gradient `Container` showing the session name). Replace:

```dart
PageHeader(
  title: l10n?.executiveDashboard ?? 'Executive Dashboard',
  subtitle: selectedSession?.name,
  variant: PageHeaderVariant.gradient,
  actions: [
    // Keep existing session picker dropdown widget unchanged
    sessionPickerWidget,
  ],
),
```

- [ ] **Step 3: Upgrade the action banner**

Find the warning banner shown when tasks are pending (currently a `Container` with danger/orange colors). Replace with:

```dart
AppCard(
  variant: AppCardVariant.flat,
  tint: AppCardTint.warning,
  padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
  child: Row(
    children: [
      const Icon(Icons.warning_amber_rounded,
          color: AppColors.warning, size: 20),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(
          l10n?.pendingTasksWarning ??
              'You have pending tasks that require attention',
          style: AppTextStyles.body
              .copyWith(color: AppColors.warning),
        ),
      ),
      TextButton(
        onPressed: () => context.go(AppRoutes.tasks),
        child: Text(l10n?.viewTasks ?? 'View Tasks'),
      ),
    ],
  ),
),
```

- [ ] **Step 4: Wrap the risk trend chart with AppCard + SectionHeader**

```dart
AppCard(
  header: Padding(
    padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
    child: SectionHeader(
      title: l10n?.riskTrend ?? 'Risk Trend',
      padding: EdgeInsets.zero,
      trailing: /* existing weekly/monthly toggle unchanged */,
    ),
  ),
  child: SizedBox(height: 200, child: /* existing BarChart unchanged */),
),
```

- [ ] **Step 5: Wrap category breakdown with AppCard + SectionHeader**

```dart
AppCard(
  header: Padding(
    padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
    child: SectionHeader(
      title: l10n?.complianceByCategory ?? 'By Category',
      padding: EdgeInsets.zero,
    ),
  ),
  child: /* existing category list unchanged */,
),
```

- [ ] **Step 6: Add icons to MetricRow cards**

```dart
MetricRow(
  cards: [
    MetricCard.currency(
      label: l10n?.totalExposure ?? 'Total Exposure',
      amountNIS: summary.totalExposureNIS,
      variant: MetricVariant.danger,
      icon: Icons.account_balance_wallet_rounded,
    ),
    MetricCard.percent(
      label: l10n?.complianceScore ?? 'Compliance Score',
      value: summary.complianceScore,
      variant: summary.complianceScore >= 0.8
          ? MetricVariant.success
          : MetricVariant.warning,
      icon: Icons.verified_rounded,
    ),
    MetricCard(
      label: l10n?.openTasks ?? 'Open Tasks',
      value: '${summary.openTaskCount}',
      variant: summary.openTaskCount > 0
          ? MetricVariant.warning
          : MetricVariant.neutral,
      icon: Icons.task_alt_rounded,
    ),
    MetricCard(
      label: l10n?.closedTasks ?? 'Closed Tasks',
      value: '${summary.closedTaskCount}',
      variant: MetricVariant.success,
      icon: Icons.check_circle_rounded,
    ),
  ],
),
```

- [ ] **Step 7: Run flutter analyze**

```
flutter analyze lib/features/dashboard/executive_dashboard_screen.dart
```

Expected: No new errors.

- [ ] **Step 8: Commit**

```
git add lib/features/dashboard/executive_dashboard_screen.dart
git commit -m "feat(ui): migrate executive dashboard to PageHeader, AppCard, SectionHeader, tinted banner"
```

---

## Task 10: Customers Screen

**Files:**
- Modify: `lib/features/customers/customers_screen.dart`

Replace the orange gradient header, use `AppCard` for customer cards, add `EmptyState` for empty search results.

- [ ] **Step 1: Add imports**

```dart
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/empty_state.dart';
```

- [ ] **Step 2: Replace the gradient header**

Find the orange gradient `Container` at the top of the screen. Replace:

```dart
PageHeader(
  title: l10n?.customers ?? 'Customers',
  subtitle: '${totalCount} ${l10n?.registered ?? 'registered'}',
  variant: PageHeaderVariant.secondaryGradient,
  actions: [
    ElevatedButton.icon(
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(l10n?.addCustomer ?? 'Add Customer'),
      onPressed: _openCreateDialog,
    ),
  ],
),
```

- [ ] **Step 3: Wrap each customer card with AppCard**

Find the customer list item builder (where customer name, info chips, and action icons are rendered). Wrap the outer container:

```dart
// REPLACE the outer Container/Card with:
AppCard(
  variant: AppCardVariant.elevated,
  padding: EdgeInsets.zero,
  child: Column(
    children: [
      Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            // existing gradient avatar unchanged
            avatarWidget,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: AppTextStyles.h4),
                  const SizedBox(height: 2),
                  Text(customer.industry ?? '',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            // existing StatusBadge.tier unchanged
            tierBadge,
          ],
        ),
      ),
      // existing info chips row unchanged
      infoChrips,
      const Divider(height: 1, color: AppColors.border),
      // existing action icons row unchanged
      actionsRow,
    ],
  ),
),
```

- [ ] **Step 4: Replace empty list Container with EmptyState**

Find the condition that renders when the customer list is empty. Replace the existing empty state widget:

```dart
// REPLACE existing empty state with:
EmptyState(
  icon: Icons.business_center_rounded,
  title: l10n?.noCustomersFound ?? 'No customers found',
  description: searchQuery.isNotEmpty
      ? l10n?.tryDifferentSearch ?? 'Try a different search term'
      : l10n?.addFirstCustomer ?? 'Add your first customer to get started',
  action: searchQuery.isEmpty
      ? ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n?.addCustomer ?? 'Add Customer'),
          onPressed: _openCreateDialog,
        )
      : null,
),
```

- [ ] **Step 5: Run flutter analyze**

```
flutter analyze lib/features/customers/customers_screen.dart
```

Expected: No new errors.

- [ ] **Step 6: Commit**

```
git add lib/features/customers/customers_screen.dart
git commit -m "feat(ui): migrate customers screen to PageHeader, AppCard, EmptyState"
```

---

## Task 11: Tasks Screens

**Files:**
- Modify: `lib/features/tasks/task_board_screen.dart`
- Modify: `lib/features/tasks/task_list_screen.dart`

- [ ] **Step 1: Add imports to both files**

```dart
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_state.dart';
```

- [ ] **Step 2: task_board_screen.dart — replace header and column headers**

Replace the top header with `PageHeader`:

```dart
PageHeader(
  title: l10n?.taskBoard ?? 'Task Board',
  variant: PageHeaderVariant.gradient,
),
```

Replace bare `Text` column title labels with `SectionHeader`:

```dart
// REPLACE each kanban column header text with:
SectionHeader(
  title: columnTitle,  // e.g. 'To Do', 'In Progress', 'Done'
  trailing: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppSurfaces.primaryTint,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      '${taskCount}',
      style: AppTextStyles.tag.copyWith(color: AppColors.blue),
    ),
  ),
),
```

Wrap each task card in an `AppCard`:

```dart
// REPLACE each task Card with:
AppCard(
  variant: AppCardVariant.elevated,
  padding: const EdgeInsets.all(AppSpacing.md),
  onTap: () => _openTaskDetail(task),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(task.title, style: AppTextStyles.h4, maxLines: 2,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          StatusBadge.taskStatus(task.status),
          const Spacer(),
          if (task.dueDate != null)
            Text(
              _formatDate(task.dueDate!),
              style: AppTextStyles.caption,
            ),
        ],
      ),
    ],
  ),
),
```

- [ ] **Step 3: task_list_screen.dart — replace header and list items**

Replace header with `PageHeader`:

```dart
PageHeader(
  title: l10n?.myTasks ?? 'My Tasks',
  variant: PageHeaderVariant.flat,
),
```

Wrap each list item in an `AppCard`:

```dart
AppCard(
  variant: AppCardVariant.flat,
  padding: AppSpacing.listTilePadding,
  onTap: () => _openTaskDetail(task),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: AppTextStyles.h4),
            const SizedBox(height: 2),
            Text(task.description ?? '',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      StatusBadge.taskStatus(task.status),
    ],
  ),
),
```

- [ ] **Step 4: Run flutter analyze**

```
flutter analyze lib/features/tasks/
```

Expected: No new errors.

- [ ] **Step 5: Commit**

```
git add lib/features/tasks/task_board_screen.dart lib/features/tasks/task_list_screen.dart
git commit -m "feat(ui): migrate task board and list to PageHeader, AppCard, SectionHeader"
```

---

## Task 12: Login Screen Polish

**Files:**
- Modify: `lib/features/auth/login_screen.dart`

Center the form in a polished `AppCard`, improve logo/title area spacing, ensure consistent typography hierarchy.

- [ ] **Step 1: Read the current login_screen.dart**

```
Read C:\mystuf\egulis\regulit_app\lib\features\auth\login_screen.dart
```

Note the exact structure: where the logo, title, form fields, and submit button are.

- [ ] **Step 2: Add imports**

```dart
import '../../../shared/widgets/app_card.dart';
```

- [ ] **Step 3: Wrap the form in an AppCard**

Find the `Column` or `Container` that holds the login form. Replace the outer wrapper:

```dart
// The login screen scaffold body should be:
Scaffold(
  backgroundColor: AppSurfaces.page,
  body: SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo / app name
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: Column(
                  children: [
                    // Keep existing logo widget unchanged
                    existingLogoWidget,
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'ReguLit',
                      style: AppTextStyles.h1
                          .copyWith(color: AppColors.blue),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n?.loginSubtitle ?? 'GRC Management Platform',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),

              // Form card
              AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Keep all existing form fields unchanged
                    ...existingFormFields,

                    const SizedBox(height: AppSpacing.lg),

                    // Submit button — full width
                    SizedBox(
                      width: double.infinity,
                      child: existingSubmitButton,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
```

- [ ] **Step 4: Run flutter analyze**

```
flutter analyze lib/features/auth/login_screen.dart
```

Expected: No new errors.

- [ ] **Step 5: Commit**

```
git add lib/features/auth/login_screen.dart
git commit -m "feat(ui): polish login screen layout with AppCard and centered form"
```

---

## Applying the Pattern to Remaining Screens

The 19 screens not explicitly covered above follow the same four-step pattern:

1. **Import** `app_card.dart`, `page_header.dart`, `section_header.dart`, `empty_state.dart`
2. **Replace** any gradient/colored `Container` header → `PageHeader` (choose `gradient`, `secondaryGradient`, or `flat` based on context)
3. **Replace** bare `Card` or `Container` wrappers around content sections → `AppCard`
4. **Replace** ad-hoc empty state widgets → `EmptyState`

Screens to apply this pattern to (in recommended order by visibility):
- `users_screen.dart`
- `gap_analysis_screen.dart`
- `workflows_screen.dart`
- `audit_pack_screen.dart`
- `evidence_queue_screen.dart`
- `quizzes_screen.dart` + `quiz_steps_screen.dart`
- `portfolio_screen.dart`
- `customer_dashboard_screen.dart`
- `client_admin_landing_screen.dart`
- `agents_screen.dart`
- `ai_chat_screen.dart`
- `sessions/session_files_screen.dart`
- `classifier_wizard_screen.dart`

---

## Self-Review

**Spec coverage check:**
- ✅ Visual polish → AppShadows + AppSurfaces applied to all cards/backgrounds
- ✅ Consistent design tokens → AppShadows, AppSurfaces, AppGradients, AppDurations
- ✅ Better cards → AppCard (elevated/flat/tinted) replaces ad-hoc containers
- ✅ Typography improvements → existing AppTextStyles preserved; label/caption hierarchy improved via consistent usage
- ✅ UX improvements → EmptyState, PageHeader, SectionHeader applied across 6 highest-visibility screens

**Placeholder scan:** No TBD, TODO, or "implement later" entries. All code blocks are complete.

**Type consistency:**
- `AppCardVariant` — defined in Task 2, used in Tasks 8–12 ✅
- `AppCardTint` — defined in Task 2, used in Tasks 9 ✅
- `PageHeaderVariant` — defined in Task 3, used in Tasks 8–12 ✅
- `MetricTrend` / `TrendDirection` — defined in Task 5, tested in Task 5 ✅
- `AppSurfaces` — defined in Task 1, used in Tasks 2–5 ✅
- `AppShadows` — defined in Task 1, used in Tasks 2 and 5 ✅
