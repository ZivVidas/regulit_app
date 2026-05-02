/// Session Files Screen
///
/// Shows all evidence files attached to a workflow-answer session —
/// both files uploaded against quiz answers and files attached to tasks.
///
/// Accessible to: client_admin, it_executor.
/// Route: /session-files/:sessionId
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../l10n/app_localizations.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _FileItem {
  final String fileId;
  final String fileName;
  final String fileType;   // 'text' | 'image'
  final DateTime uploadedAt;
  final String? uploadedBy;
  final String source;     // 'task' | 'answer'
  final String? contextLabel;
  final bool hasText;

  const _FileItem({
    required this.fileId,
    required this.fileName,
    required this.fileType,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.source,
    required this.contextLabel,
    required this.hasText,
  });

  factory _FileItem.fromJson(Map<String, dynamic> json) => _FileItem(
        fileId: json['fileId'] as String,
        fileName: json['fileName'] as String,
        fileType: json['fileType'] as String,
        uploadedAt: DateTime.parse(json['uploadedAt'] as String).toLocal(),
        uploadedBy: json['uploadedBy'] as String?,
        source: json['source'] as String,
        contextLabel: json['contextLabel'] as String?,
        hasText: json['hasText'] as bool? ?? false,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SessionFilesScreen extends ConsumerStatefulWidget {
  const SessionFilesScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<SessionFilesScreen> createState() => _SessionFilesScreenState();
}

class _SessionFilesScreenState extends ConsumerState<SessionFilesScreen> {
  List<_FileItem>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get<List<dynamic>>(
        '/workflow-answers/${widget.sessionId}/files',
      );
      if (!mounted) return;
      setState(() {
        _items = (res.data ?? [])
            .cast<Map<String, dynamic>>()
            .map(_FileItem.fromJson)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Fetch full file details and show text / image-description in a dialog.
  Future<void> _viewText(BuildContext context, _FileItem item) async {
    final l10n = AppLocalizations.of(context);
    // Show a loading dialog while we fetch
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get<Map<String, dynamic>>('/files/${item.fileId}');
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      final data = res.data!;
      final content = (data['fileText'] as String?)?.trim().isNotEmpty == true
          ? data['fileText'] as String
          : (data['imageDescription'] as String?)?.trim().isNotEmpty == true
              ? data['imageDescription'] as String
              : null;

      showDialog(
        context: context,
        builder: (_) => _TextViewDialog(
          title: item.fileName,
          content: content ?? l10n.noTextAvailable,
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(); // close loading
      }
    }
  }

  /// Launch the file download URL in the browser.
  Future<void> _download(String fileId, String baseUrl) async {
    final url = Uri.parse('$baseUrl/files/$fileId/download');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseUrl = ref.read(dioProvider).options.baseUrl;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const Gap(12),
            Text(
              l10n.failedToLoadFiles,
              style: AppTextStyles.h3.copyWith(color: AppColors.danger),
            ),
            const Gap(8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const Gap(16),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    } else if (_items == null || _items!.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined,
                size: 56, color: AppColors.muted),
            const Gap(12),
            Text(
              l10n.noFilesUploaded,
              style: AppTextStyles.h3.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items!.length,
        separatorBuilder: (_, __) => const Gap(10),
        itemBuilder: (ctx, i) {
          final item = _items![i];
          return _FileCard(
            item: item,
            onViewText: item.hasText
                ? () => _viewText(context, item)
                : null,
            onDownload: () => _download(item.fileId, baseUrl),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(color: AppColors.text),
        title: Text(l10n.sessionFilesTitle, style: AppTextStyles.h3),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: body,
    );
  }
}

// ── File card ─────────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.item,
    required this.onViewText,
    required this.onDownload,
  });

  final _FileItem item;
  final VoidCallback? onViewText;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isImage = item.fileType == 'image';
    final isTask = item.source == 'task';
    final dateStr =
        DateFormat('dd MMM yyyy · HH:mm').format(item.uploadedAt);

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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + filename + source badge ─────────────
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isImage ? AppColors.orange : AppColors.blue)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isImage
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                    size: 20,
                    color: isImage ? AppColors.orange : AppColors.blue,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    item.fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(8),
                // Source badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isTask ? AppColors.info : AppColors.success)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isTask ? l10n.sourceTask : l10n.sourceAnswer,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isTask ? AppColors.info : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),

            // ── Context label ────────────────────────────────────────
            if (item.contextLabel != null &&
                item.contextLabel!.isNotEmpty) ...[
              const Gap(8),
              Row(
                children: [
                  Icon(
                    isTask
                        ? Icons.task_alt_outlined
                        : Icons.help_outline_rounded,
                    size: 13,
                    color: AppColors.muted,
                  ),
                  const Gap(5),
                  Expanded(
                    child: Text(
                      item.contextLabel!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted, height: 1.4),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],

            const Gap(10),
            const Divider(height: 1, color: AppColors.border),
            const Gap(10),

            // ── Meta row: date + uploader ────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppColors.muted),
                const Gap(4),
                Text(dateStr,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
                if (item.uploadedBy != null) ...[
                  const Gap(12),
                  const Icon(Icons.person_outline,
                      size: 12, color: AppColors.muted),
                  const Gap(4),
                  Expanded(
                    child: Text(
                      item.uploadedBy!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),

            const Gap(12),

            // ── Action buttons ───────────────────────────────────────
            Row(
              children: [
                if (onViewText != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewText,
                      icon: const Icon(Icons.article_outlined, size: 15),
                      label: Text(l10n.viewText),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const Gap(8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_outlined, size: 15),
                    label: Text(l10n.downloadFile),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text view dialog ──────────────────────────────────────────────────────────

class _TextViewDialog extends StatelessWidget {
  const _TextViewDialog({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined,
                      size: 18, color: Colors.white),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  content,
                  style: const TextStyle(fontSize: 13, height: 1.7),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
