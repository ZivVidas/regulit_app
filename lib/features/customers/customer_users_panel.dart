/// Bottom-sheet / dialog for managing which users are linked to a customer.
/// Opened from the customer card → "Manage Users" button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_localizations.dart';

// ── Colour constants ──────────────────────────────────────────
const _kGrad0 = Color(0xFFEA580C);
const _kGrad1 = Color(0xFFF97316);

const _kClientRoles = ['client_admin', 'it_executor', 'employee'];

// ─────────────────────────────────────────────────────────────
// State / Notifier (linked-users list)
// ─────────────────────────────────────────────────────────────

class _PanelState {
  final List<Map<String, dynamic>> links;
  final bool isLoading;
  final String? error;

  const _PanelState({
    this.links = const [],
    this.isLoading = true,
    this.error,
  });

  _PanelState copyWith({
    List<Map<String, dynamic>>? links,
    bool? isLoading,
    String? error,
  }) =>
      _PanelState(
        links: links ?? this.links,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class _PanelNotifier extends StateNotifier<_PanelState> {
  final dynamic _dio;
  final String customerId;

  _PanelNotifier(this._dio, this.customerId) : super(const _PanelState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res =
          await _dio.get<List<dynamic>>('/customers/$customerId/users');
      state = state.copyWith(
        isLoading: false,
        links: (res.data as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> linkUser(String userId, String role) async {
    await _dio.post<dynamic>(
      '/customers/$customerId/users',
      data: {'user_id': userId, 'role': role},
    );
    await load();
  }

  Future<void> unlink(String userId) async {
    await _dio.delete<dynamic>('/customers/$customerId/users/$userId');
    await load();
  }

  Future<void> updateRole(String userId, String role) async {
    await _dio.patch<dynamic>(
      '/customers/$customerId/users/$userId',
      data: {'role': role},
    );
    await load();
  }
}

// ─────────────────────────────────────────────────────────────
// Entry point — call this from the customer card
// ─────────────────────────────────────────────────────────────

void showCustomerUsersPanel(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> customer,
) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: CustomerUsersPanel(customer: customer),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Panel widget
// ─────────────────────────────────────────────────────────────

class CustomerUsersPanel extends ConsumerStatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerUsersPanel({super.key, required this.customer});

  @override
  ConsumerState<CustomerUsersPanel> createState() =>
      _CustomerUsersPanelState();
}

class _CustomerUsersPanelState extends ConsumerState<CustomerUsersPanel> {
  late final StateNotifierProvider<_PanelNotifier, _PanelState> _provider;

  // ── Link-form state ─────────────────────────────────────────
  bool _linking = false;
  List<Map<String, dynamic>> _availableUsers = [];
  bool _loadingUsers = false;
  Map<String, dynamic>? _selectedUser;
  String _selectedRole = 'client_admin';
  bool _saving = false;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    final cid = widget.customer['id'] as String;
    _provider = StateNotifierProvider<_PanelNotifier, _PanelState>(
      (r) => _PanelNotifier(r.watch(dioProvider), cid),
    );
  }

  // ── Open the inline link form ───────────────────────────────
  Future<void> _startLinking() async {
    setState(() {
      _linking = true;
      _loadingUsers = true;
      _selectedUser = null;
      _selectedRole = 'client_admin';
      _linkError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get<Map<String, dynamic>>(
        '/users',
        queryParameters: {'page': 1, 'page_size': 500},
      );
      final allUsers =
          ((res.data!['items']) as List).cast<Map<String, dynamic>>();

      // Exclude already-linked users
      final linkedIds =
          ref.read(_provider).links.map((l) => l['userId'] as String).toSet();

      setState(() {
        _availableUsers =
            allUsers.where((u) => !linkedIds.contains(u['id'])).toList();
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _loadingUsers = false;
        _linking = false;
      });
    }
  }

  void _cancelLinking() => setState(() {
        _linking = false;
        _linkError = null;
        _selectedUser = null;
      });

  // ── Submit the link ─────────────────────────────────────────
  Future<void> _submitLink() async {
    final user = _selectedUser;
    if (user == null) return;

    setState(() {
      _saving = true;
      _linkError = null;
    });

    try {
      await ref
          .read(_provider.notifier)
          .linkUser(user['id'] as String, _selectedRole);
      setState(() {
        _linking = false;
        _saving = false;
        _selectedUser = null;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _linkError =
            e.toString().replaceAll('DioException [bad response]:', '').trim();
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_provider);
    final customerName =
        widget.customer['name'] as String? ?? 'Customer';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────
            _buildHeader(context, customerName),

            // ── Linked users list ─────────────────────────────
            ConstrainedBox(
              // Shrink list height when the form is open
              constraints: BoxConstraints(maxHeight: _linking ? 200 : 440),
              child: _buildLinkedList(s),
            ),

            // ── Inline link form (shown when _linking = true) ─
            if (_linking) _buildLinkForm(),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .scale(
          begin: const Offset(0.93, 0.93),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, String customerName) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGrad0, _kGrad1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, color: Colors.white, size: 22),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.linkedUsers,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Text(
                  customerName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Toggle link form
          IconButton(
            icon: Icon(
              _linking ? Icons.close : Icons.person_add_outlined,
              color: Colors.white,
            ),
            tooltip: _linking ? l10n.cancel : l10n.linkAUser,
            onPressed:
                _linking ? _cancelLinking : _startLinking,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  // ── Linked users list ────────────────────────────────────────
  Widget _buildLinkedList(_PanelState s) {
    final l10n = AppLocalizations.of(context);
    if (s.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (s.error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 40),
            const Gap(10),
            Text(s.error!,
                style: AppTextStyles.body.copyWith(color: AppColors.danger),
                textAlign: TextAlign.center),
            const Gap(14),
            OutlinedButton(
              onPressed: () => ref.read(_provider.notifier).load(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (s.links.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_off_outlined,
                size: 48, color: AppColors.muted),
            const Gap(12),
            Text(l10n.noUsersLinked,
                style:
                    AppTextStyles.body.copyWith(color: AppColors.muted)),
            const Gap(16),
            FilledButton.icon(
              style:
                  FilledButton.styleFrom(backgroundColor: _kGrad0),
              onPressed: _linking ? null : _startLinking,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: Text(l10n.linkFirstUser),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: s.links.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final link = s.links[i];
        return _LinkTile(
          link: link,
          index: i,
          onRoleChanged: (role) => ref
              .read(_provider.notifier)
              .updateRole(link['userId'] as String, role),
          onUnlink: () => ref
              .read(_provider.notifier)
              .unlink(link['userId'] as String),
        );
      },
    );
  }

  // ── Inline link form ─────────────────────────────────────────
  Widget _buildLinkForm() {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Section label ────────────────────────────
              Row(
                children: [
                  const Icon(Icons.person_add_outlined,
                      size: 16, color: _kGrad0),
                  const Gap(6),
                  Text(l10n.linkAUser,
                      style: AppTextStyles.h4
                          .copyWith(color: _kGrad0)),
                ],
              ),
              const Gap(14),

              // ── Error banner ─────────────────────────────
              if (_linkError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_linkError!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.danger)),
                ),
                const Gap(10),
              ],

              // ── Autocomplete user search ──────────────────
              Text(l10n.searchUser, style: AppTextStyles.label),
              const Gap(4),
              _loadingUsers
                  ? const LinearProgressIndicator()
                  : _UserAutocomplete(
                      users: _availableUsers,
                      onSelected: (u) =>
                          setState(() => _selectedUser = u),
                    ),
              const Gap(14),

              // ── Role selector ─────────────────────────────
              Text(l10n.roleLabel, style: AppTextStyles.label),
              const Gap(4),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(isDense: true),
                items: _kClientRoles
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_roleLabel(r, l10n),
                              style: AppTextStyles.body),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedRole = v ?? _selectedRole),
              ),
              const Gap(16),

              // ── Actions ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : _cancelLinking,
                    child: Text(l10n.cancel),
                  ),
                  const Gap(8),
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: _kGrad0),
                    onPressed: (_saving || _selectedUser == null)
                        ? null
                        : _submitLink,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.link, size: 16),
                    label: Text(l10n.link),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Autocomplete widget for user search ──────────────────────
/// Stateless: Autocomplete manages its own internal TextEditingController.
class _UserAutocomplete extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _UserAutocomplete({
    required this.users,
    required this.onSelected,
  });

  static String _displayFor(Map<String, dynamic> u) {
    final name = u['fullName'] as String? ?? '';
    final email = u['email'] as String? ?? '';
    return '$name ($email)';
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.toLowerCase().trim();
        if (q.isEmpty) return users.take(10);
        return users.where((u) {
          final name = (u['fullName'] as String? ?? '').toLowerCase();
          final email = (u['email'] as String? ?? '').toLowerCase();
          return name.contains(q) || email.contains(q);
        });
      },
      displayStringForOption: _displayFor,
      onSelected: onSelected,
      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onFieldSubmitted(),
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(ctx).typeNameOrEmail,
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
          ),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 460, maxHeight: 220),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = options.elementAt(i);
                    final name = u['fullName'] as String? ?? '—';
                    final email = u['email'] as String? ?? '';
                    final initials = name.isNotEmpty
                        ? name
                            .trim()
                            .split(' ')
                            .where((w) => w.isNotEmpty)
                            .map((w) => w[0])
                            .take(2)
                            .join()
                            .toUpperCase()
                        : '?';

                    return InkWell(
                      onTap: () => onSelected(u),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  AppColors.blue.withOpacity(0.10),
                              child: Text(
                                initials,
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  Text(email,
                                      style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Linked-user tile ──────────────────────────────────────────
class _LinkTile extends StatelessWidget {
  final Map<String, dynamic> link;
  final int index;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onUnlink;

  const _LinkTile({
    required this.link,
    required this.index,
    required this.onRoleChanged,
    required this.onUnlink,
  });

  static const _roleColors = {
    'client_admin': Color(0xFF0891B2),
    'it_executor': Color(0xFF059669),
    'employee': Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = link['userName'] as String? ?? '—';
    final email = link['userEmail'] as String? ?? '';
    final role = link['role'] as String? ?? 'employee';
    final color = _roleColors[role] ?? const Color(0xFF9CA3AF);

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ),
      title: Text(name,
          style:
              AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(email, style: AppTextStyles.caption),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Role dropdown
          DropdownButton<String>(
            value: role,
            underline: const SizedBox(),
            isDense: true,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w600),
            items: _kClientRoles
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(_roleLabel(r, l10n),
                          style: AppTextStyles.caption),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onRoleChanged(v);
            },
          ),
          const Gap(4),
          IconButton(
            icon: const Icon(Icons.link_off_outlined,
                size: 18, color: AppColors.danger),
            tooltip: l10n.unlink,
            onPressed: onUnlink,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 40).ms, duration: 280.ms)
        .slideX(begin: 0.08, delay: (index * 40).ms, duration: 280.ms);
  }
}

// ── Helpers ───────────────────────────────────────────────────
String _roleLabel(String role, AppLocalizations l10n) => switch (role) {
      'client_admin' => l10n.roleClientAdmin,
      'it_executor'  => l10n.roleItExecutor,
      'employee'     => l10n.roleEmployee,
      _              => role,
    };
