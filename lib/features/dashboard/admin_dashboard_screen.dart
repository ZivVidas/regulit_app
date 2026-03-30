import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Data model ────────────────────────────────────────────────
class _DashData {
  final int activeUsers;
  final int totalUsers;
  final int activeCustomers;
  final int totalCustomers;
  final int linkedUsersCount;
  final int totalLinks;
  final Map<String, int> usersPerRole;
  final Map<String, int> customersPerTier;
  final List<Map<String, dynamic>> recentUsers;
  final List<Map<String, dynamic>> recentCustomers;

  const _DashData({
    required this.activeUsers,
    required this.totalUsers,
    required this.activeCustomers,
    required this.totalCustomers,
    required this.linkedUsersCount,
    required this.totalLinks,
    required this.usersPerRole,
    required this.customersPerTier,
    required this.recentUsers,
    required this.recentCustomers,
  });
}

// ── Provider ──────────────────────────────────────────────────
final _dashProvider =
    FutureProvider.autoDispose<_DashData>((ref) async {
  final dio = ref.watch(dioProvider);
  final res =
      await dio.get<Map<String, dynamic>>('/admin/dashboard');
  final d = res.data!;
  return _DashData(
    activeUsers: d['activeUsers'] as int,
    totalUsers: d['totalUsers'] as int,
    activeCustomers: d['activeCustomers'] as int,
    totalCustomers: d['totalCustomers'] as int,
    linkedUsersCount: d['linkedUsersCount'] as int,
    totalLinks: d['totalLinks'] as int,
    usersPerRole: Map<String, int>.from(d['usersPerRole'] as Map),
    customersPerTier:
        Map<String, int>.from(d['customersPerTier'] as Map),
    recentUsers: (d['recentUsers'] as List)
        .cast<Map<String, dynamic>>(),
    recentCustomers: (d['recentCustomers'] as List)
        .cast<Map<String, dynamic>>(),
  );
});

// ── Screen ────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dashProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(onRefresh: () => ref.invalidate(_dashProvider)),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.danger),
                    const Gap(12),
                    Text(e.toString(),
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.danger)),
                    const Gap(16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(_dashProvider),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (data) => _DashBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x401E3A8A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
          child: Row(
            children: [
              const Icon(Icons.dashboard_rounded,
                  color: Colors.white, size: 28),
              const Gap(10),
              Text(
                'Regulit Dashboard',
                style: AppTextStyles.h2.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white),
                tooltip: 'Refresh',
                onPressed: onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashboard body ────────────────────────────────────────────
class _DashBody extends StatelessWidget {
  final _DashData data;
  const _DashBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Metric cards row ──────────────────────────────
          _MetricsRow(data: data),
          const Gap(20),

          // ── Charts row ────────────────────────────────────
          LayoutBuilder(builder: (_, constraints) {
            final wide = constraints.maxWidth > 700;
            final charts = [
              _UsersPerRoleChart(usersPerRole: data.usersPerRole),
              _CustomersPerTierChart(
                  customersPerTier: data.customersPerTier),
            ];
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[0]),
                      const Gap(16),
                      Expanded(child: charts[1]),
                    ],
                  )
                : Column(children: [
                    charts[0],
                    const Gap(16),
                    charts[1],
                  ]);
          }),
          const Gap(20),

          // ── Recent activity row ───────────────────────────
          LayoutBuilder(builder: (_, constraints) {
            final wide = constraints.maxWidth > 700;
            final panels = [
              _RecentPanel(
                title: 'Recent Users',
                icon: Icons.people_outlined,
                color: const Color(0xFF3B82F6),
                items: data.recentUsers,
                itemBuilder: (item) => _RecentUserTile(item: item),
              ),
              _RecentPanel(
                title: 'Recent Customers',
                icon: Icons.business_outlined,
                color: const Color(0xFFEA580C),
                items: data.recentCustomers,
                itemBuilder: (item) =>
                    _RecentCustomerTile(item: item),
              ),
            ];
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: panels[0]),
                      const Gap(16),
                      Expanded(child: panels[1]),
                    ],
                  )
                : Column(children: [
                    panels[0],
                    const Gap(16),
                    panels[1],
                  ]);
          }),
        ],
      ),
    );
  }
}

// ── Metrics row ───────────────────────────────────────────────
class _MetricsRow extends StatelessWidget {
  final _DashData data;
  const _MetricsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        label: 'Active Users',
        value: data.activeUsers,
        sub: 'of ${data.totalUsers} total',
        icon: Icons.person_outlined,
        color: const Color(0xFF3B82F6),
        index: 0,
      ),
      _MetricCard(
        label: 'Active Customers',
        value: data.activeCustomers,
        sub: 'of ${data.totalCustomers} total',
        icon: Icons.business_outlined,
        color: const Color(0xFFEA580C),
        index: 1,
      ),
      _MetricCard(
        label: 'Linked Users',
        value: data.linkedUsersCount,
        sub: '${data.totalLinks} assignments',
        icon: Icons.link_rounded,
        color: const Color(0xFF059669),
        index: 2,
      ),
      _MetricCard(
        label: 'Inactive Users',
        value: data.totalUsers - data.activeUsers,
        sub: 'pending activation',
        icon: Icons.person_off_outlined,
        color: const Color(0xFF9CA3AF),
        index: 3,
      ),
    ];

    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 800
          ? 4
          : constraints.maxWidth > 500
              ? 2
              : 1;
      return GridView.count(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.0,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    });
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final String sub;
  final IconData icon;
  final Color color;
  final int index;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: AppTextStyles.h2.copyWith(
                      color: color,
                      fontSize: 26,
                      fontWeight: FontWeight.w800),
                ),
                Text(label,
                    style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(sub, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 70).ms, duration: 350.ms)
        .slideY(begin: 0.15, delay: (index * 70).ms, duration: 350.ms);
  }
}

// ── Users per role chart ──────────────────────────────────────
class _UsersPerRoleChart extends StatelessWidget {
  final Map<String, int> usersPerRole;
  const _UsersPerRoleChart({required this.usersPerRole});

  static const _roleColors = {
    'regulit_admin': Color(0xFF1D4ED8),
    'csm': Color(0xFFEA580C),
    'regulit_analyst': Color(0xFF7C3AED),
    'client_admin': Color(0xFF0891B2),
    'it_executor': Color(0xFF059669),
    'employee': Color(0xFF9CA3AF),
  };

  Color _colorFor(String role) =>
      _roleColors[role] ?? const Color(0xFF6B7280);

  String _label(String role) => switch (role) {
        'regulit_admin' => 'Admin',
        'csm' => 'CSM',
        'regulit_analyst' => 'Analyst',
        'client_admin' => 'Client Admin',
        'it_executor' => 'IT Exec',
        'employee' => 'Employee',
        _ => role,
      };

  @override
  Widget build(BuildContext context) {
    if (usersPerRole.isEmpty) return const SizedBox.shrink();
    final entries = usersPerRole.entries.toList();
    final maxVal =
        entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return _ChartCard(
      title: 'Users by Role',
      icon: Icons.people_outlined,
      color: const Color(0xFF3B82F6),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Gap(8),
            _HBar(
              label: _label(entries[i].key),
              value: entries[i].value,
              maxValue: maxVal,
              color: _colorFor(entries[i].key),
              index: i,
            ),
          ],
        ],
      ),
    );
  }
}

class _HBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;
  final int index;

  const _HBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxValue == 0 ? 0.0 : value / maxValue;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
        ),
        const Gap(8),
        Expanded(
          child: LayoutBuilder(builder: (_, constraints) {
            return Stack(
              children: [
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 600 + index * 80),
                  curve: Curves.easeOut,
                  height: 18,
                  width: constraints.maxWidth * pct,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
        const Gap(8),
        SizedBox(
          width: 24,
          child: Text(value.toString(),
              style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

// ── Customers per tier chart (pie) ────────────────────────────
class _CustomersPerTierChart extends StatefulWidget {
  final Map<String, int> customersPerTier;
  const _CustomersPerTierChart({required this.customersPerTier});

  @override
  State<_CustomersPerTierChart> createState() =>
      _CustomersPerTierChartState();
}

class _CustomersPerTierChartState
    extends State<_CustomersPerTierChart> {
  int _touched = -1;

  static const _tierColors = {
    'enterprise': Color(0xFFD97706),
    'standard': Color(0xFF3B82F6),
    'basic': Color(0xFF9CA3AF),
  };

  Color _colorFor(String tier) =>
      _tierColors[tier] ?? const Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    if (widget.customersPerTier.isEmpty) return const SizedBox.shrink();
    final entries = widget.customersPerTier.entries.toList();
    final total = entries.fold(0, (s, e) => s + e.value);

    final sections = entries.asMap().entries.map((e) {
      final i = e.key;
      final entry = e.value;
      final isTouched = i == _touched;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        color: _colorFor(entry.key),
        radius: isTouched ? 70 : 58,
        title: isTouched
            ? '${(entry.value / total * 100).round()}%'
            : '',
        titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13),
      );
    }).toList();

    return _ChartCard(
      title: 'Customers by Tier',
      icon: Icons.business_outlined,
      color: const Color(0xFFEA580C),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sections: sections,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      setState(() => _touched = -1);
                      return;
                    }
                    setState(() => _touched =
                        response.touchedSection!.touchedSectionIndex);
                  },
                ),
                centerSpaceRadius: 36,
                sectionsSpace: 3,
              ),
            ),
          ),
          const Gap(12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: entries
                .map((e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _colorFor(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Gap(5),
                        Text(
                          '${e.key[0].toUpperCase()}${e.key.substring(1)} (${e.value})',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Chart card wrapper ────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const Gap(8),
            Text(title,
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
          const Gap(14),
          child,
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}

// ── Recent panel ──────────────────────────────────────────────
class _RecentPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _RecentPanel({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Row(children: [
              Icon(icon, color: color, size: 16),
              const Gap(8),
              Text(title,
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No data yet',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center),
            )
          else
            ...items.asMap().entries.map((e) => itemBuilder(e.value)
                .animate()
                .fadeIn(delay: (e.key * 50).ms, duration: 300.ms)),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms, duration: 400.ms);
  }
}

class _RecentUserTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _RecentUserTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isActive = item['isActive'] as bool? ?? true;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor:
            const Color(0xFF3B82F6).withOpacity(0.15),
        child: Text(
          (item['fullName'] as String? ?? '?')[0].toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      ),
      title: Text(item['fullName'] as String? ?? '—',
          style: AppTextStyles.bodySmall
              .copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(item['roleName'] as String? ?? '',
          style: AppTextStyles.caption),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFDCFCE7)
              : AppColors.dangerLight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isActive ? 'Active' : 'Inactive',
          style: AppTextStyles.tag.copyWith(
              color: isActive
                  ? const Color(0xFF16A34A)
                  : AppColors.danger),
        ),
      ),
    );
  }
}

class _RecentCustomerTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _RecentCustomerTile({required this.item});

  static const _tierColors = {
    'enterprise': Color(0xFFD97706),
    'standard': Color(0xFF3B82F6),
    'basic': Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    final tier = item['subscriptionTier'] as String? ?? 'basic';
    final isActive = item['isActive'] as bool? ?? true;
    final color =
        _tierColors[tier] ?? const Color(0xFF9CA3AF);
    final name = item['name'] as String? ?? '—';
    return ListTile(
      dense: true,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      ),
      title: Text(name,
          style: AppTextStyles.bodySmall
              .copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${tier[0].toUpperCase()}${tier.substring(1)}',
          style: AppTextStyles.caption),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFDCFCE7)
              : AppColors.dangerLight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isActive ? 'Active' : 'Inactive',
          style: AppTextStyles.tag.copyWith(
              color: isActive
                  ? const Color(0xFF16A34A)
                  : AppColors.danger),
        ),
      ),
    );
  }
}
