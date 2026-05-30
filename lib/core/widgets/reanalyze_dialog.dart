import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../api/api_client.dart';

/// A self-contained, non-dismissible dialog that re-runs the workflow
/// analysis for a session.
///
/// Flow:
///   1. POST /workflow-answers/{sessionId}/reanalyze
///        - 409  → "analysis already in progress" error state
///        - 202  → start polling
///   2. Poll GET /workflow-answers/{sessionId}/analyze-status every 5s
///        - pending=true  → keep spinning
///        - pending=false + failed → error state
///        - pending=false + ok     → pop(tasksCreated)
///   3. Times out after ~6 minutes.
///
/// Returns (via Navigator.pop):
///   * int  → number of tasks created (success)
///   * null → cancelled / error / timeout
///
/// Usage:
/// ```dart
/// final created = await showDialog<int>(
///   context: context,
///   barrierDismissible: false,
///   builder: (_) => ReanalyzeDialog(sessionId: id),
/// );
/// if (created != null) { /* refresh providers */ }
/// ```
class ReanalyzeDialog extends ConsumerStatefulWidget {
  final String sessionId;

  const ReanalyzeDialog({super.key, required this.sessionId});

  @override
  ConsumerState<ReanalyzeDialog> createState() => _ReanalyzeDialogState();
}

class _ReanalyzeDialogState extends ConsumerState<ReanalyzeDialog> {
  bool _running = true;
  String? _error;

  Timer? _pollTimer;
  int _pollCount = 0;

  // 5 s × 72 polls = ~6 minutes maximum wait.
  static const _kPollInterval = Duration(seconds: 5);
  static const _kMaxPolls = 72;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final dio = ref.read(dioProvider);
    final l10n = AppLocalizations.of(context);

    // The reanalyze endpoint returns immediately (background task). Use a
    // short timeout so a hung request doesn't block the dialog forever.
    final origConnect = dio.options.connectTimeout;
    final origReceive = dio.options.receiveTimeout;
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);

    try {
      await dio.post<Map<String, dynamic>>(
        '/workflow-answers/${widget.sessionId}/reanalyze',
      );
      // 202 accepted → poll for completion.
      _startPolling();
    } on DioException catch (e) {
      String msg;
      if (e.response?.statusCode == 409) {
        msg = l10n.reanalyzeInProgressError;
      } else {
        final data = e.response?.data;
        final detail = data is Map ? data['detail']?.toString() : null;
        msg = detail ?? (e.message ?? l10n.reanalyzeFailed);
      }
      if (mounted) {
        setState(() {
          _running = false;
          _error = msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      dio.options.connectTimeout = origConnect;
      dio.options.receiveTimeout = origReceive;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(_kPollInterval, (_) async {
      _pollCount++;
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      if (_pollCount >= _kMaxPolls) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _running = false;
            _error = AppLocalizations.of(context).analysisTimedOut;
          });
        }
        return;
      }
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get<Map<String, dynamic>>(
          '/workflow-answers/${widget.sessionId}/analyze-status',
        );
        final pending = res.data?['pending'] as bool? ?? true;
        if (!pending && mounted) {
          _pollTimer?.cancel();
          final failed = res.data?['failed'] as bool? ?? false;
          final created = res.data?['tasksCreated'] as int? ?? 0;
          if (failed) {
            setState(() {
              _running = false;
              _error = AppLocalizations.of(context).reanalyzeFailed;
            });
          } else {
            Navigator.of(context).pop(created); // success
          }
        }
      } catch (_) {
        // Ignore transient poll errors — keep polling until timeout.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _running ? _buildRunning(l10n) : _buildError(l10n),
        ),
      ),
    );
  }

  Widget _buildRunning(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF7C3AED),
          ),
        ),
        const Gap(20),
        Text(
          l10n.reanalyzeRunning,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const Gap(8),
        Text(
          l10n.reanalyzeRunningSub,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded,
            size: 40, color: AppColors.danger),
        const Gap(16),
        Text(
          _error ?? l10n.reanalyzeFailed,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.text,
            height: 1.5,
          ),
        ),
        const Gap(20),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ),
      ],
    );
  }
}
