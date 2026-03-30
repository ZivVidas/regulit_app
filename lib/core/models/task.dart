import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

enum TaskStatus {
  @JsonValue('open') open,
  @JsonValue('in_progress') inProgress,
  @JsonValue('pending_review') pendingReview,
  @JsonValue('approved') approved,
  @JsonValue('rejected') rejected,
  @JsonValue('overdue') overdue,
}

enum TaskPriority {
  @JsonValue('critical') critical,
  @JsonValue('high') high,
  @JsonValue('medium') medium,
  @JsonValue('low') low,
}

extension TaskStatusX on TaskStatus {
  String get label => switch (this) {
    TaskStatus.open          => 'To Do',
    TaskStatus.inProgress    => 'In Progress',
    TaskStatus.pendingReview => 'Pending Review',
    TaskStatus.approved      => 'Approved',
    TaskStatus.rejected      => 'Rejected',
    TaskStatus.overdue       => 'Overdue',
  };

  bool get isTerminal => this == TaskStatus.approved;
  bool get needsAttention => [TaskStatus.overdue, TaskStatus.rejected].contains(this);
}

@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String tenantId,
    required String gapId,

    required String title,
    required String description,
    required TaskStatus status,
    required TaskPriority priority,

    // RACI
    String? responsibleId,    // R — does the work
    String? responsibleName,
    String? accountableId,    // A — signs off
    String? accountableName,

    required DateTime createdAt,
    DateTime? dueDate,
    DateTime? completedAt,

    double? estimatedCostNIS,

    // Denormalised from gap
    required String gapCode,
    required String gapTitle,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

@freezed
class Evidence with _$Evidence {
  const factory Evidence({
    required String id,
    required String taskId,
    required String uploaderId,
    required String uploaderName,
    required String fileUrl,
    required String fileName,
    required String fileType,
    String? notes,
    required String status, // pending | approved | rejected
    String? reviewNote,
    String? reviewedById,
    required DateTime uploadedAt,
  }) = _Evidence;

  factory Evidence.fromJson(Map<String, dynamic> json) =>
      _$EvidenceFromJson(json);
}

/// Groups tasks by status for the kanban board
extension TaskListX on List<Task> {
  Map<TaskStatus, List<Task>> groupByStatus() {
    final map = <TaskStatus, List<Task>>{};
    for (final status in TaskStatus.values) {
      map[status] = where((t) => t.status == status).toList();
    }
    return map;
  }
}
