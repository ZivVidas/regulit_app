import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../api/api_client.dart';
import '../platform/open_in_browser.dart';

/// Non-dismissible dialog that opens the Gap Survey Report as **HTML in a
/// new browser tab** (RTL Hebrew renders natively in Chrome).
///
/// Why HTML instead of PDF? The WeasyPrint PDF path requires GTK system
/// libs and has had install issues on both the Windows dev box and the
/// Render container. The HTML preview endpoint produces the same content
/// (same template, same data, same LLM prose) and the browser handles RTL
/// and printing cleanly — including "Save as PDF" via Ctrl+P.
///
/// Flow:
///   1. POST nothing — call GET /workflow-answers/{id}/report/preview.html
///      (single request, no polling). The endpoint runs the LLM prompts
///      synchronously and returns the rendered HTML.
///   2. Open the response bytes in a new tab via `platformOpenInBrowser`.
///   3. Close this dialog.
///
/// Returns (via Navigator.pop):
///   * true  → HTML was successfully opened
///   * null  → user cancelled, or error
class GapReportDialog extends ConsumerStatefulWidget {
  final String sessionId;

  /// If true, skip the 3 LLM prompts on the backend — useful for fast
  /// visual iteration on layout (Prose sections render as "תוכן לא זמין").
  final bool skipLlm;

  const GapReportDialog({
    super.key,
    required this.sessionId,
    this.skipLlm = false,
  });

  @override
  ConsumerState<GapReportDialog> createState() => _GapReportDialogState();
}

class _GapReportDialogState extends ConsumerState<GapReportDialog> {
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  Future<void> _open() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url =
          '/workflow-answers/${widget.sessionId}/report/preview.html'
          '${widget.skipLlm ? '?skip_llm=true' : ''}';
      await platformOpenInBrowser(url: url, dio: ref.read(dioProvider));
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      _showError(_dioMessage(e));
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
        Text(
          l10n.reportInProgress,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        const Gap(6),
        Text(
          l10n.reportGenerating,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
        ),
        const Gap(10),
        Text(
          l10n.reportTakesAFewMinutes,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
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
              onPressed: _open,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ],
    );
  }
}
