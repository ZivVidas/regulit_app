import 'package:freezed_annotation/freezed_annotation.dart';

part 'gap.freezed.dart';
part 'gap.g.dart';

enum GapSeverity {
  @JsonValue('critical') critical,
  @JsonValue('high') high,
  @JsonValue('medium') medium,
  @JsonValue('low') low,
}

enum GapStatus {
  @JsonValue('open') open,
  @JsonValue('in_progress') inProgress,
  @JsonValue('resolved') resolved,
  @JsonValue('accepted_risk') acceptedRisk,
}

enum RequirementType {
  @JsonValue('required') required_,
  @JsonValue('best_practice') bestPractice,
}

enum GapCategory {
  @JsonValue('govern') govern,
  @JsonValue('identity') identity,
  @JsonValue('endpoint') endpoint,
  @JsonValue('network') network,
  @JsonValue('maintenance') maintenance,
  @JsonValue('monitoring') monitoring,
  @JsonValue('backup') backup,
  @JsonValue('human') human,
}

extension GapSeverityX on GapSeverity {
  String get label => switch (this) {
    GapSeverity.critical => 'Critical',
    GapSeverity.high     => 'High',
    GapSeverity.medium   => 'Medium',
    GapSeverity.low      => 'Low',
  };
}

extension GapCategoryX on GapCategory {
  String get label => switch (this) {
    GapCategory.govern      => 'Govern & Legal',
    GapCategory.identity    => 'Identity & Access',
    GapCategory.endpoint    => 'Endpoint Security',
    GapCategory.network     => 'Network Security',
    GapCategory.maintenance => 'Maintenance',
    GapCategory.monitoring  => 'Monitoring & Logging',
    GapCategory.backup      => 'Backup & Recovery',
    GapCategory.human       => 'Human Factor',
  };

  String get code => switch (this) {
    GapCategory.govern      => 'A',
    GapCategory.identity    => 'B',
    GapCategory.endpoint    => 'C',
    GapCategory.network     => 'E',
    GapCategory.maintenance => 'D',
    GapCategory.monitoring  => 'F',
    GapCategory.backup      => 'G',
    GapCategory.human       => 'H',
  };
}

/// A single gap returned from the API (client-specific instance)
@freezed
class Gap with _$Gap {
  const factory Gap({
    required String id,
    required String tenantId,
    required String definitionId,

    // From gap_definitions (joined server-side)
    required String code,           // e.g. 'A2', 'B1'
    required String title,
    required String description,
    required GapCategory category,
    required GapSeverity severity,
    required RequirementType requirementType,
    required List<String> regulationRefs,
    required String remediationSteps,

    // Client-specific
    required GapStatus status,
    required double financialExposure,  // ₪
    int? affectedRecords,
    String? notes,

    required DateTime identifiedAt,
    DateTime? resolvedAt,
  }) = _Gap;

  factory Gap.fromJson(Map<String, dynamic> json) => _$GapFromJson(json);
}

/// Summary stats for the dashboard
@freezed
class GapSummary with _$GapSummary {
  const factory GapSummary({
    required int total,
    required int open,
    required int inProgress,
    required int resolved,
    required int critical,
    required int high,
    required double totalExposureNIS,
    required double resolvedExposureNIS,
    required double complianceScore, // 0.0 – 1.0
  }) = _GapSummary;

  factory GapSummary.fromJson(Map<String, dynamic> json) =>
      _$GapSummaryFromJson(json);
}
