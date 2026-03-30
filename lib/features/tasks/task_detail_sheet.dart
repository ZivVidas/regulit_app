/// Shared task detail bottom sheet.
/// Used by both the list view (TaskListScreen) and the Kanban board
/// (TaskBoardScreen) for client_admin and employee roles.
///
/// [canChangeStatus]: when true, shows the status dropdown + save button.
///   Pass true only when the current user is assigned to the task.
library;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/workflow_task.dart';

// ── Public sheet ──────────────────────────────────────────────────────────────

class TaskDetailSheet extends ConsumerStatefulWidget {
  final WorkflowTask task;
  final bool canChangeStatus;
  final VoidCallback onStatusChanged;

  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.canChangeStatus,
    required this.onStatusChanged,
  });

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  late int _statusId;
  bool _saving = false;
  String? _error;

  // ── Evidence state ─────────────────────────────────────────────────────────
  final List<TaskFileEvidence> _evidenceItems = [];
  bool _uploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _statusId = widget.task.statusId;
    _loadEvidence();
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

    setState(() { _uploading = true; _uploadProgress = 0.0; });
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

  Future<void> _saveStatus() async {
    if (_statusId == widget.task.statusId) return;
    setState(() { _saving = true; _error = null; });
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/workflow-tasks/${widget.task.id}/status',
        data: {'statusId': _statusId},
        options: Options(contentType: Headers.jsonContentType),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onStatusChanged();
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      final msg = detail ??
          'HTTP ${e.response?.statusCode ?? '?'}: ${e.message ?? 'unknown error'}';
      if (mounted) {
        setState(() { _saving = false; _error = msg; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status update failed: $msg'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; _error = e.toString(); });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status update failed: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  static Color _accentFor(WorkflowTaskStatus s) => switch (s) {
        WorkflowTaskStatus.todo          => AppColors.muted,
        WorkflowTaskStatus.inProgress    => AppColors.warning,
        WorkflowTaskStatus.pendingReview => AppColors.orange,
        WorkflowTaskStatus.approved      => AppColors.success,
        WorkflowTaskStatus.overdue       => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final status = WorkflowTaskStatus.fromId(_statusId);
    final accent = _accentFor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(16),

            // Title
            Text(widget.task.taskName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Gap(4),

            // Required badge
            if (widget.task.isRequired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Required',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600)),
              ),

            const Gap(16),
            const Divider(height: 1, color: AppColors.border),
            const Gap(16),

            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  // What to do
                  if (widget.task.whatToDo != null) ...[
                    const Text('What To Do',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            fontSize: 12)),
                    const Gap(6),
                    Text(widget.task.whatToDo!,
                        style: const TextStyle(fontSize: 14, height: 1.6)),
                    const Gap(16),
                  ],

                  // Risk
                  if (widget.task.risk != null && widget.task.risk!.isNotEmpty) ...[
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: AppColors.orange),
                      const Gap(5),
                      const Text('Risk',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                              fontSize: 12)),
                    ]),
                    const Gap(6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.orange.withOpacity(0.25)),
                      ),
                      child: Text(widget.task.risk!,
                          style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text)),
                    ),
                    const Gap(16),
                  ],

                  // Meta row
                  Wrap(
                    spacing: 12, runSpacing: 8,
                    children: [
                      if (widget.task.assignedToUserName != null)
                        _MetaItem(
                          icon: Icons.person_outline,
                          label: 'Assigned to',
                          value: widget.task.assignedToUserName!,
                        ),
                      if (widget.task.dueDate != null)
                        _MetaItem(
                          icon: Icons.calendar_today_outlined,
                          label: 'Due date',
                          value: DateFormat('dd MMM yyyy').format(widget.task.dueDate!),
                        ),
                      if (widget.task.estimatedFine != null)
                        _MetaItem(
                          icon: Icons.account_balance_outlined,
                          label: 'Estimated fine',
                          value: '₪${NumberFormat.decimalPattern().format(widget.task.estimatedFine)}',
                        ),
                    ],
                  ),
                  const Gap(16),

                  // ── Evidence section ────────────────────────────────────
                  const Divider(height: 1, color: AppColors.border),
                  const Gap(16),

                  Row(children: [
                    const Icon(Icons.attach_file_rounded,
                        size: 14, color: AppColors.muted),
                    const Gap(6),
                    const Text('Evidence',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            fontSize: 12)),
                    const Spacer(),
                    // Sufficiency badge — shown whenever a value exists
                    if (widget.task.evidenceSufficiencyPcntg != null)
                      _EvidenceSufficiencyBadge(
                          pcntg: widget.task.evidenceSufficiencyPcntg!),
                  ]),
                  const Gap(8),

                  if (_uploading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        minHeight: 4,
                        backgroundColor: AppColors.blue.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.blue),
                      ),
                    ),
                    const Gap(8),
                  ],

                  // Evidence file rows — visible to everyone
                  if (_evidenceItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        widget.canChangeStatus
                            ? 'No evidence attached yet. Upload a file below.'
                            : 'No evidence attached.',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    )
                  else
                    ..._evidenceItems.map((item) => _EvidenceFileRow(
                          item: item,
                          baseUrl: ref.read(dioProvider).options.baseUrl,
                          canRemove: widget.canChangeStatus,
                          onRemove: () => _removeEvidence(item),
                        )),

                  // Upload button — only when assigned (canChangeStatus)
                  if (widget.canChangeStatus) ...[
                    const Gap(4),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickAndUpload,
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: const Text('Add Evidence'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.blue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],

                  const Gap(24),

                  // ── Status section (only when user can change it) ─────────
                  if (widget.canChangeStatus) ...[
                    const Text('Status',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            fontSize: 12)),
                    const Gap(8),
                    DropdownButtonFormField<int>(
                      value: _statusId,
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: accent.withOpacity(0.5))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: accent.withOpacity(0.5))),
                        filled: true,
                        fillColor: accent.withOpacity(0.05),
                      ),
                      items: WorkflowTaskStatus.values
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.label),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _statusId = v!),
                    ),

                    if (_error != null) ...[
                      const Gap(8),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ],

                    const Gap(24),

                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _saving ? null : _saveStatus,
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Status',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ] else ...[
                    // Read-only status chip
                    const Text('Status',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            fontSize: 12)),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                        const Gap(8),
                        Text(status.label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accent)),
                      ]),
                    ),
                    const Gap(8),
                    Text('You can only change status for tasks assigned to you.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                  const Gap(32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _EvidenceSufficiencyBadge extends StatelessWidget {
  final int pcntg;
  const _EvidenceSufficiencyBadge({required this.pcntg});

  Color get _color {
    if (pcntg >= 75) return AppColors.success;
    if (pcntg >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 14, color: _color),
          const Gap(6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Evidence Sufficiency',
                  style: TextStyle(
                      fontSize: 11,
                      color: _color,
                      fontWeight: FontWeight.w500)),
              Text('$pcntg%',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceFileRow extends StatelessWidget {
  final TaskFileEvidence item;
  final String baseUrl;
  final bool canRemove;
  final VoidCallback onRemove;

  const _EvidenceFileRow({
    required this.item,
    required this.baseUrl,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = item.fileType == 'image';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
            size: 16,
            color: AppColors.muted,
          ),
          const Gap(8),
          Expanded(
            child: InkWell(
              onTap: () async {
                final url = Uri.parse('$baseUrl/files/${item.fileId}/download');
                if (await canLaunchUrl(url)) launchUrl(url);
              },
              child: Text(
                item.fileName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.blue,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.close, size: 14, color: AppColors.muted),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const Gap(4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500)),
            Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
