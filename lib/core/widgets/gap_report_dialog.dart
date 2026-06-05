import 'dart:async';

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
/// ## Stage progress
/// The preview endpoint is a single synchronous GET — no server-sent
/// progress events. So the stage list is **driven client-side on a timer**,
/// using the per-stage durations the backend actually exhibits in practice
/// (data + analyze ≈ 2–3 s, each LLM prompt ≈ 12–20 s on gpt-4o, render
/// ≈ 1 s). The last stage stays "in progress" until the GET returns. When
/// the response arrives we flip the remaining stages to done before the
/// dialog closes, so the user gets a clean "all green" moment.
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

/// One stage of the report generation pipeline. The labels are derived from
/// l10n in [build] so we don't need to hold context here.
enum _Stage { data, analyze, orgDesc, actionPlan, execSummary, render }

/// Estimated duration *for each stage* (how long until we advance the
/// cursor). The last stage doesn't have a timer — it stays current until
/// the network call returns. Sums to ~45 s; real LLM walls vary.
const Map<_Stage, Duration> _stageDurations = {
  _Stage.data:        Duration(milliseconds: 1500),
  _Stage.analyze:     Duration(milliseconds: 1500),
  _Stage.orgDesc:     Duration(seconds: 12),
  _Stage.actionPlan:  Duration(seconds: 14),
  _Stage.execSummary: Duration(seconds: 14),
  // _Stage.render: open-ended (waits on the GET).
};

class _GapReportDialogState extends ConsumerState<GapReportDialog> {
  bool _busy = true;
  String? _error;

  /// Index into _Stage.values of the currently-running stage.
  int _currentStage = 0;
  Timer? _stageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _currentStage = 0;
    });
    _scheduleNextStage();

    try {
      final url =
          '/workflow-answers/${widget.sessionId}/report/preview.html'
          '${widget.skipLlm ? '?skip_llm=true' : ''}';
      await platformOpenInBrowser(url: url, dio: ref.read(dioProvider));
      // Success: jump cursor past the last stage so every row renders as
      // completed for one frame before we pop.
      if (mounted) {
        _stageTimer?.cancel();
        setState(() => _currentStage = _Stage.values.length);
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      _showError(_dioMessage(e));
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Schedules the timer to advance from [_currentStage] to the next one
  /// after that stage's estimated duration. The render stage (last) has no
  /// scheduled advance — it stays current until completion or error.
  void _scheduleNextStage() {
    _stageTimer?.cancel();
    if (_currentStage >= _Stage.values.length - 1) return; // last stage
    final stage = _Stage.values[_currentStage];
    final delay = _stageDurations[stage];
    if (delay == null) return;
    _stageTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _currentStage += 1);
      _scheduleNextStage();
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    _stageTimer?.cancel();
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

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1B3A6B)),
            ),
            const Gap(12),
            Expanded(
              child: Text(
                l10n.reportInProgress,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
            ),
          ],
        ),
        const Gap(16),
        // Stage checklist.
        ..._Stage.values.asMap().entries.map((e) {
          final idx = e.key;
          final stage = e.value;
          final state = idx < _currentStage
              ? _StageState.done
              : idx == _currentStage
                  ? _StageState.current
                  : _StageState.pending;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _StageRow(label: _stageLabel(l10n, stage), state: state),
          );
        }),
        const Gap(14),
        Text(
          l10n.reportTakesAFewMinutes,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  String _stageLabel(AppLocalizations l10n, _Stage stage) {
    switch (stage) {
      case _Stage.data:        return l10n.reportStageData;
      case _Stage.analyze:     return l10n.reportStageAnalyze;
      case _Stage.orgDesc:     return l10n.reportStageOrgDesc;
      case _Stage.actionPlan:  return l10n.reportStageActionPlan;
      case _Stage.execSummary: return l10n.reportStageExecSummary;
      case _Stage.render:      return l10n.reportStageRender;
    }
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

enum _StageState { pending, current, done }

class _StageRow extends StatelessWidget {
  final String label;
  final _StageState state;
  const _StageRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final (Widget icon, Color textColor, FontWeight weight) = switch (state) {
      _StageState.done => (
          const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
          AppColors.text,
          FontWeight.w500,
        ),
      _StageState.current => (
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B3A6B)),
          ),
          AppColors.text,
          FontWeight.w700,
        ),
      _StageState.pending => (
          Icon(Icons.radio_button_unchecked_rounded,
              size: 18, color: AppColors.muted.withValues(alpha: 0.5)),
          AppColors.muted,
          FontWeight.w400,
        ),
    };
    // Wrap the icon in a 22-wide box so all rows align even when the
    // current-stage spinner is smaller than the radio/check glyph.
    return Row(
      children: [
        SizedBox(width: 22, child: Center(child: icon)),
        const Gap(10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: textColor, fontWeight: weight),
          ),
        ),
      ],
    );
  }
}
