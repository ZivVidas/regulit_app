/// Session Files — navigation entry point.
///
/// Session picker at the top (identical pattern to the dashboard and task
/// screens), file list below.  Auto-selects the first session on load.
///
/// Accessible to: client_admin, it_executor.
/// Route: /session-files  (no path parameter — uses built-in picker)
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/customer/customer_context_provider.dart';
import '../../l10n/app_localizations.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _Session {
  final String id;
  final String workflowName;
  const _Session({required this.id, required this.workflowName});

  factory _Session.fromJson(Map<String, dynamic> j) => _Session(
        id: j['id'] as String,
        workflowName: j['workflowName'] as String? ?? '—',
      );
}

class _FileItem {
  final String fileId;
  final String fileName;
  final String filePath;
  final String fileType;
  final DateTime uploadedAt;
  final String? uploadedBy;
  final String source;
  final String? contextLabel;
  final bool hasText;

  const _FileItem({
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.source,
    required this.contextLabel,
    required this.hasText,
  });

  factory _FileItem.fromJson(Map<String, dynamic> j) => _FileItem(
        fileId: j['fileId'] as String,
        fileName: j['fileName'] as String,
        filePath: j['filePath'] as String? ?? '',
        fileType: j['fileType'] as String,
        uploadedAt: DateTime.parse(j['uploadedAt'] as String).toLocal(),
        uploadedBy: j['uploadedBy'] as String?,
        source: j['source'] as String,
        contextLabel: j['contextLabel'] as String?,
        hasText: j['hasText'] as bool? ?? false,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _sfSessionsProvider =
    FutureProvider.autoDispose.family<List<_Session>, String>(
  (ref, customerId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<List<dynamic>>(
      '/workflow-answers/active-sessions/$customerId',
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(_Session.fromJson)
        .toList();
  },
);

final _sfFilesProvider =
    FutureProvider.autoDispose.family<List<_FileItem>, String>(
  (ref, sessionId) async {
    final dio = ref.watch(dioProvider);
    final res = await dio.get<List<dynamic>>(
      '/workflow-answers/$sessionId/files',
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(_FileItem.fromJson)
        .toList();
  },
);

// ── Screen ────────────────────────────────────────────────────────────────────

class SessionFilesNavScreen extends ConsumerStatefulWidget {
  const SessionFilesNavScreen({super.key});

  @override
  ConsumerState<SessionFilesNavScreen> createState() =>
      _SessionFilesNavScreenState();
}

class _SessionFilesNavScreenState
    extends ConsumerState<SessionFilesNavScreen> {
  String? _selectedSessionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customerId =
        ref.watch(customerContextProvider)?['customerId'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.sessionFilesTitle),
        centerTitle: false,
      ),
      body: customerId == null
          ? Center(child: Text(l10n.noCustomerContextSelected))
          : _Body(
              customerId: customerId,
              selectedSessionId: _selectedSessionId,
              onSessionChanged: (id) =>
                  setState(() => _selectedSessionId = id),
            ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final String customerId;
  final String? selectedSessionId;
  final ValueChanged<String?> onSessionChanged;

  const _Body({
    required this.customerId,
    required this.selectedSessionId,
    required this.onSessionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(_sfSessionsProvider(customerId));

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e.toString(),
            style: const TextStyle(color: AppColors.danger)),
      ),
      data: (sessions) {
        if (selectedSessionId == null && sessions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => onSessionChanged(sessions.first.id));
        }

        final effectiveId =
            selectedSessionId != null &&
                    sessions.any((s) => s.id == selectedSessionId)
                ? selectedSessionId!
                : (sessions.isNotEmpty ? sessions.first.id : null);

        return Column(
          children: [
            _SessionPickerBar(
              sessions: sessions,
              selectedId: effectiveId,
              onChanged: onSessionChanged,
            ),
            Expanded(
              child: effectiveId == null
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)
                            .noActiveAssessmentSessions,
                        style:
                            const TextStyle(color: AppColors.muted),
                      ),
                    )
                  : _FileList(
                      sessionId: effectiveId,
                      dio: ref.read(dioProvider),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Session picker bar — identical to dashboard ───────────────────────────────

class _SessionPickerBar extends StatelessWidget {
  final List<_Session> sessions;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _SessionPickerBar({
    required this.sessions,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined,
              size: 16, color: AppColors.muted),
          const Gap(8),
          Text(
            l10n.assessmentLabel,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted),
          ),
          const Gap(12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedId,
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              items: sessions
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.workflowName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── File list ─────────────────────────────────────────────────────────────────

class _FileList extends ConsumerStatefulWidget {
  final String sessionId;
  final Dio dio;
  const _FileList({required this.sessionId, required this.dio});

  @override
  ConsumerState<_FileList> createState() => _FileListState();
}

class _FileListState extends ConsumerState<_FileList> {
  bool _downloadingAll = false;

  Future<void> _downloadAll() async {
    if (_downloadingAll) return;
    setState(() => _downloadingAll = true);
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/session_files.zip';

      await widget.dio.download(
        '/workflow-answers/${widget.sessionId}/files/download-zip',
        savePath,
      );

      if (!mounted) return;
      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open zip: ${result.message}'),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _downloadingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filesAsync = ref.watch(_sfFilesProvider(widget.sessionId));

    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: AppColors.danger),
            const Gap(12),
            Text(l10n.failedToLoadFiles,
                style:
                    AppTextStyles.h3.copyWith(color: AppColors.danger)),
            const Gap(8),
            Text(e.toString(),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted),
                textAlign: TextAlign.center),
            const Gap(16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(_sfFilesProvider(widget.sessionId)),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (files) {
        if (files.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_open_outlined,
                    size: 56, color: AppColors.muted),
                const Gap(12),
                Text(l10n.noFilesUploaded,
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.muted)),
              ],
            ),
          );
        }
        return Column(
          children: [
            // ── Header bar: file count + Download All ────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_copy_outlined,
                      size: 15, color: AppColors.muted),
                  const Gap(6),
                  Text(
                    l10n.nFiles(files.length),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted),
                  ),
                  const Spacer(),
                  if (_downloadingAll)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.blue),
                    )
                  else
                    TextButton.icon(
                      onPressed: _downloadAll,
                      icon: const Icon(
                          Icons.download_for_offline_outlined,
                          size: 16),
                      label: Text(l10n.downloadAll),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        textStyle: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            // ── File cards ───────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: files.length,
                separatorBuilder: (_, __) => const Gap(10),
                itemBuilder: (_, i) =>
                    _FileCard(item: files[i], dio: widget.dio),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── File card (stateful — manages download spinner) ───────────────────────────

class _FileCard extends StatefulWidget {
  const _FileCard({required this.item, required this.dio});
  final _FileItem item;
  final Dio dio;

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> {
  bool _downloading = false;

  // ── View text ──────────────────────────────────────────────────────────────

  Future<void> _openViewer() async {
    // Capture the root navigator BEFORE any async gap.
    // showDialog() uses rootNavigator:true by default, so the spinner is pushed
    // onto the root navigator. After the await the context's nearest navigator
    // is GoRouter's ShellRoute nested navigator — a different object — so we
    // must hold a direct reference to avoid popping the wrong route.
    final nav = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await widget.dio
          .get<Map<String, dynamic>>('/files/${widget.item.fileId}');

      nav.pop(); // close spinner (same root navigator)

      if (!mounted) return;
      final data = res.data!;

      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (_) => _EvidenceViewerDialog(
          fileName: widget.item.fileName,
          fileType: widget.item.fileType,
          fileText: data['fileText'] as String?,
          imageDescription: data['imageDescription'] as String?,
        ),
      );
    } catch (e) {
      nav.pop(); // close spinner even if fetch failed
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not load file: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  // ── Download (via authenticated Dio → temp dir → OS open) ─────────────────

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final rawName = widget.item.filePath.split('/').last;
      final idx = rawName.indexOf('_');
      final cleanName =
          (idx == 8 && idx < rawName.length - 1)
              ? rawName.substring(idx + 1)
              : widget.item.fileName.isNotEmpty
                  ? widget.item.fileName
                  : rawName;

      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/$cleanName';

      await widget.dio.download(
        '/files/${widget.item.fileId}/download',
        savePath,
      );

      if (!mounted) return;
      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open file: ${result.message}'),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isImage = widget.item.fileType == 'image';
    final isTask = widget.item.source == 'task';
    final dateStr = DateFormat('dd MMM yyyy · HH:mm')
        .format(widget.item.uploadedAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // ── File type icon ──────────────────────────────────
            Icon(
              isImage ? Icons.image_outlined : Icons.description_outlined,
              size: 18,
              color: isImage ? AppColors.info : AppColors.blue,
            ),
            const Gap(10),

            // ── Name + meta ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.fileName,
                    style: AppTextStyles.body.copyWith(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const Gap(2),
                  Row(
                    children: [
                      Text(dateStr,
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 11)),
                      if (widget.item.uploadedBy != null) ...[
                        const Text(' · ',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                        Expanded(
                          child: Text(
                            widget.item.uploadedBy!,
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.item.contextLabel != null &&
                      widget.item.contextLabel!.isNotEmpty) ...[
                    const Gap(2),
                    Row(
                      children: [
                        // Source badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isTask
                                    ? AppColors.info
                                    : AppColors.success)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isTask ? l10n.sourceTask : l10n.sourceAnswer,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isTask
                                  ? AppColors.info
                                  : AppColors.success,
                            ),
                          ),
                        ),
                        const Gap(6),
                        Expanded(
                          child: Text(
                            widget.item.contextLabel!,
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const Gap(4),

            // ── Action icons (matches task window exactly) ───────
            if (widget.item.hasText)
              _IconBtn(
                icon: Icons.visibility_outlined,
                tooltip: l10n.viewText,
                color: AppColors.blue,
                onTap: _openViewer,
              ),
            _downloading
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.success),
                    ),
                  )
                : _IconBtn(
                    icon: Icons.download_outlined,
                    tooltip: l10n.downloadFile,
                    color: AppColors.success,
                    onTap: _download,
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Icon button (matches _EvidenceIconBtn in task_edit_dialog) ────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Viewer dialog — exact copy of the one in task_edit_dialog.dart
// ══════════════════════════════════════════════════════════════════════════════

class _EvidenceViewerDialog extends StatelessWidget {
  final String fileName;
  final String fileType;
  final String? fileText;
  final String? imageDescription;

  const _EvidenceViewerDialog({
    required this.fileName,
    required this.fileType,
    required this.fileText,
    required this.imageDescription,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = fileType == 'image';
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                color: isImage
                    ? AppColors.info.withOpacity(0.08)
                    : AppColors.blue.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                border: const Border(
                    bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    isImage
                        ? Icons.image_outlined
                        : Icons.article_outlined,
                    color: isImage ? AppColors.info : AppColors.blue,
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      fileName,
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
            // Content
            Expanded(
              child: isImage
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _ImageDescriptionView(
                          description: imageDescription ?? ''),
                    )
                  : _DocumentView(fileText: fileText ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Document viewer (structured JSON or plain text fallback) ──────────────────

class _DocumentView extends StatefulWidget {
  final String fileText;
  const _DocumentView({required this.fileText});

  @override
  State<_DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<_DocumentView> {
  final _scrollController = ScrollController();
  final _sectionKeys = <GlobalKey>[];
  int _activeSection = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(int index) {
    if (index < 0 || index >= _sectionKeys.length) return;
    setState(() => _activeSection = index);
    final ctx = _sectionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fileText.isEmpty) {
      return Center(
        child: Text('No content available.',
            style: AppTextStyles.body.copyWith(color: AppColors.muted)),
      );
    }

    try {
      final decoded =
          jsonDecode(widget.fileText) as Map<String, dynamic>;
      final title = decoded['title'] as String? ?? '';
      final content =
          (decoded['content'] as List?)?.cast<Map<String, dynamic>>() ??
              [];

      while (_sectionKeys.length < content.length) {
        _sectionKeys.add(GlobalKey());
      }

      final hasToc = content.length >= 2 &&
          content.any(
              (s) => (s['sectionName'] as String? ?? '').isNotEmpty);

      if (hasToc) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOC panel ─────────────────────────────────────────
            Container(
              width: 190,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F8),
                border:
                    Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                    child: Text('Contents',
                        style: AppTextStyles.label.copyWith(
                            color: AppColors.muted,
                            fontSize: 11,
                            letterSpacing: 0.8)),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: content.length,
                      itemBuilder: (context, i) {
                        final name =
                            content[i]['sectionName'] as String? ?? '';
                        final isActive = i == _activeSection;
                        return InkWell(
                          onTap: () => _scrollTo(i),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF1A237E)
                                      .withOpacity(0.08)
                                  : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: isActive
                                      ? const Color(0xFF1A237E)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(children: [
                              Text('${i + 1}',
                                  style: AppTextStyles.label.copyWith(
                                      fontSize: 11,
                                      color: isActive
                                          ? const Color(0xFF1A237E)
                                          : AppColors.muted,
                                      fontWeight: FontWeight.bold)),
                              const Gap(8),
                              Expanded(
                                child: Text(name,
                                    style: AppTextStyles.body.copyWith(
                                        fontSize: 12,
                                        color: isActive
                                            ? const Color(0xFF1A237E)
                                            : AppColors.text,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.normal),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // ── Content panel ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) ...[
                      Text(title,
                          style: AppTextStyles.h2.copyWith(
                              color: const Color(0xFF1A237E))),
                      const Gap(12),
                      const Divider(color: AppColors.border),
                      const Gap(16),
                    ],
                    ...List.generate(content.length, (i) {
                      final section = content[i];
                      final name =
                          section['sectionName'] as String? ?? '';
                      final body =
                          section['sectionContent'] as String? ?? '';
                      return Padding(
                        key: _sectionKeys[i],
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (name.isNotEmpty) ...[
                              Row(children: [
                                Container(
                                  width: 4,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A237E),
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                                const Gap(8),
                                Expanded(
                                  child: Text(name,
                                      style: AppTextStyles.label.copyWith(
                                          color:
                                              const Color(0xFF1A237E),
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w600)),
                                ),
                              ]),
                              const Gap(10),
                            ],
                            SelectableText(body,
                                style: AppTextStyles.body
                                    .copyWith(height: 1.7)),
                          ],
                        ),
                      );
                    }),
                    const Gap(40),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      // Single-column fallback
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(title,
                  style: AppTextStyles.h2
                      .copyWith(color: const Color(0xFF1A237E))),
              const Gap(12),
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
                            style: AppTextStyles.label.copyWith(
                                color: const Color(0xFF1A237E))),
                      ),
                      const Gap(8),
                    ],
                    SelectableText(body,
                        style:
                            AppTextStyles.body.copyWith(height: 1.6)),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    } catch (_) {
      // Plain text fallback
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: SelectableText(widget.fileText,
            style: AppTextStyles.body.copyWith(height: 1.6)),
      );
    }
  }
}

// ── Image description viewer ──────────────────────────────────────────────────

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
          const Icon(Icons.auto_awesome_outlined,
              size: 16, color: AppColors.info),
          const Gap(6),
          Text('AI-Generated Description',
              style:
                  AppTextStyles.label.copyWith(color: AppColors.info)),
        ]),
        const Gap(12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.info.withOpacity(0.2)),
          ),
          child: SelectableText(description,
              style: AppTextStyles.body.copyWith(height: 1.7)),
        ),
      ],
    );
  }
}
