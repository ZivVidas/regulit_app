/// Sub-panel embedded inside the customer add/edit dialog. Lets the user
/// list, add, rename, and delete a customer's data environments.
///
/// See:
///   * gap_data_environments_design.md §6.1
///   * gap_data_environments_dev_plan.md Phase 9
///
/// Surfaced only when editing an existing customer (env CRUD requires
/// a customer_id; new customers haven't been POSTed yet). The parent
/// dialog handles that gating.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_localizations.dart';

class CustomerDataEnvironmentsPanel extends ConsumerStatefulWidget {
  /// UUID of the customer whose envs we manage.
  final String customerId;

  /// Fired whenever the env count changes (add/delete). The parent dialog
  /// uses this to refresh the read-only "Number of Data Environments"
  /// counter shown at the top of the form.
  final ValueChanged<int>? onCountChanged;

  const CustomerDataEnvironmentsPanel({
    super.key,
    required this.customerId,
    this.onCountChanged,
  });

  @override
  ConsumerState<CustomerDataEnvironmentsPanel> createState() =>
      _CustomerDataEnvironmentsPanelState();
}

class _CustomerDataEnvironmentsPanelState
    extends ConsumerState<CustomerDataEnvironmentsPanel> {
  List<Map<String, dynamic>> _envs = const [];
  bool _loading = true;
  String? _error;

  // Inline "add" form state.
  bool _addOpen = false;
  final _addCtrl = TextEditingController();
  bool _adding = false;

  // Inline "rename" state — keyed by env id.
  String? _renameEnvId;
  final _renameCtrl = TextEditingController();
  bool _renaming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _renameCtrl.dispose();
    super.dispose();
  }

  String get _basePath =>
      '/customers/${widget.customerId}/data-environments';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioProvider).get<dynamic>(_basePath);
      final list = (res.data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _envs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _dioMessage(e);
      });
    }
  }

  Future<void> _add() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ref.read(dioProvider).post<dynamic>(
            _basePath,
            data: <String, dynamic>{'envName': name},
          );
      _addCtrl.clear();
      if (mounted) {
        setState(() {
          _addOpen = false;
          _adding = false;
        });
      }
      await _load();
      widget.onCountChanged?.call(_envs.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      _showSnack(_dioMessage(e), isError: true);
    }
  }

  Future<void> _rename(String envId) async {
    final name = _renameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _renaming = true);
    try {
      await ref.read(dioProvider).patch<dynamic>(
            '$_basePath/$envId',
            data: <String, dynamic>{'envName': name},
          );
      if (mounted) {
        setState(() {
          _renameEnvId = null;
          _renaming = false;
        });
      }
      await _load();
      // count unchanged on rename — no callback fire
    } catch (e) {
      if (!mounted) return;
      setState(() => _renaming = false);
      _showSnack(_dioMessage(e), isError: true);
    }
  }

  /// Deletes [env] with a pre-flight impact lookup + confirm dialog.
  Future<void> _delete(Map<String, dynamic> env) async {
    final envId = env['id'] as String;
    final envName = env['envName'] as String? ?? '';
    final dio = ref.read(dioProvider);
    // Capture l10n + context before any awaits so the linter is happy
    // (and so we don't accidentally use a stale context if the widget
    // remounted while the pre-flight was in flight).
    final l10n = AppLocalizations.of(context);

    // 1. Pre-flight: how many answers + tasks does this env have?
    int impactAnswers = 0;
    int impactTasks = 0;
    try {
      final res = await dio.get<dynamic>('$_basePath/$envId/impact');
      final m = Map<String, dynamic>.from(res.data as Map);
      impactAnswers = (m['affectedAnswers'] as num?)?.toInt() ?? 0;
      impactTasks = (m['affectedTasks'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // Impact pre-flight isn't fatal — show the dialog with zero counts.
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(envName),
        content: Text(
          l10n.dataEnvironmentDeleteConfirm(impactAnswers, impactTasks),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Icon(Icons.delete_forever_rounded,
                color: Colors.white, size: 18),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await dio.delete<dynamic>('$_basePath/$envId');
      await _load();
      widget.onCountChanged?.call(_envs.length);
    } catch (e) {
      if (!mounted) return;
      _showSnack(_dioMessage(e), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  static String _dioMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      return detail ?? e.message ?? 'Network error';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.storage_rounded,
                  size: 16, color: AppColors.muted),
              const Gap(6),
              Text(
                '${l10n.manageDataEnvironments} (${_envs.length})',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              if (!_addOpen && !_loading)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l10n.addDataEnvironment,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _addOpen = true),
                ),
            ],
          ),

          // ── Body ────────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: AppColors.danger),
                const Gap(6),
                Expanded(child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.danger))),
                TextButton(onPressed: _load, child: Text(l10n.retry)),
              ]),
            )
          else ...[
            const Gap(8),
            if (_addOpen) _buildAddRow(l10n),
            if (_envs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  l10n.noResults,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              )
            else
              ..._envs.map((env) => _buildEnvRow(env, l10n)),
          ],
        ],
      ),
    );
  }

  Widget _buildAddRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _addCtrl,
            autofocus: true,
            enabled: !_adding,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: l10n.dataEnvironmentName,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const Gap(6),
        IconButton(
          icon: _adding
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_rounded,
                  size: 18, color: Color(0xFF16A34A)),
          onPressed: _adding ? null : _add,
          tooltip: l10n.save,
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              size: 18, color: AppColors.muted),
          onPressed: _adding
              ? null
              : () {
                  _addCtrl.clear();
                  setState(() => _addOpen = false);
                },
          tooltip: l10n.cancel,
        ),
      ]),
    );
  }

  Widget _buildEnvRow(Map<String, dynamic> env, AppLocalizations l10n) {
    final envId = env['id'] as String;
    final envName = env['envName'] as String? ?? '';
    final isRenaming = _renameEnvId == envId;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_outlined,
            size: 14, color: AppColors.muted),
        const Gap(8),
        Expanded(
          child: isRenaming
              ? TextField(
                  controller: _renameCtrl,
                  autofocus: true,
                  enabled: !_renaming,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _rename(envId),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 13),
                )
              : Text(
                  envName,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
        ),
        if (isRenaming) ...[
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: _renaming
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded,
                    size: 16, color: Color(0xFF16A34A)),
            onPressed: _renaming ? null : () => _rename(envId),
            tooltip: l10n.save,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.close_rounded,
                size: 16, color: AppColors.muted),
            onPressed: _renaming
                ? null
                : () => setState(() => _renameEnvId = null),
            tooltip: l10n.cancel,
          ),
        ] else ...[
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.edit_outlined,
                size: 14, color: AppColors.muted),
            onPressed: () {
              _renameCtrl.text = envName;
              setState(() => _renameEnvId = envId);
            },
            tooltip: l10n.dataEnvironmentName,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 14, color: AppColors.danger),
            onPressed: () => _delete(env),
          ),
        ],
      ]),
    );
  }
}
