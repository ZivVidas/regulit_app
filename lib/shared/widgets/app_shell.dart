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
/// - Web / desktop  → expanded sidebar (160px, labels + groups)
/// - Mobile          → BottomNavigationBar
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return child;

    // Customer context role always takes priority over the user's system role.
    // A user may have a system role (e.g. employee) that is overridden when they
    // operate inside a customer workspace as client_admin or it_executor.
    final customerCtx = ref.watch(customerContextProvider);
    final effectiveRole = _roleFromContext(customerCtx) ?? user.role;

    // For clientAdmin: ask the server directly (FutureProvider, cached per
    // customerId). Falls back to the StateProvider value while loading so the
    // "Go to Dashboard" button can give instant feedback.
    bool hasEvaluatedWorkflows = ref.watch(clientHasEvaluatedWorkflowsProvider);
    if (effectiveRole == UserRole.clientAdmin) {
      final customerId = customerCtx?['customerId'] as String?;
      if (customerId != null) {
        hasEvaluatedWorkflows =
            ref.watch(clientNavEnabledProvider(customerId)).valueOrNull ??
                hasEvaluatedWorkflows;
      }
    }

    final l10n = AppLocalizations.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    final navItems = _navItemsForRole(effectiveRole, l10n,
        hasEvaluatedWorkflows: hasEvaluatedWorkflows);
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
          elevation: 0,
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
  final String? group;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.group,
  });
}

/// Null role = customer context not yet resolved → show minimal nav.
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
