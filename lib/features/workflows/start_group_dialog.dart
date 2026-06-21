import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/models/workflow_answer_group.dart';
import '../../l10n/app_localizations.dart';

/// Step 41 — confirmation dialog before creating a new workflow_answer_group.
///
/// Shows the list of envs that will each get their own answering session,
/// then POSTs `/workflow-answer-groups`. Returns the created
/// `WorkflowAnswerGroupFull` to the caller via `Navigator.pop` (or `null`
/// if the user cancels).
///
/// Usage:
/// ```dart
/// final group = await showDialog<WorkflowAnswerGroupFull>(
///   context: context,
///   builder: (_) => StartGroupDialog(
///     workflowId: wf.id,
///     workflowName: wf.name,
///     customerId: customer.id,
///     envNames: customer.envs.map((e) => e.envName).toList(),
///     dio: ref.read(dioProvider),
///   ),
/// );
/// if (group != null) {
///   // → navigate to the survey screen with group.id (Phase 9)
/// }
/// ```
///
/// All strings are hardcoded English placeholders. Phase 11 will replace
/// them with `AppLocalizations.of(context)!.<key>` lookups.
class StartGroupDialog extends StatefulWidget {
  final String workflowId;
  final String workflowName;
  final String customerId;
  final List<String> envNames;
  final Dio dio;

  const StartGroupDialog({
    super.key,
    required this.workflowId,
    required this.workflowName,
    required this.customerId,
    required this.envNames,
    required this.dio,
  });

  @override
  State<StartGroupDialog> createState() => _StartGroupDialogState();
}

class _StartGroupDialogState extends State<StartGroupDialog> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final resp = await widget.dio.post<Map<String, dynamic>>(
        '/workflow-answer-groups',
        data: {
          'workflowId': widget.workflowId,
          'customerId': widget.customerId,
        },
      );
      final group = WorkflowAnswerGroupFull.fromJson(resp.data!);
      if (mounted) Navigator.of(context).pop(group);
    } on DioException catch (e) {
      // Surface backend 422 messages (e.g., "Customer has no data
      // environments configured.") inline so the user knows what to fix.
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      setState(() {
        _error = detail ?? 'Failed to start: ${e.message ?? e.toString()}';
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to start: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.startWorkflow(widget.workflowName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.startGroupHint),
          const SizedBox(height: 12),
          ...widget.envNames.map((n) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $n'),
              )),
          const SizedBox(height: 12),
          Text(
            l10n.startGroupSwitchHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.start),
        ),
      ],
    );
  }
}
