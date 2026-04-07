import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/models/user.dart';
import '../../l10n/app_localizations.dart';

/// Responsive app shell:
/// - Web / desktop  → NavigationRail (left sidebar, icon-only, 56px)
/// - Mobile          → BottomNavigationBar
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return child;

    // For client users (role == null), derive effective role from customer context
    final customerCtx = ref.watch(customerContextProvider);
    final effectiveRole = user.role ?? _roleFromContext(customerCtx);

    final l10n = AppLocalizations.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    final navItems = _navItemsForRole(effectiveRole, l10n);
    final currentIndex = _selectedIndex(context, navItems);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(
              items: navItems,
              selectedIndex: currentIndex,
              user: user,
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  // Show customer workspace bar for client-side users
                  if (user.role == null || user.role!.isClientSide)
                    const _CustomerTopBar(),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex.clamp(0, navItems.length - 1),
        onTap: (i) => context.go(navItems[i].route),
        items: navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }

  int _selectedIndex(BuildContext context, List<_NavItem> items) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = items.indexWhere((item) => loc.startsWith(item.route));
    return idx < 0 ? 0 : idx;
  }
}

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
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    return Container(
      width: 56,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Logo
          const SizedBox(height: 12),
          _Logo(),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Nav icons
          ...items.asMap().entries.map((entry) {
            final isActive = entry.key == selectedIndex;
            return _SidebarIcon(
              item: entry.value,
              isActive: isActive,
              onTap: () => context.go(entry.value.route),
            );
          }),

          const Spacer(),

          // Language picker
          _LanguagePicker(currentLocale: currentLocale),
          const SizedBox(height: 4),

          // Settings
          _SidebarIcon(
            item: _NavItem(
              icon: Icons.settings_outlined,
              label: l10n.settings,
              route: '/settings',
            ),
            isActive: false,
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // User avatar + logout
          _UserAvatar(user: user, ref: ref),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Language Picker ───────────────────────────────────────────────────────────
class _LanguagePicker extends ConsumerWidget {
  final Locale currentLocale;
  const _LanguagePicker({required this.currentLocale});

  static const _languages = [
    (locale: Locale('en'), flag: '🇬🇧', name: 'English'),
    (locale: Locale('he'), flag: '🇮🇱', name: 'עברית'),
    (locale: Locale('es'), flag: '🇪🇸', name: 'Español'),
    (locale: Locale('fr'), flag: '🇫🇷', name: 'Français'),
    (locale: Locale('ru'), flag: '🇷🇺', name: 'Русский'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Language / שפה',
      preferBelow: false,
      child: PopupMenuButton<Locale>(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.translate,
          size: 20,
          color: AppColors.sidebarIconInactive,
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
                        fontWeight: currentLocale.languageCode ==
                                lang.locale.languageCode
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Logo ─────────────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/newlogo.png',
      width: 36,
      height: 36,
      filterQuality: FilterQuality.high,
    );
  }
}

// ── Sidebar Icon ─────────────────────────────────────────────────────────────
class _SidebarIcon extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isActive ? AppColors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            item.icon,
            size: 20,
            color: isActive
                ? AppColors.white
                : AppColors.sidebarIconInactive,
          ),
        ),
      ),
    );
  }
}

// ── User Avatar + Logout ──────────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final AppUser user;
  final WidgetRef ref;

  const _UserAvatar({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final initials = user.name.isNotEmpty
        ? user.name.trim().split(' ').map((w) => w[0]).take(2).join()
        : '?';

    return GestureDetector(
      onTap: () => _showLogoutMenu(context),
      child: Tooltip(
        message: '${user.name}\n${user.email}',
        child: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.orange,
          child: Text(
            initials.toUpperCase(),
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
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

// ── Customer Workspace Top Bar ────────────────────────────────────────────────
class _CustomerTopBar extends ConsumerWidget {
  const _CustomerTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(customerContextProvider);
    if (ctx == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final customerName = ctx['customerName'] as String? ?? '';
    final role = ctx['role'] as String? ?? '';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_outlined, size: 16, color: AppColors.blue),
          const SizedBox(width: 8),
          Text(customerName, style: AppTextStyles.h4),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              role,
              style: AppTextStyles.tag.copyWith(color: AppColors.blue),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(customerContextProvider.notifier).state = null,
            icon: const Icon(Icons.swap_horiz, size: 14),
            label: Text(l10n.switchWorkspace),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle:
                  AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav helpers ───────────────────────────────────────────────────────────────

/// Maps the role string stored in customer context → UserRole enum.
UserRole? _roleFromContext(Map<String, dynamic>? ctx) {
  if (ctx == null) return null;
  return switch (ctx['role'] as String?) {
    'client_admin' => UserRole.clientAdmin,
    'it_executor'  => UserRole.itExecutor,
    'employee'     => UserRole.employee,
    _              => null,
  };
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}

/// Null role = customer context not yet resolved → show minimal nav.
List<_NavItem> _navItemsForRole(UserRole? role, AppLocalizations l10n) {
  if (role == null) {
    return [];
  }
  switch (role) {
    case UserRole.regulitAdmin:
      return [
        _NavItem(icon: Icons.people_outlined,        label: l10n.navUsers,      route: AppRoutes.users),
        _NavItem(icon: Icons.business_outlined,      label: l10n.navCustomers,  route: AppRoutes.customers),
        _NavItem(icon: Icons.quiz_outlined,          label: l10n.navQuizzes,    route: AppRoutes.quizzes),
        _NavItem(icon: Icons.account_tree_outlined,  label: l10n.navWorkflows,  route: AppRoutes.workflows),
        _NavItem(icon: Icons.smart_toy_outlined,     label: l10n.navAgents,     route: AppRoutes.agents),
        _NavItem(icon: Icons.dashboard_rounded,      label: l10n.navAdminDash,  route: AppRoutes.adminDashboard),
      ];
    case UserRole.csm:
    case UserRole.analyst:
      return [
        _NavItem(icon: Icons.business_outlined,      label: l10n.navClients,       route: AppRoutes.portfolio),
        _NavItem(icon: Icons.check_circle_outline,   label: l10n.navEvidenceQueue, route: AppRoutes.evidenceQueue),
        _NavItem(icon: Icons.notifications_outlined, label: l10n.navAlerts,        route: '/alerts'),
        _NavItem(icon: Icons.bar_chart_outlined,     label: l10n.navReports,       route: '/reports'),
      ];
    case UserRole.clientAdmin:
      // Step 15: dashboard (default) → kanban → task list → audit pack → users
      return [
        _NavItem(icon: Icons.dashboard_outlined,   label: l10n.navDashboard,  route: AppRoutes.dashboard),
        _NavItem(icon: Icons.view_kanban_outlined,  label: l10n.navKanban,    route: AppRoutes.tasks),
        _NavItem(icon: Icons.list_alt_outlined,     label: l10n.navMyTasks,   route: AppRoutes.taskList),
        _NavItem(icon: Icons.inventory_2_outlined,  label: l10n.navAuditPack, route: AppRoutes.auditPack),
        _NavItem(icon: Icons.group_outlined,        label: l10n.navUsers,     route: AppRoutes.clientUsers),
      ];
    case UserRole.itExecutor:
      // Step 15: kanban (default) → task list
      return [
        _NavItem(icon: Icons.view_kanban_outlined, label: l10n.navKanban,  route: AppRoutes.tasks),
        _NavItem(icon: Icons.list_alt_outlined,    label: l10n.navMyTasks, route: AppRoutes.taskList),
      ];
    case UserRole.employee:
      // Step 15: task list only (default screen)
      return [
        _NavItem(icon: Icons.list_alt_outlined, label: l10n.navMyTasks, route: AppRoutes.taskList),
      ];
  }
}
