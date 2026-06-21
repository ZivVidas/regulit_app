// Step 41 — Dart models for the grouped workflow-answers API.
//
// Mirrors the backend Pydantic schemas in
// `regulit_api/schemas/workflow_answer_group.py`.
//
// Note on `sessions`: each entry is a raw `Map<String, dynamic>` because
// the existing Flutter survey screen reads workflow_answer payloads as
// raw maps (there is no typed `WorkflowAnswerFull` Dart class). Phase 9
// indexes into these maps by `id` to switch the active env-session.

class EnvSessionSummary {
  /// Lightweight summary of one env-session in a group.
  /// Used by the env-switcher chip strip (Phase 9).
  final String sessionId;
  final String envId;
  final String envName;
  final int answeredCount;
  final bool isAnalyzed;

  EnvSessionSummary({
    required this.sessionId,
    required this.envId,
    required this.envName,
    required this.answeredCount,
    required this.isAnalyzed,
  });

  factory EnvSessionSummary.fromJson(Map<String, dynamic> j) => EnvSessionSummary(
        sessionId: j['sessionId'] as String,
        envId: j['envId'] as String,
        envName: j['envName'] as String,
        answeredCount: (j['answeredCount'] ?? 0) as int,
        isAnalyzed: (j['isAnalyzed'] ?? false) as bool,
      );
}

class WorkflowAnswerGroup {
  /// Lightweight group — mirrors backend `WorkflowAnswerGroupOut`.
  /// Used by `GET /workflow-answer-groups/by-customer/{id}` and the
  /// activate endpoint.
  final String id;
  final String workflowId;
  final String customerId;
  final bool isActive;
  final String? displayName;
  final String datedCreated;
  final String dateModified;
  final List<EnvSessionSummary> envSessions;

  WorkflowAnswerGroup({
    required this.id,
    required this.workflowId,
    required this.customerId,
    required this.isActive,
    this.displayName,
    required this.datedCreated,
    required this.dateModified,
    required this.envSessions,
  });

  factory WorkflowAnswerGroup.fromJson(Map<String, dynamic> j) => WorkflowAnswerGroup(
        id: j['id'] as String,
        workflowId: j['workflowId'] as String,
        customerId: j['customerId'] as String,
        isActive: (j['isActive'] ?? false) as bool,
        displayName: j['displayName'] as String?,
        datedCreated: j['datedCreated'] as String,
        dateModified: j['dateModified'] as String,
        envSessions: ((j['envSessions'] ?? const []) as List)
            .map((e) => EnvSessionSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WorkflowAnswerGroupFull {
  /// Full group payload — mirrors backend `WorkflowAnswerGroupFull`.
  /// Returned by `POST /workflow-answer-groups` and `GET /{id}`.
  ///
  /// `sessions` is held as a `List<Map<String, dynamic>>` rather than a
  /// typed model list because the project's survey screen consumes
  /// workflow_answer payloads as raw maps (no `WorkflowAnswerFull` Dart
  /// class exists). Phase 9 looks up the active session by `id` field
  /// inside each map.
  ///
  /// `envSessions` is a parallel lightweight index — same data as the
  /// `WorkflowAnswerGroupOut` shape — so the env-switcher chip strip
  /// can render env names + progress badges without parsing each raw
  /// session map.
  final String id;
  final String workflowId;
  final String workflowName;
  final String customerId;
  final bool isActive;
  final String? displayName;
  final String datedCreated;
  final String dateModified;
  final List<EnvSessionSummary> envSessions;
  final List<Map<String, dynamic>> sessions;

  WorkflowAnswerGroupFull({
    required this.id,
    required this.workflowId,
    required this.workflowName,
    required this.customerId,
    required this.isActive,
    this.displayName,
    required this.datedCreated,
    required this.dateModified,
    required this.envSessions,
    required this.sessions,
  });

  factory WorkflowAnswerGroupFull.fromJson(Map<String, dynamic> j) =>
      WorkflowAnswerGroupFull(
        id: j['id'] as String,
        workflowId: j['workflowId'] as String,
        workflowName: j['workflowName'] as String,
        customerId: j['customerId'] as String,
        isActive: (j['isActive'] ?? false) as bool,
        displayName: j['displayName'] as String?,
        datedCreated: j['datedCreated'] as String,
        dateModified: j['dateModified'] as String,
        envSessions: ((j['envSessions'] ?? const []) as List)
            .map((e) => EnvSessionSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        sessions: ((j['sessions'] ?? const []) as List)
            .cast<Map<String, dynamic>>(),
      );
}

/// One env's slice of the analyze status. The Flutter progress panel
/// renders these in a list under the overall "Running analysis for N
/// environments…" header.
class GroupAnalyzeStatusPerEnv {
  final String envName;
  /// "queued" | "pending" | "done" | "failed"
  final String status;
  final int tasks;

  GroupAnalyzeStatusPerEnv({
    required this.envName,
    required this.status,
    required this.tasks,
  });

  factory GroupAnalyzeStatusPerEnv.fromJson(Map<String, dynamic> j) =>
      GroupAnalyzeStatusPerEnv(
        envName: j['envName'] as String,
        status: j['status'] as String,
        tasks: (j['tasks'] ?? 0) as int,
      );
}

class GroupAnalyzeStatus {
  final bool pending;
  final bool failed;
  final int tasksCreated;
  final List<GroupAnalyzeStatusPerEnv> perEnv;

  GroupAnalyzeStatus({
    required this.pending,
    required this.failed,
    required this.tasksCreated,
    required this.perEnv,
  });

  factory GroupAnalyzeStatus.fromJson(Map<String, dynamic> j) => GroupAnalyzeStatus(
        pending: (j['pending'] ?? false) as bool,
        failed: (j['failed'] ?? false) as bool,
        tasksCreated: (j['tasksCreated'] ?? 0) as int,
        perEnv: ((j['perEnv'] ?? const []) as List)
            .map((e) => GroupAnalyzeStatusPerEnv.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
