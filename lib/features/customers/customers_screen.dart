import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import 'customer_users_panel.dart';
import 'customer_workflows_panel.dart';

// ── Tier accent colours ───────────────────────────────────────
const _kEnterprise = Color(0xFFD97706); // amber
const _kStandard = Color(0xFF3B82F6); // blue
const _kBasic = Color(0xFF9CA3AF); // muted gray

// ── Header gradient (warm orange) ────────────────────────────
const _kGrad0 = Color(0xFFEA580C); // orange-600
const _kGrad1 = Color(0xFFF97316); // orange-400

Color _tierColor(String tier) => switch (tier) {
      'enterprise' => _kEnterprise,
      'standard' => _kStandard,
      _ => _kBasic,
    };

// ── Screen State ─────────────────────────────────────────────
class _CustomersState {
  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int pages;
  final bool isLoading;
  final String? error;
  final String search;

  const _CustomersState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    this.isLoading = true,
    this.error,
    this.search = '',
  });

  _CustomersState copyWith({
    List<Map<String, dynamic>>? items,
    int? total,
    int? page,
    int? pages,
    bool? isLoading,
    String? error,
    String? search,
  }) =>
      _CustomersState(
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        search: search ?? this.search,
      );
}

// ── Notifier ─────────────────────────────────────────────────
class _CustomersNotifier extends StateNotifier<_CustomersState> {
  final Dio _dio;

  _CustomersNotifier(this._dio) : super(const _CustomersState()) {
    load();
  }

  Future<void> load({String? search, int? page}) async {
    final s = search ?? state.search;
    final p = page ?? state.page;
    state = state.copyWith(isLoading: true, error: null, search: s, page: p);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/customers',
        queryParameters: {'search': s, 'page': p, 'page_size': 20},
      );
      final data = res.data!;
      state = state.copyWith(
        isLoading: false,
        items: (data['items'] as List).cast<Map<String, dynamic>>(),
        total: data['total'] as int,
        pages: data['pages'] as int,
        page: data['page'] as int,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createCustomer(Map<String, dynamic> body) async {
    await _dio.post<dynamic>('/customers', data: body);
    await load();
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> body) async {
    await _dio.put<dynamic>('/customers/$id', data: body);
    await load();
  }

  Future<void> deactivateCustomer(String id) async {
    await _dio.delete<dynamic>('/customers/$id');
    await load();
  }
}

final _customersProvider =
    StateNotifierProvider.autoDispose<_CustomersNotifier, _CustomersState>(
        (ref) => _CustomersNotifier(ref.watch(dioProvider)));

// ── Screen ───────────────────────────────────────────────────
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) =>
      ref.read(_customersProvider.notifier).load(search: q, page: 1);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_customersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Vivid gradient header ──────────────────────────
          _GradientHeader(
            searchCtrl: _searchCtrl,
            onSearch: _search,
            onAdd: () => _showCustomerForm(context, null),
          ),

          // ── Count row ─────────────────────────────────────
          if (!s.isLoading && s.error == null && s.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(children: [
                Text(
                  '${s.total} customer${s.total == 1 ? '' : 's'}',
                  style: AppTextStyles.caption,
                ),
              ]),
            ),

          // ── Body ──────────────────────────────────────────
          Expanded(
            child: s.isLoading
                ? const _ShimmerList()
                : s.error != null
                    ? _ErrorView(
                        message: s.error!,
                        onRetry: () =>
                            ref.read(_customersProvider.notifier).load(),
                      )
                    : s.items.isEmpty
                        ? _EmptyView(
                            message: s.search.isEmpty
                                ? 'No customers yet. Add the first one.'
                                : 'No customers match "${s.search}".',
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            itemCount: s.items.length,
                            itemBuilder: (_, i) {
                              final c = s.items[i];
                              return _CustomerCard(
                                customer: c,
                                index: i,
                                onEdit: () =>
                                    _showCustomerForm(context, c),
                                onManageUsers: () =>
                                    showCustomerUsersPanel(
                                        context, ref, c),
                                onLinkWorkflow: () =>
                                    showCustomerWorkflowsPanel(
                                        context, ref, c),
                                onViewDashboard: () => context.push(
                                  '/admin/customers/${c['id']}/dashboard',
                                ),
                                onDeactivate: c['isActive'] == true
                                    ? () => _confirmDeactivate(
                                          context,
                                          c['id'] as String,
                                          c['name'] as String,
                                        )
                                    : null,
                              );
                            },
                          ),
          ),

          // ── Pagination ────────────────────────────────────
          if (!s.isLoading && s.error == null && s.pages > 1)
            _PaginationBar(
              page: s.page,
              pages: s.pages,
              onPrev: s.page > 1
                  ? () => ref
                      .read(_customersProvider.notifier)
                      .load(page: s.page - 1)
                  : null,
              onNext: s.page < s.pages
                  ? () => ref
                      .read(_customersProvider.notifier)
                      .load(page: s.page + 1)
                  : null,
            ),
        ],
      ),
    );
  }

  void _showCustomerForm(
      BuildContext context, Map<String, dynamic>? customer) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CustomerFormDialog(
        initialCustomer: customer,
        onSave: (body) async {
          final n = ref.read(_customersProvider.notifier);
          if (customer == null) {
            await n.createCustomer(body);
          } else {
            await n.updateCustomer(customer['id'] as String, body);
          }
        },
      ),
    );
  }

  Future<void> _confirmDeactivate(
      BuildContext context, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate customer'),
        content: Text(
            '$name will be marked as inactive. This does not delete any data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ref
            .read(_customersProvider.notifier)
            .deactivateCustomer(id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }
}

// ── Gradient header with search ───────────────────────────────
class _GradientHeader extends StatefulWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  const _GradientHeader({
    required this.searchCtrl,
    required this.onSearch,
    required this.onAdd,
  });

  @override
  State<_GradientHeader> createState() => _GradientHeaderState();
}

class _GradientHeaderState extends State<_GradientHeader> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad0, _kGrad1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40EA580C),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  const Icon(Icons.business_rounded,
                      color: Colors.white, size: 28),
                  const Gap(10),
                  Text(
                    'Customers',
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _AnimatedAddButton(onPressed: widget.onAdd),
                ],
              ),
              const Gap(14),
              // Search bar on gradient
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.30)),
                ),
                child: TextField(
                  controller: widget.searchCtrl,
                  onChanged: (v) {
                    setState(() {});
                    widget.onSearch(v);
                  },
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name, city, or industry…',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 18),
                    suffixIcon: widget.searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Colors.white.withOpacity(0.8),
                                size: 16),
                            onPressed: () {
                              widget.searchCtrl.clear();
                              widget.onSearch('');
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated Add button ───────────────────────────────────────
class _AnimatedAddButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AnimatedAddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _kGrad0,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add_business_outlined, size: 16),
      label: const Text('Add Customer',
          style:
              TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
            duration: 2400.ms, color: _kGrad1.withOpacity(0.35));
  }
}

// ── Customer card with hover + staggered anim ─────────────────
class _CustomerCard extends StatefulWidget {
  final Map<String, dynamic> customer;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onManageUsers;
  final VoidCallback onLinkWorkflow;
  final VoidCallback onViewDashboard;
  final VoidCallback? onDeactivate;

  const _CustomerCard({
    required this.customer,
    required this.index,
    required this.onEdit,
    required this.onManageUsers,
    required this.onLinkWorkflow,
    required this.onViewDashboard,
    this.onDeactivate,
  });

  @override
  State<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<_CustomerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final isActive = c['isActive'] as bool? ?? true;
    final tier = c['subscriptionTier'] as String? ?? 'basic';
    final tierColor = _tierColor(tier);
    final name = c['name'] as String? ?? '—';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        // ── Only shadow lives here – no border or color to avoid
        // the Flutter "non-uniform Border + borderRadius" paint error.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? tierColor.withOpacity(0.20)
                  : Colors.black.withOpacity(0.04),
              blurRadius: _hovered ? 16 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              // Uniform border (all sides same width) is safe with borderRadius.
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left tier-accent strip ───────────────
                  Container(width: 4, color: tierColor),
                  // ── Card body ────────────────────────────
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 14, 10, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top row ─────────────────────
                          Row(
                            children: [
                              // Gradient company-initial avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      tierColor,
                                      tierColor.withOpacity(0.60)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 19,
                                  ),
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15),
                                    ),
                                    if ((c['industry'] as String?)
                                            ?.isNotEmpty ==
                                        true)
                                      Text(c['industry'] as String,
                                          style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              _TierBadge(tier: tier),
                              const Gap(6),
                              if (!isActive) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerLight,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text('Inactive',
                                      style: AppTextStyles.tag.copyWith(
                                          color: AppColors.danger)),
                                ),
                                const Gap(4),
                              ],
                              _ActionIcon(
                                icon: Icons.edit_outlined,
                                tooltip: 'Edit',
                                onTap: widget.onEdit,
                                hoverColor: AppColors.blue,
                              ),
                              _ActionIcon(
                                icon: Icons.group_outlined,
                                tooltip: 'Manage users',
                                onTap: widget.onManageUsers,
                                hoverColor: const Color(0xFF059669),
                              ),
                              _ActionIcon(
                                icon: Icons.account_tree_outlined,
                                tooltip: 'Link Workflow',
                                onTap: widget.onLinkWorkflow,
                                hoverColor: const Color(0xFF7C3AED),
                              ),
                              _ActionIcon(
                                icon: Icons.bar_chart_rounded,
                                tooltip: 'Dashboard',
                                onTap: widget.onViewDashboard,
                                hoverColor: const Color(0xFFEA580C),
                              ),
                              if (widget.onDeactivate != null)
                                _ActionIcon(
                                  icon: Icons.archive_outlined,
                                  tooltip: 'Deactivate',
                                  onTap: widget.onDeactivate!,
                                  hoverColor: AppColors.danger,
                                ),
                            ],
                          ),
                          const Gap(10),
                          const Divider(
                              height: 1, color: AppColors.border),
                          const Gap(10),
                          // ── Info chips ───────────────────
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              if ((c['contactEmail'] as String?)
                                      ?.isNotEmpty ==
                                  true)
                                _InfoChip(
                                    icon: Icons.email_outlined,
                                    label:
                                        c['contactEmail'] as String),
                              if ((c['contactPhone'] as String?)
                                      ?.isNotEmpty ==
                                  true)
                                _InfoChip(
                                    icon: Icons.phone_outlined,
                                    label:
                                        c['contactPhone'] as String),
                              if ((c['city'] as String?)?.isNotEmpty ==
                                  true)
                                _InfoChip(
                                    icon: Icons.location_city_outlined,
                                    label: c['city'] as String),
                              if ((c['companySize'] as int?) != null)
                                _InfoChip(
                                    icon: Icons.people_outline,
                                    label:
                                        '${c['companySize']} employees'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        // ── Staggered entry animation ─────────────────────
        .animate()
        .fadeIn(
          delay: (widget.index * 55).ms,
          duration: 320.ms,
          curve: Curves.easeOut,
        )
        .slideX(
          begin: 0.12,
          delay: (widget.index * 55).ms,
          duration: 320.ms,
          curve: Curves.easeOut,
        );
  }
}

// ── Hoverable action icon ─────────────────────────────────────
class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color hoverColor;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.hoverColor,
  });

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.hoverColor.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: IconButton(
          icon: Icon(
            widget.icon,
            size: 18,
            color: _hovered ? widget.hoverColor : AppColors.muted,
          ),
          onPressed: widget.onTap,
          tooltip: widget.tooltip,
          padding: const EdgeInsets.all(6),
          constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const Gap(4),
          Text(label, style: AppTextStyles.caption),
        ],
      );
}

// ── Tier badge ────────────────────────────────────────────────
class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        tier[0].toUpperCase() + tier.substring(1),
        style: AppTextStyles.tag.copyWith(color: color),
      ),
    );
  }
}

// ── Shimmer skeleton loading ──────────────────────────────────
class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF9FAFB),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 114,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Pagination bar ────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int page;
  final int pages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.pages,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageBtn(
              icon: Icons.chevron_left,
              tooltip: 'Previous',
              onTap: onPrev),
          const Gap(12),
          Text('Page $page of $pages',
              style: AppTextStyles.caption),
          const Gap(12),
          _PageBtn(
              icon: Icons.chevron_right,
              tooltip: 'Next',
              onTap: onNext),
        ],
      ),
    );
  }
}

class _PageBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _PageBtn(
      {required this.icon,
      required this.tooltip,
      this.onTap});

  @override
  State<_PageBtn> createState() => _PageBtnState();
}

class _PageBtnState extends State<_PageBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered && enabled
              ? _kGrad0.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          icon: Icon(widget.icon,
              color: enabled
                  ? (_hovered ? _kGrad0 : AppColors.muted)
                  : AppColors.border),
          onPressed: widget.onTap,
          tooltip: widget.tooltip,
        ),
      ),
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.business_outlined,
              size: 56, color: AppColors.muted),
          const Gap(14),
          Text(message,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center),
        ]),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.97, 0.97),
            end: const Offset(1.01, 1.01),
            duration: 1800.ms,
            curve: Curves.easeInOut,
          );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline,
              size: 56, color: AppColors.danger),
          const Gap(14),
          Text(message,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.danger),
              textAlign: TextAlign.center),
          const Gap(16),
          OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry')),
        ]),
      ).animate().shake(
            hz: 3,
            offset: const Offset(4, 0),
            duration: 500.ms,
          );
}

// ── Customer Form Dialog ──────────────────────────────────────
const _kTiers = ['basic', 'standard', 'enterprise'];

const _kLanguages = <String, String>{
  'he': '🇮🇱  עברית (Hebrew)',
  'en': '🇬🇧  English',
  'es': '🇪🇸  Español',
  'fr': '🇫🇷  Français',
  'ru': '🇷🇺  Русский',
};

class _CustomerFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialCustomer;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _CustomerFormDialog(
      {this.initialCustomer, required this.onSave});

  @override
  State<_CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _industryCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _notesCtrl;
  String _tier = 'basic';
  String _language = 'he';
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialCustomer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCustomer;
    _nameCtrl =
        TextEditingController(text: c?['name'] as String? ?? '');
    _industryCtrl =
        TextEditingController(text: c?['industry'] as String? ?? '');
    _contactNameCtrl = TextEditingController(
        text: c?['contactName'] as String? ?? '');
    _contactEmailCtrl = TextEditingController(
        text: c?['contactEmail'] as String? ?? '');
    _contactPhoneCtrl = TextEditingController(
        text: c?['contactPhone'] as String? ?? '');
    _cityCtrl =
        TextEditingController(text: c?['city'] as String? ?? '');
    _notesCtrl =
        TextEditingController(text: c?['notes'] as String? ?? '');
    _tier = c?['subscriptionTier'] as String? ?? 'basic';
    _language = c?['language'] as String? ?? 'he';
    _isActive = c?['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _industryCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      if (_industryCtrl.text.trim().isNotEmpty)
        'industry': _industryCtrl.text.trim(),
      if (_contactNameCtrl.text.trim().isNotEmpty)
        'contact_name': _contactNameCtrl.text.trim(),
      if (_contactEmailCtrl.text.trim().isNotEmpty)
        'contact_email': _contactEmailCtrl.text.trim(),
      if (_contactPhoneCtrl.text.trim().isNotEmpty)
        'contact_phone': _contactPhoneCtrl.text.trim(),
      if (_cityCtrl.text.trim().isNotEmpty)
        'city': _cityCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
      'subscription_tier': _tier,
      'language': _language,
      if (_isEdit) 'is_active': _isActive,
    };

    try {
      await widget.onSave(body);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient header ────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kGrad0, _kGrad1],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded,
                      color: Colors.white, size: 22),
                  const Gap(10),
                  Text(
                    _isEdit ? 'Edit Customer' : 'Add Customer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),

            // ── Form body ─────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_error!,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.danger)),
                        ),
                        const Gap(12),
                      ],
                      _LabelField(
                          label: 'Company name *',
                          ctrl: _nameCtrl,
                          required: true),
                      const Gap(10),
                      Row(children: [
                        Expanded(
                          child: _LabelField(
                              label: 'Industry',
                              ctrl: _industryCtrl),
                        ),
                        const Gap(12),
                        Expanded(
                          child: _LabelField(
                              label: 'City', ctrl: _cityCtrl),
                        ),
                      ]),
                      const Gap(10),
                      _LabelField(
                          label: 'Contact name',
                          ctrl: _contactNameCtrl),
                      const Gap(10),
                      Row(children: [
                        Expanded(
                          child: _LabelField(
                              label: 'Contact email',
                              ctrl: _contactEmailCtrl,
                              keyboardType:
                                  TextInputType.emailAddress),
                        ),
                        const Gap(12),
                        Expanded(
                          child: _LabelField(
                              label: 'Contact phone',
                              ctrl: _contactPhoneCtrl,
                              keyboardType: TextInputType.phone),
                        ),
                      ]),
                      const Gap(10),
                      Text('Subscription tier',
                          style: AppTextStyles.label),
                      const Gap(4),
                      DropdownButtonFormField<String>(
                        value: _tier,
                        decoration:
                            const InputDecoration(isDense: true),
                        items: _kTiers
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _tierColor(t),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const Gap(8),
                                      Text(
                                        t[0].toUpperCase() +
                                            t.substring(1),
                                        style: AppTextStyles.body,
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _tier = v ?? _tier),
                      ),
                      const Gap(10),
                      Text('LLM output language',
                          style: AppTextStyles.label),
                      const Gap(4),
                      DropdownButtonFormField<String>(
                        value: _language,
                        decoration:
                            const InputDecoration(isDense: true),
                        items: _kLanguages.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value,
                                      style: AppTextStyles.body),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _language = v ?? _language),
                      ),
                      const Gap(10),
                      _LabelField(
                          label: 'Notes',
                          ctrl: _notesCtrl,
                          maxLines: 3),
                      if (_isEdit) ...[
                        const Gap(10),
                        Row(children: [
                          Switch(
                            value: _isActive,
                            activeColor: _kGrad0,
                            onChanged: (v) =>
                                setState(() => _isActive = v),
                          ),
                          const Gap(8),
                          Text(_isActive ? 'Active' : 'Inactive',
                              style: AppTextStyles.body),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Actions ───────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Gap(8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGrad0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(_isEdit
                            ? 'Save changes'
                            : 'Create customer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        // ── Dialog scale-in animation ─────────────────────
        .animate()
        .fadeIn(duration: 220.ms)
        .scale(
          begin: const Offset(0.93, 0.93),
          end: const Offset(1.0, 1.0),
          duration: 220.ms,
          curve: Curves.easeOutBack,
        );
  }
}

// ── Label + input helper ──────────────────────────────────────
class _LabelField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType? keyboardType;
  final bool required;
  final int maxLines;

  const _LabelField({
    required this.label,
    required this.ctrl,
    this.keyboardType,
    this.required = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const Gap(4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: AppTextStyles.body,
          decoration: const InputDecoration(isDense: true),
          validator: required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null,
        ),
      ],
    );
  }
}
