/// Shared task edit dialog — used by both TaskBoardScreen (Kanban) and
/// TaskListScreen (list view) when the current user is it_executor.
///
/// Also exports [CustomerUserItem] and [customerUsersProvider] which are
/// needed by the create-task dialog that remains in TaskBoardScreen.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../core/models/workflow_task.dart';
import '../../l10n/app_localizations.dart';

// ── Shared model ──────────────────────────────────────────────────────────────

class CustomerUserItem {
  final String userId;
  final String userName;
  final String userEmail;
  const CustomerUserItem({
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  String get displayName =>
      userName.trim().isNotEmpty ? userName : userEmail;

  factory CustomerUserItem.fromJson(Map<String, dynamic> j) =>
      CustomerUserItem(
        userId: j['userId'] as String,
        userName: j['userName'] as String? ?? '',
        userEmail: j['userEmail'] as String? ?? '',
      );
}

// ── Shared provider ───────────────────────────────────────────────────────────

/// Users linked to a customer — for the assignee dropdown.
final customerUsersProvider =
    FutureProvider.autoDispose.family<List<CustomerUserItem>, String>(
        (ref, customerId) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<List<dynamic>>('/customers/$customerId/users');
  return (res.data ?? [])
      .map((e) => CustomerUserItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Public Edit Dialog ────────────────────────────────────────────────────────

class TaskEditDialog extends ConsumerStatefulWidget {
  final WorkflowTask task;
  final AppLocalizations l10n;

  const TaskEditDialog({super.key, required this.task, required this.l10n});

  @override
  ConsumerState<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends ConsumerState<TaskEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.task.taskName);
  late final _whatCtrl =
      TextEditingController(text: widget.task.whatToDo ?? '');
  late final _fineCtrl = TextEditingController(
      text: widget.task.estimatedFine != null
          ? widget.task.estimatedFine!.toStringAsFixed(2)
          : '');

  late int _statusId = widget.task.statusId;
  late DateTime? _dueDate = widget.task.dueDate;
  late bool _isRequired = widget.task.isRequired;
  late String? _assignedToUserId = widget.task.assignedToUserId;
  bool _saving = false;

  // ── Evidence state ─────────────────────────────────────────────────────────
  bool _uploading = false;
  double _uploadProgress = 0.0;
  final List<TaskFileEvidence> _evidenceItems = [];

  // ── Evidence review state ──────────────────────────────────────────────────
  bool _reviewingEvidence = false;
  int? _sufficiency; // 0-100, null = not yet reviewed
  String? _reviewDecision;
  String? _reviewSummary;

  AppLocalizations get l10n => widget.l10n;

  @override
  void initState() {
    super.initState();
    _sufficiency = widget.task.evidenceSufficiencyPcntg;
    _loadEvidence();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _whatCtrl.dispose();
    _fineCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvidence() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get<List<dynamic>>(
        '/workflow-tasks/${widget.task.id}/file-evidence',
      );
      if (!mounted) return;
      setState(() {
        _evidenceItems
          ..clear()
          ..addAll(
            (res.data ?? []).map(
              (e) => TaskFileEvidence.fromJson(e as Map<String, dynamic>),
            ),
          );
      });
    } catch (_) {}
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final dio = ref.read(dioProvider);

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: picked.name),
      });
      final uploadRes = await dio.post<Map<String, dynamic>>(
        '/files/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      final fileId = uploadRes.data!['id'] as String;

      final linkRes = await dio.post<Map<String, dynamic>>(
        '/workflow-tasks/${widget.task.id}/file-evidence',
        data: {'fileId': fileId},
      );
      final newItem = TaskFileEvidence.fromJson(linkRes.data!);

      if (mounted) {
        setState(() {
          _evidenceItems.insert(0, newItem);
          _uploading = false;
          _uploadProgress = 0.0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeEvidence(TaskFileEvidence item) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.delete(
          '/workflow-tasks/${widget.task.id}/file-evidence/${item.id}');
      if (mounted) {
        setState(() => _evidenceItems.removeWhere((e) => e.id == item.id));
      }
    } catch (_) {}
  }

  Future<void> _reviewEvidence() async {
    setState(() => _reviewingEvidence = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post<Map<String, dynamic>>(
        '/evidence-review',
        data: {'type': 'task', 'elementId': widget.task.id},
      );
      if (!mounted) return;
      final data = res.data!;
      setState(() {
        _sufficiency = (data['evidenceSufficiencyPcntg'] as num?)?.toInt();
        _reviewDecision = data['decision'] as String?;
        _reviewSummary = data['summary'] as String?;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Evidence review failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _reviewingEvidence = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final dio = ref.read(dioProvider);
      final fineText = _fineCtrl.text.trim();
      final fine = fineText.isNotEmpty ? double.tryParse(fineText) : null;

      await dio.put('/workflow-tasks/${widget.task.id}', data: {
        'taskName': _nameCtrl.text.trim(),
        'whatToDo': _whatCtrl.text.trim().isEmpty ? null : _whatCtrl.text.trim(),
        'statusId': _statusId,
        'dueDate': _dueDate == null
            ? null
            : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
        'isRequired': _isRequired,
        'assignedToUserId': _assignedToUserId,
        'estimatedFine': fine,
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  String _statusLabel(int id) => switch (id) {
        1 => l10n.taskToDo,
        2 => l10n.taskInProgress,
        3 => l10n.taskPendingReview,
        4 => l10n.taskDone,
        5 => l10n.taskOverdue,
        _ => l10n.taskToDo,
      };

  Color _statusColor(int id) => switch (id) {
        2 => AppColors.warning,
        3 => AppColors.orange,
        4 => AppColors.success,
        5 => AppColors.danger,
        _ => AppColors.muted,
      };

  InputDecoration _inputDeco({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.white,
      );

  @override
  Widget build(BuildContext context) {
    final customerId =
        ref.watch(customerContextProvider)?['customerId'] as String? ?? '';
    final usersAsync = ref.watch(customerUsersProvider(customerId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _statusColor(_statusId).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.edit_note_rounded,
                            color: _statusColor(_statusId), size: 20),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.editTask, style: AppTextStyles.h3),
                            Text(
                              widget.task.taskName,
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.of(context).pop(false),
                        color: AppColors.muted,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),

                  const Gap(20),
                  const Divider(color: AppColors.border, height: 1),
                  const Gap(16),

                  // ── Task Name ──────────────────────────────────────────
                  Text(l10n.taskNameLabel, style: AppTextStyles.label),
                  const Gap(6),
                  TextFormField(
                    controller: _nameCtrl,
                    autofocus: true,
                    decoration: _inputDeco(hint: l10n.taskNameLabel),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.required : null,
                  ),

                  const Gap(14),

                  // ── What To Do ─────────────────────────────────────────
                  Text(l10n.whatToDoLabel, style: AppTextStyles.label),
                  const Gap(6),
                  TextFormField(
                    controller: _whatCtrl,
                    maxLines: 3,
                    decoration: _inputDeco(
                        hint: 'Describe the steps to complete this task…'),
                  ),

                  // ── Risk (read-only — LLM-generated) ──────────────────
                  if (widget.task.risk != null &&
                      widget.task.risk!.isNotEmpty) ...[
                    const Gap(14),
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: AppColors.orange),
                      const Gap(5),
                      Text(l10n.taskRiskLabel, style: AppTextStyles.label),
                    ]),
                    const Gap(6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        widget.task.risk!,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],

                  const Gap(14),

                  // ── Status + Due Date ──────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.taskStatusLabel,
                                style: AppTextStyles.label),
                            const Gap(6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                                color: AppColors.white,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _statusId,
                                  isExpanded: true,
                                  isDense: true,
                                  style: AppTextStyles.body
                                      .copyWith(color: AppColors.text),
                                  items: [1, 2, 3, 4, 5]
                                      .map((id) => DropdownMenuItem(
                                            value: id,
                                            child: Text(
                                              _statusLabel(id),
                                              style: AppTextStyles.body
                                                  .copyWith(
                                                      color:
                                                          _statusColor(id)),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _statusId = v!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.dueDateLabel,
                                style: AppTextStyles.label),
                            const Gap(6),
                            GestureDetector(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.white,
                                ),
                                child: Row(children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 14, color: AppColors.muted),
                                  const Gap(8),
                                  Expanded(
                                    child: Text(
                                      _dueDate == null
                                          ? l10n.noDueDate
                                          : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                                      style: AppTextStyles.body.copyWith(
                                        color: _dueDate == null
                                            ? AppColors.muted
                                            : AppColors.text,
                                      ),
                                    ),
                                  ),
                                  if (_dueDate != null)
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _dueDate = null),
                                      child: const Icon(Icons.clear,
                                          size: 14, color: AppColors.muted),
                                    ),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Gap(14),

                  // ── Assignee + Fine ────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.assignToLabel,
                                style: AppTextStyles.label),
                            const Gap(6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                                color: AppColors.white,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: usersAsync.when(
                                  loading: () => const SizedBox(
                                    height: 32,
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                  error: (_, __) => DropdownButton<String?>(
                                    value: null,
                                    isExpanded: true,
                                    isDense: true,
                                    items: [
                                      DropdownMenuItem(
                                          value: null,
                                          child: Text(l10n.unassigned,
                                              style: AppTextStyles.body
                                                  .copyWith(
                                                      color:
                                                          AppColors.muted))),
                                    ],
                                    onChanged: (_) {},
                                  ),
                                  data: (users) => DropdownButton<String?>(
                                    value: _assignedToUserId,
                                    isExpanded: true,
                                    isDense: true,
                                    style: AppTextStyles.body
                                        .copyWith(color: AppColors.text),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          l10n.unassigned,
                                          style: AppTextStyles.body.copyWith(
                                              color: AppColors.muted),
                                        ),
                                      ),
                                      ...users.map((u) =>
                                          DropdownMenuItem<String?>(
                                            value: u.userId,
                                            child: Text(
                                              u.displayName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _assignedToUserId = v),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(14),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.estimatedFineLabel,
                                style: AppTextStyles.label),
                            const Gap(6),
                            TextFormField(
                              controller: _fineCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              decoration: _inputDeco(hint: '0.00'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Gap(14),

                  // ── Is Required ────────────────────────────────────────
                  Row(children: [
                    Switch(
                      value: _isRequired,
                      onChanged: (v) => setState(() => _isRequired = v),
                      activeColor: AppColors.danger,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Gap(8),
                    Text(l10n.isRequiredLabel, style: AppTextStyles.body),
                    if (_isRequired) ...[
                      const Gap(6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(l10n.taskRequired,
                            style: AppTextStyles.tag
                                .copyWith(color: AppColors.danger)),
                      ),
                    ],
                  ]),

                  const Gap(20),
                  const Divider(color: AppColors.border, height: 1),
                  const Gap(14),

                  // ── Evidence ──────────────────────────────────────────
                  Row(children: [
                    const Icon(Icons.attach_file_rounded,
                        size: 14, color: AppColors.muted),
                    const Gap(6),
                    Text(l10n.addEvidence, style: AppTextStyles.label),
                    const Spacer(),
                    if (_sufficiency != null)
                      _SufficiencyBadge(pcntg: _sufficiency!),
                  ]),
                  const Gap(8),

                  // Review summary (shown after a review run)
                  if (_reviewSummary != null && _reviewSummary!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_reviewDecision == 'APPROVE'
                                ? AppColors.success
                                : AppColors.warning)
                            .withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (_reviewDecision == 'APPROVE'
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _reviewDecision == 'APPROVE'
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 15,
                            color: _reviewDecision == 'APPROVE'
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              _reviewSummary!,
                              style: AppTextStyles.caption
                                  .copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                  ],

                  if (_uploading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        minHeight: 4,
                        backgroundColor:
                            AppColors.blue.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.blue),
                      ),
                    ),
                    const Gap(8),
                  ],

                  ..._evidenceItems.map((item) => _EvidenceRow(
                        item: item,
                        baseUrl: ref.read(dioProvider).options.baseUrl,
                        onRemove: () => _removeEvidence(item),
                      )),

                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickAndUpload,
                        icon: const Icon(Icons.upload_file_outlined, size: 16),
                        label: Text(l10n.addEvidence),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.blue,
                          side: const BorderSide(color: AppColors.blue),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          textStyle: AppTextStyles.button,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (_evidenceItems.isNotEmpty) ...[
                        const Gap(10),
                        OutlinedButton.icon(
                          onPressed: _reviewingEvidence ? null : _reviewEvidence,
                          icon: _reviewingEvidence
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF6C3FC5)),
                                )
                              : const Icon(Icons.fact_check_outlined, size: 16),
                          label: Text(_reviewingEvidence
                              ? 'Reviewing…'
                              : 'Review Evidence'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6C3FC5),
                            side:
                                const BorderSide(color: Color(0xFF6C3FC5)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            textStyle: AppTextStyles.button,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const Gap(20),
                  const Divider(color: AppColors.border, height: 1),
                  const Gap(14),

                  // ── Action buttons ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel,
                            style: AppTextStyles.button
                                .copyWith(color: AppColors.muted)),
                      ),
                      const Gap(8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          textStyle: AppTextStyles.button,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 16),
                        label: Text(l10n.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sufficiency badge ─────────────────────────────────────────────────────────

class _SufficiencyBadge extends StatelessWidget {
  final int pcntg;
  const _SufficiencyBadge({required this.pcntg});

  Color get _color {
    if (pcntg >= 70) return AppColors.success;
    if (pcntg >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 12, color: _color),
          const Gap(4),
          Text(
            '$pcntg%',
            style: AppTextStyles.tag.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private evidence helpers ──────────────────────────────────────────────────

class _EvidenceRow extends StatelessWidget {
  final TaskFileEvidence item;
  final VoidCallback onRemove;
  final String baseUrl;

  const _EvidenceRow({
    required this.item,
    required this.onRemove,
    required this.baseUrl,
  });

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  void _openViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EvidenceViewerDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImage = item.fileType == 'image';
    final hasContent = (item.fileText != null && item.fileText!.isNotEmpty) ||
        (item.imageDescription != null && item.imageDescription!.isNotEmpty);
    final displayName =
        item.fileName.isNotEmpty ? item.fileName : item.filePath.split('/').last;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isImage ? Icons.image_outlined : Icons.description_outlined,
            size: 16,
            color: isImage ? AppColors.info : AppColors.blue,
          ),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.body
                      .copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  _fmtDate(item.createdAt),
                  style: AppTextStyles.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          const Gap(4),
          if (hasContent)
            _EvidenceIconBtn(
              icon: Icons.visibility_outlined,
              tooltip: 'View',
              color: AppColors.blue,
              onTap: () => _openViewer(context),
            ),
          _EvidenceIconBtn(
            icon: Icons.download_outlined,
            tooltip: 'Download',
            color: AppColors.success,
            onTap: () async {
              final uri = Uri.parse('$baseUrl/files/${item.fileId}/download');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
          _EvidenceIconBtn(
            icon: Icons.delete_outline,
            tooltip: 'Remove',
            color: AppColors.danger,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _EvidenceIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _EvidenceIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}

class _EvidenceViewerDialog extends StatelessWidget {
  final TaskFileEvidence item;
  const _EvidenceViewerDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final isImage = item.fileType == 'image';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: isImage
                    ? AppColors.info.withOpacity(0.08)
                    : AppColors.blue.withOpacity(0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border:
                    const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    isImage ? Icons.image_outlined : Icons.article_outlined,
                    color: isImage ? AppColors.info : AppColors.blue,
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      item.fileName.isNotEmpty
                          ? item.fileName
                          : item.filePath.split('/').last,
                      style: AppTextStyles.h4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: isImage
                    ? _ImageDescriptionView(
                        description: item.imageDescription ?? '')
                    : _DocumentView(fileText: item.fileText ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentView extends StatelessWidget {
  final String fileText;
  const _DocumentView({required this.fileText});

  @override
  Widget build(BuildContext context) {
    if (fileText.isEmpty) {
      return Center(
        child: Text('No content available.',
            style: AppTextStyles.body.copyWith(color: AppColors.muted)),
      );
    }
    try {
      final decoded = jsonDecode(fileText) as Map<String, dynamic>;
      final title = decoded['title'] as String? ?? '';
      final content =
          (decoded['content'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title,
                style: AppTextStyles.h2
                    .copyWith(color: const Color(0xFF1A237E))),
            const Gap(16),
            const Divider(color: AppColors.border),
            const Gap(16),
          ],
          ...content.map((section) {
            final name = section['sectionName'] as String? ?? '';
            final body = section['sectionContent'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EAF6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(name,
                          style: AppTextStyles.label
                              .copyWith(color: const Color(0xFF1A237E))),
                    ),
                    const Gap(8),
                  ],
                  Text(body,
                      style: AppTextStyles.body.copyWith(height: 1.6)),
                ],
              ),
            );
          }),
        ],
      );
    } catch (_) {
      return SelectableText(fileText,
          style: AppTextStyles.body.copyWith(height: 1.6));
    }
  }
}

class _ImageDescriptionView extends StatelessWidget {
  final String description;
  const _ImageDescriptionView({required this.description});

  @override
  Widget build(BuildContext context) {
    if (description.isEmpty) {
      return Center(
        child: Text('No description available.',
            style: AppTextStyles.body.copyWith(color: AppColors.muted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.info),
          const Gap(6),
          Text('AI-Generated Description',
              style: AppTextStyles.label.copyWith(color: AppColors.info)),
        ]),
        const Gap(12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info.withOpacity(0.2)),
          ),
          child: SelectableText(
            description,
            style: AppTextStyles.body.copyWith(height: 1.7),
          ),
        ),
      ],
    );
  }
}
