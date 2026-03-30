import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';

// ── Palette ───────────────────────────────────────────────────
const _kGrad1 = Color(0xFF1E3A8A);
const _kGrad2 = Color(0xFF3B82F6);

const _kRoleColors = {
  'regulit_admin': Color(0xFF1D4ED8),
  'csm': Color(0xFFEA580C),
  'regulit_analyst': Color(0xFF7C3AED),
  'client_admin': Color(0xFF0891B2),
  'it_executor': Color(0xFF059669),
  'employee': Color(0xFF6B7280),
};

Color _roleColor(String role) =>
    _kRoleColors[role] ?? const Color(0xFF6B7280);

// ── State ─────────────────────────────────────────────────────
class _UsersState {
  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int pages;
  final bool isLoading;
  final String? error;
  final String search;

  const _UsersState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    this.isLoading = true,
    this.error,
    this.search = '',
  });

  _UsersState copyWith({
    List<Map<String, dynamic>>? items,
    int? total,
    int? page,
    int? pages,
    bool? isLoading,
    String? error,
    String? search,
  }) =>
      _UsersState(
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        search: search ?? this.search,
      );
}

// ── Notifier ──────────────────────────────────────────────────
class _UsersNotifier extends StateNotifier<_UsersState> {
  final Dio _dio;
  _UsersNotifier(this._dio) : super(const _UsersState()) {
    load();
  }

  Future<void> load({String? search, int? page}) async {
    final s = search ?? state.search;
    final p = page ?? state.page;
    state = state.copyWith(isLoading: true, error: null, search: s, page: p);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/users',
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

  Future<void> createUser(Map<String, dynamic> body) async {
    await _dio.post<dynamic>('/users', data: body);
    await load();
  }

  Future<void> updateUser(String id, Map<String, dynamic> body) async {
    await _dio.put<dynamic>('/users/$id', data: body);
    await load();
  }

  Future<void> deactivateUser(String id) async {
    await _dio.delete<dynamic>('/users/$id');
    await load();
  }
}

final _usersProvider =
    StateNotifierProvider.autoDispose<_UsersNotifier, _UsersState>(
        (ref) => _UsersNotifier(ref.watch(dioProvider)));

// ── Screen ────────────────────────────────────────────────────
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});
  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String q) =>
      ref.read(_usersProvider.notifier).load(search: q, page: 1);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_usersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Gradient Header ──────────────────────────────────
          _GradientHeader(
            title: 'Users',
            subtitle: s.isLoading
                ? 'Loading…'
                : '${s.total} user${s.total == 1 ? '' : 's'} in the system',
            icon: Icons.people_rounded,
            onAdd: () => _showUserForm(context, null),
            addLabel: 'Add User',
            searchCtrl: _searchCtrl,
            searchHint: 'Search by name or email…',
            onSearch: _search,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.06, end: 0),

          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: s.isLoading
                ? const _ShimmerList()
                : s.error != null
                    ? _ErrorView(
                        message: s.error!,
                        onRetry: () =>
                            ref.read(_usersProvider.notifier).load(),
                      )
                    : s.items.isEmpty
                        ? _EmptyView(
                            icon: Icons.people_outline,
                            message: s.search.isEmpty
                                ? 'No users yet.\nAdd the first one!'
                                : 'No results for "${s.search}".',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: s.items.length,
                            itemBuilder: (_, i) {
                              final u = s.items[i];
                              return _UserCard(
                                user: u,
                                index: i,
                                onEdit: () => _showUserForm(context, u),
                                onDeactivate: u['isActive'] == true
                                    ? () => _confirmDeactivate(
                                          context,
                                          u['id'] as String,
                                          u['fullName'] as String,
                                        )
                                    : null,
                              );
                            },
                          ),
          ),

          // ── Pagination ───────────────────────────────────────
          if (!s.isLoading && s.error == null && s.pages > 1)
            _PaginationBar(
              page: s.page,
              pages: s.pages,
              onPrev: s.page > 1
                  ? () => ref
                      .read(_usersProvider.notifier)
                      .load(page: s.page - 1)
                  : null,
              onNext: s.page < s.pages
                  ? () => ref
                      .read(_usersProvider.notifier)
                      .load(page: s.page + 1)
                  : null,
            ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  void _showUserForm(BuildContext context, Map<String, dynamic>? user) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserFormDialog(
        initialUser: user,
        onSave: (body) async {
          final n = ref.read(_usersProvider.notifier);
          if (user == null) {
            await n.createUser(body);
          } else {
            await n.updateUser(user['id'] as String, body);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate user'),
        content: Text('$name will no longer be able to log in. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ref.read(_usersProvider.notifier).deactivateUser(id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    }
  }
}

// ── Gradient Header ───────────────────────────────────────────
class _GradientHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onAdd;
  final String addLabel;
  final TextEditingController searchCtrl;
  final String searchHint;
  final ValueChanged<String> onSearch;

  const _GradientHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onAdd,
    required this.addLabel,
    required this.searchCtrl,
    required this.searchHint,
    required this.onSearch,
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
          colors: [_kGrad1, _kGrad2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x331E3A8A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            )),
                        Text(widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                  _AnimatedAddButton(
                    label: widget.addLabel,
                    onTap: widget.onAdd,
                  ),
                ],
              ),
              const Gap(14),
              // Search bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: TextField(
                  controller: widget.searchCtrl,
                  onChanged: widget.onSearch,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.55), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.7), size: 18),
                    suffixIcon: widget.searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close,
                                color: Colors.white.withOpacity(0.7), size: 16),
                            onPressed: () {
                              widget.searchCtrl.clear();
                              widget.onSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 11),
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

// ── Animated Add Button ───────────────────────────────────────
class _AnimatedAddButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _AnimatedAddButton({required this.label, required this.onTap});

  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, size: 16, color: _kGrad1),
            const Gap(6),
            Text(
              widget.label,
              style: const TextStyle(
                color: _kGrad1,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 2200.ms,
          delay: 1500.ms,
          color: Colors.white.withOpacity(0.6),
        );
  }
}

// ── User Card ─────────────────────────────────────────────────
class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  const _UserCard({
    required this.user,
    required this.index,
    required this.onEdit,
    this.onDeactivate,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final isActive = u['isActive'] as bool? ?? true;
    final role = u['roleName'] as String? ?? '';
    final color = _roleColor(role);
    final initials = ((u['fullName'] as String? ?? '?')
            .trim()
            .split(' ')
            .map((w) => w.isEmpty ? '' : w[0])
            .take(2)
            .join())
        .toUpperCase();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: isActive ? color : AppColors.muted,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? color.withOpacity(0.18)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _hovered ? 20 : 6,
              offset: Offset(0, _hovered ? 6 : 2),
            ),
          ],
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _hovered
                      ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const Gap(14),

              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        u['fullName'] as String? ?? '—',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (!isActive) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Inactive',
                              style: AppTextStyles.tag
                                  .copyWith(color: AppColors.danger)),
                        ),
                      ],
                    ]),
                    const Gap(2),
                    Text(
                      u['email'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              // Role badge
              _RoleBadge(role: role, color: color),
              const Gap(8),

              // Actions
              _ActionIcon(
                icon: Icons.edit_outlined,
                color: _kGrad2,
                tooltip: 'Edit',
                onTap: widget.onEdit,
              ),
              if (widget.onDeactivate != null) ...[
                const Gap(4),
                _ActionIcon(
                  icon: Icons.person_off_outlined,
                  color: AppColors.danger,
                  tooltip: 'Deactivate',
                  onTap: widget.onDeactivate!,
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 380.ms,
          delay: (widget.index * 55).ms,
          curve: Curves.easeOut,
        )
        .slideX(
          begin: 0.12,
          end: 0,
          duration: 380.ms,
          delay: (widget.index * 55).ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ── Action Icon Button ────────────────────────────────────────
class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionIcon(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _hov
                  ? widget.color.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon,
                size: 17, color: _hov ? widget.color : Colors.grey[400]),
          ),
        ),
      ),
    );
  }
}

// ── Role Badge ────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final String role;
  final Color color;
  const _RoleBadge({required this.role, required this.color});

  String get _label => switch (role) {
        'regulit_admin' => 'Admin',
        'csm' => 'CSM',
        'regulit_analyst' => 'Analyst',
        'client_admin' => 'CEO',
        'it_executor' => 'IT',
        'employee' => 'Employee',
        _ => role,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Shimmer Loading ───────────────────────────────────────────
class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 7,
        itemBuilder: (_, __) => Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Pagination Bar ────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageBtn(
              icon: Icons.chevron_left_rounded,
              onTap: onPrev,
              enabled: onPrev != null),
          const Gap(16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _kGrad1.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Page $page of $pages',
              style: const TextStyle(
                color: _kGrad1,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Gap(16),
          _PageBtn(
              icon: Icons.chevron_right_rounded,
              onTap: onNext,
              enabled: onNext != null),
        ],
      ),
    );
  }
}

class _PageBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  const _PageBtn(
      {required this.icon, required this.onTap, required this.enabled});

  @override
  State<_PageBtn> createState() => _PageBtnState();
}

class _PageBtnState extends State<_PageBtn> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hov && widget.enabled
                ? _kGrad1.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.enabled
                  ? _kGrad1.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.enabled ? _kGrad1 : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}

// ── Empty View ────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kGrad1.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 48, color: _kGrad1.withOpacity(0.5)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.06, 1.06),
              duration: 1800.ms,
              curve: Curves.easeInOut,
            ),
        const Gap(20),
        Text(
          message,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ]),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.85, 0.85), duration: 400.ms, curve: Curves.easeOutBack);
  }
}

// ── Error View ────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline_rounded,
              size: 40, color: AppColors.danger),
        )
            .animate(onPlay: (c) => c.repeat())
            .shake(duration: 600.ms, delay: 1000.ms, hz: 3),
        const Gap(16),
        Text(message,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
            textAlign: TextAlign.center),
        const Gap(20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

// ── User Form Dialog ──────────────────────────────────────────
const _kRoles = [
  ('regulit_admin', 'Regulit Admin'),
  ('csm', 'Customer Success Manager'),
  ('regulit_analyst', 'Compliance Analyst'),
  ('client_admin', 'Client Admin (CEO)'),
  ('it_executor', 'IT Manager'),
  ('employee', 'Employee'),
];

class _UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initialUser;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  const _UserFormDialog({this.initialUser, required this.onSave});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passCtrl;
  String _roleName = 'employee';
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialUser != null;

  @override
  void initState() {
    super.initState();
    final u = widget.initialUser;
    _firstCtrl = TextEditingController(text: u?['firstname'] as String? ?? '');
    _lastCtrl = TextEditingController(text: u?['lastname'] as String? ?? '');
    _emailCtrl = TextEditingController(text: u?['email'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: u?['phone'] as String? ?? '');
    _passCtrl = TextEditingController();
    _roleName = u?['roleName'] as String? ?? 'employee';
    _isActive = u?['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'firstname': _firstCtrl.text.trim(),
      'lastname': _lastCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'role_name': _roleName,
      if (!_isEdit) 'email': _emailCtrl.text.trim(),
      if (!_isEdit && _passCtrl.text.isNotEmpty) 'password': _passCtrl.text,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_kGrad1, _kGrad2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Row(children: [
                Icon(_isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                    color: Colors.white, size: 20),
                const Gap(10),
                Text(
                  _isEdit ? 'Edit User' : 'Add User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),

            // Form body
            SizedBox(
              width: 440,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_error!,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.danger)),
                          )
                              .animate()
                              .shake(duration: 400.ms)
                              .fadeIn(duration: 200.ms),
                          const Gap(12),
                        ],
                        Row(children: [
                          Expanded(
                              child: _Field(
                                  label: 'First name',
                                  ctrl: _firstCtrl,
                                  required: true)),
                          const Gap(12),
                          Expanded(
                              child: _Field(
                                  label: 'Last name',
                                  ctrl: _lastCtrl,
                                  required: true)),
                        ]),
                        const Gap(12),
                        if (!_isEdit) ...[
                          _Field(
                            label: 'Email',
                            ctrl: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            required: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const Gap(12),
                          _Field(
                            label: 'Password',
                            ctrl: _passCtrl,
                            obscure: true,
                            required: true,
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return 'At least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const Gap(12),
                        ],
                        _Field(
                            label: 'Phone (optional)',
                            ctrl: _phoneCtrl,
                            keyboardType: TextInputType.phone),
                        const Gap(12),
                        Text('Role', style: AppTextStyles.label),
                        const Gap(4),
                        DropdownButtonFormField<String>(
                          value: _roleName,
                          decoration: const InputDecoration(isDense: true),
                          items: _kRoles
                              .map((r) => DropdownMenuItem(
                                    value: r.$1,
                                    child: Text(r.$2,
                                        style: AppTextStyles.body),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _roleName = v ?? _roleName),
                        ),
                        if (_isEdit) ...[
                          const Gap(12),
                          Row(children: [
                            Switch(
                              value: _isActive,
                              activeColor: AppColors.orange,
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
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Gap(8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGrad1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_isEdit ? 'Save Changes' : 'Create User'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
        begin: const Offset(0.93, 0.93),
        duration: 250.ms,
        curve: Curves.easeOutBack);
  }
}

// ── Reusable form field ───────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType? keyboardType;
  final bool required;
  final bool obscure;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.ctrl,
    this.keyboardType,
    this.required = false,
    this.obscure = false,
    this.validator,
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
          obscureText: obscure,
          style: AppTextStyles.body,
          decoration: const InputDecoration(isDense: true),
          validator: validator ??
              (required
                  ? (v) => (v == null || v.isEmpty) ? 'Required' : null
                  : null),
        ),
      ],
    );
  }
}
