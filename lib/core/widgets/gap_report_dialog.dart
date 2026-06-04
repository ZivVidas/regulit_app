import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../api/api_client.dart';
import '../platform/file_download.dart';

/// A self-contained, non-dismissible dialog that:
///   1. POSTs /workflow-answers/{sessionId}/generate-report
///   2. Polls /report-status every 4 s until done/failed (6-min timeout)
///   3. On 'done' → fetches the PDF (auth'd Dio) and triggers a browser save-as
///   4. On 'failed' → shows error + a Retry button (force=true on retry)
///
/// Returns (via Navigator.pop):
///   * true  → PDF was successfully downloaded
///   * null  → user cancelled, or error/timeout
class GapReportDialog extends ConsumerStatefulWidget {
  final String sessionId;

  const GapReportDialog({super.key, required this.sessionId});

  @override
  ConsumerState<GapReportDialog> createState() => _GapReportDialogState();
}

class _GapReportDialogState extends ConsumerState<GapReportDialog> {
  bool _busy = true;
  String? _error;
  String? _statusLabel;   // shown under the spinner ("scheduling…", "rendering…")

  Timer? _pollTimer;
  int _pollCount = 0;

  // 4 s × 90 polls = 6 minutes max.
  static const _kPollInterval = Duration(seconds: 4);
  static const _kMaxPolls = 90;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start(force: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Kick off generation, then start polling.
  /// force=true re-generates even if a 'done' report already exists.
  Future<void> _start({required bool force}) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _statusLabel = AppLocalizations.of(context).reportScheduling;
    });
    final dio = ref.read(dioProvider);
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/workflow-answers/${widget.sessionId}/generate-report'
        '${force ? '?force=true' : ''}',
      );
      final status = res.data?['status'] as String? ?? 'pending';
      if (status == 'done' && !force) {
        await _downloadAndClose();
        return;
      }
      _startPolling();
    } on DioException catch (e) {
      _showError(_dioMessage(e));
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    if (mounted) {
      setState(() => _statusLabel = AppLocalizations.of(context).reportGenerating);
    }
    _pollTimer = Timer.periodic(_kPollInterval, (_) async {
      _pollCount++;
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      if (_pollCount >= _kMaxPolls) {
        _pollTimer?.cancel();
        _showError(AppLocalizations.of(context).analysisTimedOut);
        return;
      }
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get<Map<String, dynamic>>(
          '/workflow-answers/${widget.sessionId}/report-status',
        );
        final status = res.data?['status'] as String? ?? 'pending';
        if (status == 'done') {
          _pollTimer?.cancel();
          await _downloadAndClose();
        } else if (status == 'failed') {
          _pollTimer?.cancel();
          _showError(
            (res.data?['errorMessage'] as String?) ??
                AppLocalizations.of(context).reportFailed,
          );
        }
        // 'pending' / 'processing' → keep polling silently
      } catch (_) {
        // transient — keep polling until timeout
      }
    });
  }

  Future<void> _downloadAndClose() async {
    if (!mounted) return;
    setState(() => _statusLabel = AppLocalizations.of(context).reportDownloading);
    try {
      await platformDownload(
        url: '/workflow-answers/${widget.sessionId}/report/download',
        fileName: 'gap_report_${widget.sessionId}.pdf',
        dio: ref.read(dioProvider),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = msg;
    });
  }

  static String _dioMessage(DioException e) {
    final data = e.response?.data;
    final detail = data is Map ? data['detail']?.toString() : null;
    return detail ?? e.message ?? 'Network error';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _busy ? _buildBusy(l10n) : _buildError(l10n),
        ),
      ),
    );
  }

  Widget _buildBusy(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 36, height: 36,
          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1B3A6B)),
        ),
        const Gap(20),
        Text(l10n.reportInProgress,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        const Gap(6),
        Text(
          _statusLabel ?? l10n.reportGenerating,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
        ),
        const Gap(10),
        Text(
          l10n.reportTakesAFewMinutes,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.danger),
        const Gap(14),
        Text(l10n.reportFailed,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
        const Gap(6),
        Text(
          _error ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
        ),
        const Gap(20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            const Gap(8),
            FilledButton.icon(
              onPressed: () => _start(force: true),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ],
    );
  }
}
