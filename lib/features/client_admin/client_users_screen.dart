/// Full-page user-management screen for client_admin.
/// Shows users linked to the current customer; supports create + link,
/// role change, and unlink.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../l10n/app_localizations.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGrad0 = Color(0xFF1E40AF);
const _kGrad1 = Color(0xFF3B82F6);

const _kClientRoles = ['client_admin', 'it_executor', 'employee'];

const _kRoleColors = {
  'client_admin': Color(0xFF0891B2),
  'it_executor':  Color(0xFF059669),
  'employee':     Color(0xFF6B7280),
};

Color _roleColor(String r) => _kRoleColors[r] ?? const Color(0xFF6B7280);

// ── State / Notifier ──────────────────────────────────────────────────────────
class _State {
  final List<Map<String, dynamic>> users;
  final bool loading;
  final String? error;

  const _State({this.users = const [], this.loading = true, this.error});

  _State copyWith({
    List<Map<String, dynamic>>? users,
    bool? loading,
    String? error,
  }) =>
      _State(
        users: users ?? this.users,
        loading: loading ?? this.loading,
        error: error,
      );
}

class _Notifier extends StateNotifier<_State> {
  final dynamic _dio;
  final String customerId;

  _Notifier(this._dio, this.customerId) : super(const _State()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _dio.get<List<dynamic>>('/customers/$customerId/users');
      state = state.copyWith(
        loading: false,
        users: (res.data as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> updateRole(String userId, String role) async {
    await _dio.patch<dynamic>(
      '/customers/$customerId/users/$userId',
      data: {'role': role},
    );
    await load();
  }

  Future<void> unlink(String userId) async {
    await _dio.delete<dynamic>('/customers/$customerId/users/$userId');
    await load();
  }

  Future<void> linkUser(String userId, String role) async {
    await _dio.post<dynamic>(
      '/customers/$customerId/users',
      data: {'user_id': userId, 'role': role},
    );
    await load();
  }

  Future<void> createAndLink({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
    required String role,
  }) async {
    // 1. create user (no global role — the link gives the role)
    final created = await _dio.post<Map<String, dynamic>>(
      '/users',
      data: {
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'password': password,
      },
    );
    final userId = (created.data!['id'] as String);
    // 2. link to this customer with the chosen role
    await _dio.post<dynamic>(
      '/customers/$customerId/users',
      data: {'user_id': userId, 'role': role},
    );
    await load();
  }
}

// ── Provider (autoDispose so it never leaks between user sessions) ───────────
final _usersProvider =
    StateNotifierProvider.autoDispose.family<_Notifier, _State, String>(
  (ref, customerId) => _Notifier(ref.watch(dioProvider), customerId),
);

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class ClientUsersScreen extends ConsumerWidget {
  const ClientUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(customerContextProvider);
    final customerId = ctx?['customerId'] as String? ?? '';
    final customerName = ctx?['customerName'] as String? ?? '';
    final l10n = AppLocalizations.of(context);

    if (customerId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final state = ref.watch(_usersProvider(customerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────
          _Header(
            customerName: customerName,
            l10n: l10n,
            onAdd: () => _showAddDialog(context, ref, customerId, l10n),
          ),

          // ── Body ─────────────────────────────────────────────────
          Expanded(
            child: _buildBody(context, ref, state, customerId, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    _State state,
    String customerId,
    AppLocalizations l10n,
  ) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const Gap(12),
            Text(state.error!, textAlign: TextAlign.center),
            const Gap(16),
            FilledButton(
              onPressed: () => ref.read(_usersProvider(customerId).notifier).load(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_off_outlined, size: 64, color: AppColors.muted),
            const Gap(16),
            Text(l10n.noUsersLinked,
                style: AppTextStyles.body.copyWith(color: AppColors.muted)),
            const Gap(20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kGrad0),
              onPressed: () => _showAddDialog(
                  context, ref, customerId, l10n),
              icon: const Icon(Icons.person_add_outlined),
              label: Text(l10n.addUser),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: state.users.length,
      separatorBuilder: (_, __) => const Gap(12),
      itemBuilder: (context, i) {
        final u = state.users[i];
        return _UserCard(
          user: u,
          onRoleChanged: (role) => ref
              .read(_usersProvider(customerId).notifier)
              .updateRole(u['userId'] as String, role),
          onUnlink: () => _confirmUnlink(context, ref, customerId, u, l10n),
        ).animate().fadeIn(duration: 200.ms, delay: (i * 40).ms);
      },
    );
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    WidgetRef ref,
    String customerId,
    Map<String, dynamic> user,
    AppLocalizations l10n,
  ) async {
    final name = user['userName'] as String? ?? user['userEmail'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.unlink),
        content: Text('Remove $name from this organisation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.unlink),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(_usersProvider(customerId).notifier)
          .unlink(user['userId'] as String);
    }
  }

  Future<void> _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    String customerId,
    AppLocalizations l10n,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _AddUserDialog(customerId: customerId),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String customerName;
  final AppLocalizations l10n;
  final VoidCallback onAdd;

  const _Header({
    required this.customerName,
    required this.l10n,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad0, _kGrad1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, color: Colors.white, size: 28),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.navUsers,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  customerName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _kGrad0,
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: Text(l10n.addUser),
          ),
        ],
      ),
    );
  }
}

// ── User card ─────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onUnlink;

  const _UserCard({
    required this.user,
    required this.onRoleChanged,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name  = user['userName']  as String? ?? '';
    final email = user['userEmail'] as String? ?? '';
    final role  = user['role']      as String? ?? '';
    final initials = _initials(name);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: _roleColor(role).withOpacity(0.15),
              child: Text(
                initials,
                style: TextStyle(
                  color: _roleColor(role),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const Gap(14),
            // Name + email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  const Gap(2),
                  Text(email,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            // Role dropdown
            DropdownButton<String>(
              value: _kClientRoles.contains(role) ? role : _kClientRoles.first,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(8),
              items: _kClientRoles
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: _RoleChip(role: r),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null && v != role) onRoleChanged(v);
              },
            ),
            const Gap(8),
            // Unlink button
            IconButton(
              icon: const Icon(Icons.link_off_outlined, size: 20),
              color: AppColors.danger,
              tooltip: l10n.unlink,
              onPressed: onUnlink,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _roleColor(role).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _roleLabel(role, l10n),
        style: TextStyle(
          color: _roleColor(role),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _roleLabel(String r, AppLocalizations l10n) {
  switch (r) {
    case 'client_admin': return l10n.roleClientAdmin;
    case 'it_executor':  return l10n.roleItExecutor;
    case 'employee':     return l10n.roleEmployee;
    default:             return r;
  }
}

// ── Add User Dialog ──────────────────────────────────────────────────────────
class _AddUserDialog extends ConsumerStatefulWidget {
  final String customerId;
  const _AddUserDialog({required this.customerId});

  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kGrad0, _kGrad1],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add_outlined,
                          color: Colors.white, size: 20),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          l10n.addUser,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Gap(8),
                  TabBar(
                    controller: _tabs,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorColor: Colors.white,
                    tabs: [
                      Tab(text: l10n.newUser),
                      Tab(text: l10n.existingUser),
                    ],
                  ),
                ],
              ),
            ),
            // Tab body
            SizedBox(
              height: 380,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _NewUserTab(customerId: widget.customerId),
                  _ExistingUserTab(customerId: widget.customerId),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 180.ms)
        .scale(
          begin: const Offset(0.93, 0.93),
          duration: 180.ms,
          curve: Curves.easeOutBack,
        );
  }
}

// ── Tab: Create new user ──────────────────────────────────────────────────────
class _NewUserTab extends ConsumerStatefulWidget {
  final String customerId;
  const _NewUserTab({required this.customerId});

  @override
  ConsumerState<_NewUserTab> createState() => _NewUserTabState();
}

class _NewUserTabState extends ConsumerState<_NewUserTab> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl  = TextEditingController();
  final _lastCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _pwCtrl     = TextEditingController();
  String _role = 'employee';
  bool _saving = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ref
          .read(_usersProvider(widget.customerId).notifier)
          .createAndLink(
            firstname: _firstCtrl.text.trim(),
            lastname:  _lastCtrl.text.trim(),
            email:     _emailCtrl.text.trim(),
            password:  _pwCtrl.text,
            role:      _role,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('DioException [bad response]:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.firstName,
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.required : null,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: TextFormField(
                    controller: _lastCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.lastName,
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.required : null,
                  ),
                ),
              ],
            ),
            const Gap(14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.emailAddress,
                isDense: true,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.required;
                if (!v.contains('@')) return l10n.enterValidEmail;
                return null;
              },
            ),
            const Gap(14),
            TextFormField(
              controller: _pwCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.password,
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.required;
                if (v.length < 8) return l10n.atLeast8Chars;
                return null;
              },
            ),
            const Gap(14),
            Text(l10n.roleLabel, style: AppTextStyles.label),
            const Gap(4),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(isDense: true),
              items: _kClientRoles
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_roleLabel(r, l10n)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const Gap(20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const Gap(10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _kGrad0),
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_add_outlined, size: 16),
                  label: Text(l10n.createAndLink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Link existing user ───────────────────────────────────────────────────
class _ExistingUserTab extends ConsumerStatefulWidget {
  final String customerId;
  const _ExistingUserTab({required this.customerId});

  @override
  ConsumerState<_ExistingUserTab> createState() => _ExistingUserTabState();
}

class _ExistingUserTabState extends ConsumerState<_ExistingUserTab> {
  List<Map<String, dynamic>> _allUsers = [];
  bool _loadingUsers = false;
  Map<String, dynamic>? _selected;
  String _role = 'employee';
  bool _saving = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get<Map<String, dynamic>>(
        '/users',
        queryParameters: {'page': 1, 'page_size': 500},
      );
      final all = ((res.data!['items']) as List).cast<Map<String, dynamic>>();
      // Exclude already-linked users
      final linkedIds = ref
          .read(_usersProvider(widget.customerId))
          .users
          .map((u) => u['userId'] as String)
          .toSet();
      setState(() {
        _allUsers = all.where((u) => !linkedIds.contains(u['id'])).toList();
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() => _loadingUsers = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _allUsers;
    return _allUsers.where((u) {
      return (u['fullName'] as String? ?? '')
              .toLowerCase()
              .contains(q) ||
          (u['email'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _submit() async {
    final user = _selected;
    if (user == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ref
          .read(_usersProvider(widget.customerId).notifier)
          .linkUser(user['id'] as String, _role);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('DioException [bad response]:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
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
            const Gap(10),
          ],
          // Search field
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.typeNameOrEmail,
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
          ),
          const Gap(10),
          // User list
          Expanded(
            child: _loadingUsers
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(child: Text(l10n.noResults))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final u = _filtered[i];
                          final isSelected = _selected?['id'] == u['id'];
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: _kGrad0.withOpacity(0.08),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: _kGrad0.withOpacity(0.15),
                              child: Text(
                                _initials(u['fullName'] as String? ?? ''),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _kGrad0),
                              ),
                            ),
                            title: Text(u['fullName'] as String? ?? '',
                                style: AppTextStyles.body),
                            subtitle: Text(u['email'] as String? ?? '',
                                style: AppTextStyles.bodySmall),
                            onTap: () => setState(() => _selected = u),
                          );
                        },
                      ),
          ),
          const Gap(10),
          // Role selector
          Row(
            children: [
              Text(l10n.roleLabel, style: AppTextStyles.label),
              const Gap(12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(isDense: true),
                  items: _kClientRoles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(_roleLabel(r, l10n)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
              ),
            ],
          ),
          const Gap(14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              const Gap(10),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kGrad0),
                onPressed: (_saving || _selected == null) ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link_outlined, size: 16),
                label: Text(l10n.link),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isEmpty ? '?' : parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
