// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gap.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GapImpl _$$GapImplFromJson(Map<String, dynamic> json) => _$GapImpl(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      definitionId: json['definitionId'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: $enumDecode(_$GapCategoryEnumMap, json['category']),
      severity: $enumDecode(_$GapSeverityEnumMap, json['severity']),
      requirementType:
          $enumDecode(_$RequirementTypeEnumMap, json['requirementType']),
      regulationRefs: (json['regulationRefs'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      remediationSteps: json['remediationSteps'] as String,
      status: $enumDecode(_$GapStatusEnumMap, json['status']),
      financialExposure: (json['financialExposure'] as num).toDouble(),
      affectedRecords: (json['affectedRecords'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      identifiedAt: DateTime.parse(json['identifiedAt'] as String),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String),
    );

Map<String, dynamic> _$$GapImplToJson(_$GapImpl instance) => <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'definitionId': instance.definitionId,
      'code': instance.code,
      'title': instance.title,
      'description': instance.description,
      'category': _$GapCategoryEnumMap[instance.category]!,
      'severity': _$GapSeverityEnumMap[instance.severity]!,
      'requirementType': _$RequirementTypeEnumMap[instance.requirementType]!,
      'regulationRefs': instance.regulationRefs,
      'remediationSteps': instance.remediationSteps,
      'status': _$GapStatusEnumMap[instance.status]!,
      'financialExposure': instance.financialExposure,
      'affectedRecords': instance.affectedRecords,
      'notes': instance.notes,
      'identifiedAt': instance.identifiedAt.toIso8601String(),
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
    };

const _$GapCategoryEnumMap = {
  GapCategory.govern: 'govern',
  GapCategory.identity: 'identity',
  GapCategory.endpoint: 'endpoint',
  GapCategory.network: 'network',
  GapCategory.maintenance: 'maintenance',
  GapCategory.monitoring: 'monitoring',
  GapCategory.backup: 'backup',
  GapCategory.human: 'human',
};

const _$GapSeverityEnumMap = {
  GapSeverity.critical: 'critical',
  GapSeverity.high: 'high',
  GapSeverity.medium: 'medium',
  GapSeverity.low: 'low',
};

const _$RequirementTypeEnumMap = {
  RequirementType.required_: 'required',
  RequirementType.bestPractice: 'best_practice',
};

const _$GapStatusEnumMap = {
  GapStatus.open: 'open',
  GapStatus.inProgress: 'in_progress',
  GapStatus.resolved: 'resolved',
  GapStatus.acceptedRisk: 'accepted_risk',
};

_$GapSummaryImpl _$$GapSummaryImplFromJson(Map<String, dynamic> json) =>
    _$GapSummaryImpl(
      total: (json['total'] as num).toInt(),
      open: (json['open'] as num).toInt(),
      inProgress: (json['inProgress'] as num).toInt(),
      resolved: (json['resolved'] as num).toInt(),
      critical: (json['critical'] as num).toInt(),
      high: (json['high'] as num).toInt(),
      totalExposureNIS: (json['totalExposureNIS'] as num).toDouble(),
      resolvedExposureNIS: (json['resolvedExposureNIS'] as num).toDouble(),
      complianceScore: (json['complianceScore'] as num).toDouble(),
    );

Map<String, dynamic> _$$GapSummaryImplToJson(_$GapSummaryImpl instance) =>
    <String, dynamic>{
      'total': instance.total,
      'open': instance.open,
      'inProgress': instance.inProgress,
      'resolved': instance.resolved,
      'critical': instance.critical,
      'high': instance.high,
      'totalExposureNIS': instance.totalExposureNIS,
      'resolvedExposureNIS': instance.resolvedExposureNIS,
      'complianceScore': instance.complianceScore,
    };
