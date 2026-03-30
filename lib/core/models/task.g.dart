// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskImpl _$$TaskImplFromJson(Map<String, dynamic> json) => _$TaskImpl(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      gapId: json['gapId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: $enumDecode(_$TaskStatusEnumMap, json['status']),
      priority: $enumDecode(_$TaskPriorityEnumMap, json['priority']),
      responsibleId: json['responsibleId'] as String?,
      responsibleName: json['responsibleName'] as String?,
      accountableId: json['accountableId'] as String?,
      accountableName: json['accountableName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      estimatedCostNIS: (json['estimatedCostNIS'] as num?)?.toDouble(),
      gapCode: json['gapCode'] as String,
      gapTitle: json['gapTitle'] as String,
    );

Map<String, dynamic> _$$TaskImplToJson(_$TaskImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'gapId': instance.gapId,
      'title': instance.title,
      'description': instance.description,
      'status': _$TaskStatusEnumMap[instance.status]!,
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'responsibleId': instance.responsibleId,
      'responsibleName': instance.responsibleName,
      'accountableId': instance.accountableId,
      'accountableName': instance.accountableName,
      'createdAt': instance.createdAt.toIso8601String(),
      'dueDate': instance.dueDate?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'estimatedCostNIS': instance.estimatedCostNIS,
      'gapCode': instance.gapCode,
      'gapTitle': instance.gapTitle,
    };

const _$TaskStatusEnumMap = {
  TaskStatus.open: 'open',
  TaskStatus.inProgress: 'in_progress',
  TaskStatus.pendingReview: 'pending_review',
  TaskStatus.approved: 'approved',
  TaskStatus.rejected: 'rejected',
  TaskStatus.overdue: 'overdue',
};

const _$TaskPriorityEnumMap = {
  TaskPriority.critical: 'critical',
  TaskPriority.high: 'high',
  TaskPriority.medium: 'medium',
  TaskPriority.low: 'low',
};

_$EvidenceImpl _$$EvidenceImplFromJson(Map<String, dynamic> json) =>
    _$EvidenceImpl(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      uploaderId: json['uploaderId'] as String,
      uploaderName: json['uploaderName'] as String,
      fileUrl: json['fileUrl'] as String,
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      reviewNote: json['reviewNote'] as String?,
      reviewedById: json['reviewedById'] as String?,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );

Map<String, dynamic> _$$EvidenceImplToJson(_$EvidenceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'taskId': instance.taskId,
      'uploaderId': instance.uploaderId,
      'uploaderName': instance.uploaderName,
      'fileUrl': instance.fileUrl,
      'fileName': instance.fileName,
      'fileType': instance.fileType,
      'notes': instance.notes,
      'status': instance.status,
      'reviewNote': instance.reviewNote,
      'reviewedById': instance.reviewedById,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
    };
