import 'package:flutter/material.dart' show immutable;

// ── Status mapping ────────────────────────────────────────────────────────────
// Mirrors the task_statuses table: 1=To Do, 2=In Progress, 3=Pending Review,
// 4=Approved, 5=Overdue

enum WorkflowTaskStatus {
  todo,
  inProgress,
  pendingReview,
  approved,
  overdue;

  static WorkflowTaskStatus fromId(int id) => switch (id) {
        2 => inProgress,
        3 => pendingReview,
        4 => approved,
        5 => overdue,
        _ => todo, // 1 and any unknown → To Do
      };

  int get id => switch (this) {
        WorkflowTaskStatus.todo          => 1,
        WorkflowTaskStatus.inProgress    => 2,
        WorkflowTaskStatus.pendingReview => 3,
        WorkflowTaskStatus.approved      => 4,
        WorkflowTaskStatus.overdue       => 5,
      };

  String get label => switch (this) {
        WorkflowTaskStatus.todo          => 'To Do',
        WorkflowTaskStatus.inProgress    => 'In Progress',
        WorkflowTaskStatus.pendingReview => 'Pending Review',
        WorkflowTaskStatus.approved      => 'Approved',
        WorkflowTaskStatus.overdue       => 'Overdue',
      };
}

// ── Model ─────────────────────────────────────────────────────────────────────

@immutable
class WorkflowTask {
  final String id;
  final String workflowId;
  final String? workflowAnswerId;
  final String taskName;
  final String? whatToDo;
  final int statusId;
  final String? statusDescription;
  final DateTime? dueDate;
  final String? assignedToUserId;
  final String? assignedToUserName;
  final double? estimatedFine;
  final bool isRequired;
  final String? risk;
  final String? category;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int evidenceCount;
  final int? evidenceSufficiencyPcntg;

  const WorkflowTask({
    required this.id,
    required this.workflowId,
    this.workflowAnswerId,
    required this.taskName,
    this.whatToDo,
    required this.statusId,
    this.statusDescription,
    this.dueDate,
    this.assignedToUserId,
    this.assignedToUserName,
    this.estimatedFine,
    required this.isRequired,
    this.risk,
    this.category,
    required this.createdAt,
    required this.modifiedAt,
    this.evidenceCount = 0,
    this.evidenceSufficiencyPcntg,
  });

  WorkflowTaskStatus get status => WorkflowTaskStatus.fromId(statusId);

  factory WorkflowTask.fromJson(Map<String, dynamic> j) {
    return WorkflowTask(
      id: j['id'] as String,
      workflowId: j['workflowId'] as String,
      workflowAnswerId: j['workflowAnswerId'] as String?,
      taskName: j['taskName'] as String,
      whatToDo: j['whatToDo'] as String?,
      statusId: (j['statusId'] as num).toInt(),
      statusDescription: j['statusDescription'] as String?,
      dueDate: j['dueDate'] != null
          ? DateTime.tryParse(j['dueDate'] as String)
          : null,
      assignedToUserId: j['assignedToUserId'] as String?,
      assignedToUserName: j['assignedToUserName'] as String?,
      estimatedFine: j['estimatedFine'] != null
          ? (j['estimatedFine'] as num).toDouble()
          : null,
      isRequired: j['isRequired'] as bool? ?? false,
      risk: j['risk'] as String?,
      category: j['category'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      modifiedAt: DateTime.parse(j['modifiedAt'] as String),
      evidenceCount: (j['evidenceCount'] as num?)?.toInt() ?? 0,
      evidenceSufficiencyPcntg:
          (j['evidenceSufficiencyPcntg'] as num?)?.toInt(),
    );
  }
}

// ── Evidence model ────────────────────────────────────────────────────────────

@immutable
class TaskEvidence {
  final String id;
  final String taskId;
  final String fileLocation;
  final String fileName;
  final String? fileDescription;
  final DateTime createdAt;

  const TaskEvidence({
    required this.id,
    required this.taskId,
    required this.fileLocation,
    required this.fileName,
    this.fileDescription,
    required this.createdAt,
  });

  factory TaskEvidence.fromJson(Map<String, dynamic> j) {
    return TaskEvidence(
      id: j['id'] as String,
      taskId: j['taskId'] as String,
      fileLocation: j['fileLocation'] as String,
      fileName: j['fileName'] as String,
      fileDescription: j['fileDescription'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

// ── File-evidence model ───────────────────────────────────────────────────────

@immutable
class TaskFileEvidence {
  final String id;
  final String workflowTaskId;
  final String fileId;
  final String filePath;
  final String fileName;   // clean name without uuid prefix, from backend
  final String fileType;   // 'text' | 'image'
  final String? fileText;
  final String? imageDescription;
  final DateTime createdAt;

  const TaskFileEvidence({
    required this.id,
    required this.workflowTaskId,
    required this.fileId,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    this.fileText,
    this.imageDescription,
    required this.createdAt,
  });

  factory TaskFileEvidence.fromJson(Map<String, dynamic> j) => TaskFileEvidence(
        id: j['id'] as String,
        workflowTaskId: j['workflowTaskId'] as String,
        fileId: j['fileId'] as String,
        filePath: j['filePath'] as String? ?? '',
        fileName: j['fileName'] as String? ?? '',
        fileType: j['fileType'] as String? ?? 'text',
        fileText: j['fileText'] as String?,
        imageDescription: j['imageDescription'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ── groupByStatus extension ───────────────────────────────────────────────────

extension WorkflowTaskGrouping on List<WorkflowTask> {
  Map<WorkflowTaskStatus, List<WorkflowTask>> groupByStatus() {
    final map = <WorkflowTaskStatus, List<WorkflowTask>>{};
    for (final t in this) {
      map.putIfAbsent(t.status, () => []).add(t);
    }
    return map;
  }
}
