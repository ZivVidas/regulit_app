// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gap.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Gap _$GapFromJson(Map<String, dynamic> json) {
  return _Gap.fromJson(json);
}

/// @nodoc
mixin _$Gap {
  String get id => throw _privateConstructorUsedError;
  String get tenantId => throw _privateConstructorUsedError;
  String get definitionId =>
      throw _privateConstructorUsedError; // From gap_definitions (joined server-side)
  String get code => throw _privateConstructorUsedError; // e.g. 'A2', 'B1'
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  GapCategory get category => throw _privateConstructorUsedError;
  GapSeverity get severity => throw _privateConstructorUsedError;
  RequirementType get requirementType => throw _privateConstructorUsedError;
  List<String> get regulationRefs => throw _privateConstructorUsedError;
  String get remediationSteps =>
      throw _privateConstructorUsedError; // Client-specific
  GapStatus get status => throw _privateConstructorUsedError;
  double get financialExposure => throw _privateConstructorUsedError; // ₪
  int? get affectedRecords => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DateTime get identifiedAt => throw _privateConstructorUsedError;
  DateTime? get resolvedAt => throw _privateConstructorUsedError;

  /// Serializes this Gap to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Gap
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GapCopyWith<Gap> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GapCopyWith<$Res> {
  factory $GapCopyWith(Gap value, $Res Function(Gap) then) =
      _$GapCopyWithImpl<$Res, Gap>;
  @useResult
  $Res call(
      {String id,
      String tenantId,
      String definitionId,
      String code,
      String title,
      String description,
      GapCategory category,
      GapSeverity severity,
      RequirementType requirementType,
      List<String> regulationRefs,
      String remediationSteps,
      GapStatus status,
      double financialExposure,
      int? affectedRecords,
      String? notes,
      DateTime identifiedAt,
      DateTime? resolvedAt});
}

/// @nodoc
class _$GapCopyWithImpl<$Res, $Val extends Gap> implements $GapCopyWith<$Res> {
  _$GapCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Gap
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? definitionId = null,
    Object? code = null,
    Object? title = null,
    Object? description = null,
    Object? category = null,
    Object? severity = null,
    Object? requirementType = null,
    Object? regulationRefs = null,
    Object? remediationSteps = null,
    Object? status = null,
    Object? financialExposure = null,
    Object? affectedRecords = freezed,
    Object? notes = freezed,
    Object? identifiedAt = null,
    Object? resolvedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      definitionId: null == definitionId
          ? _value.definitionId
          : definitionId // ignore: cast_nullable_to_non_nullable
              as String,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as GapCategory,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as GapSeverity,
      requirementType: null == requirementType
          ? _value.requirementType
          : requirementType // ignore: cast_nullable_to_non_nullable
              as RequirementType,
      regulationRefs: null == regulationRefs
          ? _value.regulationRefs
          : regulationRefs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      remediationSteps: null == remediationSteps
          ? _value.remediationSteps
          : remediationSteps // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as GapStatus,
      financialExposure: null == financialExposure
          ? _value.financialExposure
          : financialExposure // ignore: cast_nullable_to_non_nullable
              as double,
      affectedRecords: freezed == affectedRecords
          ? _value.affectedRecords
          : affectedRecords // ignore: cast_nullable_to_non_nullable
              as int?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      identifiedAt: null == identifiedAt
          ? _value.identifiedAt
          : identifiedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedAt: freezed == resolvedAt
          ? _value.resolvedAt
          : resolvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GapImplCopyWith<$Res> implements $GapCopyWith<$Res> {
  factory _$$GapImplCopyWith(_$GapImpl value, $Res Function(_$GapImpl) then) =
      __$$GapImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String tenantId,
      String definitionId,
      String code,
      String title,
      String description,
      GapCategory category,
      GapSeverity severity,
      RequirementType requirementType,
      List<String> regulationRefs,
      String remediationSteps,
      GapStatus status,
      double financialExposure,
      int? affectedRecords,
      String? notes,
      DateTime identifiedAt,
      DateTime? resolvedAt});
}

/// @nodoc
class __$$GapImplCopyWithImpl<$Res> extends _$GapCopyWithImpl<$Res, _$GapImpl>
    implements _$$GapImplCopyWith<$Res> {
  __$$GapImplCopyWithImpl(_$GapImpl _value, $Res Function(_$GapImpl) _then)
      : super(_value, _then);

  /// Create a copy of Gap
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? definitionId = null,
    Object? code = null,
    Object? title = null,
    Object? description = null,
    Object? category = null,
    Object? severity = null,
    Object? requirementType = null,
    Object? regulationRefs = null,
    Object? remediationSteps = null,
    Object? status = null,
    Object? financialExposure = null,
    Object? affectedRecords = freezed,
    Object? notes = freezed,
    Object? identifiedAt = null,
    Object? resolvedAt = freezed,
  }) {
    return _then(_$GapImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      definitionId: null == definitionId
          ? _value.definitionId
          : definitionId // ignore: cast_nullable_to_non_nullable
              as String,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as GapCategory,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as GapSeverity,
      requirementType: null == requirementType
          ? _value.requirementType
          : requirementType // ignore: cast_nullable_to_non_nullable
              as RequirementType,
      regulationRefs: null == regulationRefs
          ? _value._regulationRefs
          : regulationRefs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      remediationSteps: null == remediationSteps
          ? _value.remediationSteps
          : remediationSteps // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as GapStatus,
      financialExposure: null == financialExposure
          ? _value.financialExposure
          : financialExposure // ignore: cast_nullable_to_non_nullable
              as double,
      affectedRecords: freezed == affectedRecords
          ? _value.affectedRecords
          : affectedRecords // ignore: cast_nullable_to_non_nullable
              as int?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      identifiedAt: null == identifiedAt
          ? _value.identifiedAt
          : identifiedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      resolvedAt: freezed == resolvedAt
          ? _value.resolvedAt
          : resolvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GapImpl implements _Gap {
  const _$GapImpl(
      {required this.id,
      required this.tenantId,
      required this.definitionId,
      required this.code,
      required this.title,
      required this.description,
      required this.category,
      required this.severity,
      required this.requirementType,
      required final List<String> regulationRefs,
      required this.remediationSteps,
      required this.status,
      required this.financialExposure,
      this.affectedRecords,
      this.notes,
      required this.identifiedAt,
      this.resolvedAt})
      : _regulationRefs = regulationRefs;

  factory _$GapImpl.fromJson(Map<String, dynamic> json) =>
      _$$GapImplFromJson(json);

  @override
  final String id;
  @override
  final String tenantId;
  @override
  final String definitionId;
// From gap_definitions (joined server-side)
  @override
  final String code;
// e.g. 'A2', 'B1'
  @override
  final String title;
  @override
  final String description;
  @override
  final GapCategory category;
  @override
  final GapSeverity severity;
  @override
  final RequirementType requirementType;
  final List<String> _regulationRefs;
  @override
  List<String> get regulationRefs {
    if (_regulationRefs is EqualUnmodifiableListView) return _regulationRefs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_regulationRefs);
  }

  @override
  final String remediationSteps;
// Client-specific
  @override
  final GapStatus status;
  @override
  final double financialExposure;
// ₪
  @override
  final int? affectedRecords;
  @override
  final String? notes;
  @override
  final DateTime identifiedAt;
  @override
  final DateTime? resolvedAt;

  @override
  String toString() {
    return 'Gap(id: $id, tenantId: $tenantId, definitionId: $definitionId, code: $code, title: $title, description: $description, category: $category, severity: $severity, requirementType: $requirementType, regulationRefs: $regulationRefs, remediationSteps: $remediationSteps, status: $status, financialExposure: $financialExposure, affectedRecords: $affectedRecords, notes: $notes, identifiedAt: $identifiedAt, resolvedAt: $resolvedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GapImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.definitionId, definitionId) ||
                other.definitionId == definitionId) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.requirementType, requirementType) ||
                other.requirementType == requirementType) &&
            const DeepCollectionEquality()
                .equals(other._regulationRefs, _regulationRefs) &&
            (identical(other.remediationSteps, remediationSteps) ||
                other.remediationSteps == remediationSteps) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.financialExposure, financialExposure) ||
                other.financialExposure == financialExposure) &&
            (identical(other.affectedRecords, affectedRecords) ||
                other.affectedRecords == affectedRecords) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.identifiedAt, identifiedAt) ||
                other.identifiedAt == identifiedAt) &&
            (identical(other.resolvedAt, resolvedAt) ||
                other.resolvedAt == resolvedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      definitionId,
      code,
      title,
      description,
      category,
      severity,
      requirementType,
      const DeepCollectionEquality().hash(_regulationRefs),
      remediationSteps,
      status,
      financialExposure,
      affectedRecords,
      notes,
      identifiedAt,
      resolvedAt);

  /// Create a copy of Gap
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GapImplCopyWith<_$GapImpl> get copyWith =>
      __$$GapImplCopyWithImpl<_$GapImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GapImplToJson(
      this,
    );
  }
}

abstract class _Gap implements Gap {
  const factory _Gap(
      {required final String id,
      required final String tenantId,
      required final String definitionId,
      required final String code,
      required final String title,
      required final String description,
      required final GapCategory category,
      required final GapSeverity severity,
      required final RequirementType requirementType,
      required final List<String> regulationRefs,
      required final String remediationSteps,
      required final GapStatus status,
      required final double financialExposure,
      final int? affectedRecords,
      final String? notes,
      required final DateTime identifiedAt,
      final DateTime? resolvedAt}) = _$GapImpl;

  factory _Gap.fromJson(Map<String, dynamic> json) = _$GapImpl.fromJson;

  @override
  String get id;
  @override
  String get tenantId;
  @override
  String get definitionId; // From gap_definitions (joined server-side)
  @override
  String get code; // e.g. 'A2', 'B1'
  @override
  String get title;
  @override
  String get description;
  @override
  GapCategory get category;
  @override
  GapSeverity get severity;
  @override
  RequirementType get requirementType;
  @override
  List<String> get regulationRefs;
  @override
  String get remediationSteps; // Client-specific
  @override
  GapStatus get status;
  @override
  double get financialExposure; // ₪
  @override
  int? get affectedRecords;
  @override
  String? get notes;
  @override
  DateTime get identifiedAt;
  @override
  DateTime? get resolvedAt;

  /// Create a copy of Gap
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GapImplCopyWith<_$GapImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GapSummary _$GapSummaryFromJson(Map<String, dynamic> json) {
  return _GapSummary.fromJson(json);
}

/// @nodoc
mixin _$GapSummary {
  int get total => throw _privateConstructorUsedError;
  int get open => throw _privateConstructorUsedError;
  int get inProgress => throw _privateConstructorUsedError;
  int get resolved => throw _privateConstructorUsedError;
  int get critical => throw _privateConstructorUsedError;
  int get high => throw _privateConstructorUsedError;
  double get totalExposureNIS => throw _privateConstructorUsedError;
  double get resolvedExposureNIS => throw _privateConstructorUsedError;
  double get complianceScore => throw _privateConstructorUsedError;

  /// Serializes this GapSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GapSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GapSummaryCopyWith<GapSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GapSummaryCopyWith<$Res> {
  factory $GapSummaryCopyWith(
          GapSummary value, $Res Function(GapSummary) then) =
      _$GapSummaryCopyWithImpl<$Res, GapSummary>;
  @useResult
  $Res call(
      {int total,
      int open,
      int inProgress,
      int resolved,
      int critical,
      int high,
      double totalExposureNIS,
      double resolvedExposureNIS,
      double complianceScore});
}

/// @nodoc
class _$GapSummaryCopyWithImpl<$Res, $Val extends GapSummary>
    implements $GapSummaryCopyWith<$Res> {
  _$GapSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GapSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? total = null,
    Object? open = null,
    Object? inProgress = null,
    Object? resolved = null,
    Object? critical = null,
    Object? high = null,
    Object? totalExposureNIS = null,
    Object? resolvedExposureNIS = null,
    Object? complianceScore = null,
  }) {
    return _then(_value.copyWith(
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      open: null == open
          ? _value.open
          : open // ignore: cast_nullable_to_non_nullable
              as int,
      inProgress: null == inProgress
          ? _value.inProgress
          : inProgress // ignore: cast_nullable_to_non_nullable
              as int,
      resolved: null == resolved
          ? _value.resolved
          : resolved // ignore: cast_nullable_to_non_nullable
              as int,
      critical: null == critical
          ? _value.critical
          : critical // ignore: cast_nullable_to_non_nullable
              as int,
      high: null == high
          ? _value.high
          : high // ignore: cast_nullable_to_non_nullable
              as int,
      totalExposureNIS: null == totalExposureNIS
          ? _value.totalExposureNIS
          : totalExposureNIS // ignore: cast_nullable_to_non_nullable
              as double,
      resolvedExposureNIS: null == resolvedExposureNIS
          ? _value.resolvedExposureNIS
          : resolvedExposureNIS // ignore: cast_nullable_to_non_nullable
              as double,
      complianceScore: null == complianceScore
          ? _value.complianceScore
          : complianceScore // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GapSummaryImplCopyWith<$Res>
    implements $GapSummaryCopyWith<$Res> {
  factory _$$GapSummaryImplCopyWith(
          _$GapSummaryImpl value, $Res Function(_$GapSummaryImpl) then) =
      __$$GapSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int total,
      int open,
      int inProgress,
      int resolved,
      int critical,
      int high,
      double totalExposureNIS,
      double resolvedExposureNIS,
      double complianceScore});
}

/// @nodoc
class __$$GapSummaryImplCopyWithImpl<$Res>
    extends _$GapSummaryCopyWithImpl<$Res, _$GapSummaryImpl>
    implements _$$GapSummaryImplCopyWith<$Res> {
  __$$GapSummaryImplCopyWithImpl(
      _$GapSummaryImpl _value, $Res Function(_$GapSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of GapSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? total = null,
    Object? open = null,
    Object? inProgress = null,
    Object? resolved = null,
    Object? critical = null,
    Object? high = null,
    Object? totalExposureNIS = null,
    Object? resolvedExposureNIS = null,
    Object? complianceScore = null,
  }) {
    return _then(_$GapSummaryImpl(
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      open: null == open
          ? _value.open
          : open // ignore: cast_nullable_to_non_nullable
              as int,
      inProgress: null == inProgress
          ? _value.inProgress
          : inProgress // ignore: cast_nullable_to_non_nullable
              as int,
      resolved: null == resolved
          ? _value.resolved
          : resolved // ignore: cast_nullable_to_non_nullable
              as int,
      critical: null == critical
          ? _value.critical
          : critical // ignore: cast_nullable_to_non_nullable
              as int,
      high: null == high
          ? _value.high
          : high // ignore: cast_nullable_to_non_nullable
              as int,
      totalExposureNIS: null == totalExposureNIS
          ? _value.totalExposureNIS
          : totalExposureNIS // ignore: cast_nullable_to_non_nullable
              as double,
      resolvedExposureNIS: null == resolvedExposureNIS
          ? _value.resolvedExposureNIS
          : resolvedExposureNIS // ignore: cast_nullable_to_non_nullable
              as double,
      complianceScore: null == complianceScore
          ? _value.complianceScore
          : complianceScore // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GapSummaryImpl implements _GapSummary {
  const _$GapSummaryImpl(
      {required this.total,
      required this.open,
      required this.inProgress,
      required this.resolved,
      required this.critical,
      required this.high,
      required this.totalExposureNIS,
      required this.resolvedExposureNIS,
      required this.complianceScore});

  factory _$GapSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$GapSummaryImplFromJson(json);

  @override
  final int total;
  @override
  final int open;
  @override
  final int inProgress;
  @override
  final int resolved;
  @override
  final int critical;
  @override
  final int high;
  @override
  final double totalExposureNIS;
  @override
  final double resolvedExposureNIS;
  @override
  final double complianceScore;

  @override
  String toString() {
    return 'GapSummary(total: $total, open: $open, inProgress: $inProgress, resolved: $resolved, critical: $critical, high: $high, totalExposureNIS: $totalExposureNIS, resolvedExposureNIS: $resolvedExposureNIS, complianceScore: $complianceScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GapSummaryImpl &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.open, open) || other.open == open) &&
            (identical(other.inProgress, inProgress) ||
                other.inProgress == inProgress) &&
            (identical(other.resolved, resolved) ||
                other.resolved == resolved) &&
            (identical(other.critical, critical) ||
                other.critical == critical) &&
            (identical(other.high, high) || other.high == high) &&
            (identical(other.totalExposureNIS, totalExposureNIS) ||
                other.totalExposureNIS == totalExposureNIS) &&
            (identical(other.resolvedExposureNIS, resolvedExposureNIS) ||
                other.resolvedExposureNIS == resolvedExposureNIS) &&
            (identical(other.complianceScore, complianceScore) ||
                other.complianceScore == complianceScore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      total,
      open,
      inProgress,
      resolved,
      critical,
      high,
      totalExposureNIS,
      resolvedExposureNIS,
      complianceScore);

  /// Create a copy of GapSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GapSummaryImplCopyWith<_$GapSummaryImpl> get copyWith =>
      __$$GapSummaryImplCopyWithImpl<_$GapSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GapSummaryImplToJson(
      this,
    );
  }
}

abstract class _GapSummary implements GapSummary {
  const factory _GapSummary(
      {required final int total,
      required final int open,
      required final int inProgress,
      required final int resolved,
      required final int critical,
      required final int high,
      required final double totalExposureNIS,
      required final double resolvedExposureNIS,
      required final double complianceScore}) = _$GapSummaryImpl;

  factory _GapSummary.fromJson(Map<String, dynamic> json) =
      _$GapSummaryImpl.fromJson;

  @override
  int get total;
  @override
  int get open;
  @override
  int get inProgress;
  @override
  int get resolved;
  @override
  int get critical;
  @override
  int get high;
  @override
  double get totalExposureNIS;
  @override
  double get resolvedExposureNIS;
  @override
  double get complianceScore;

  /// Create a copy of GapSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GapSummaryImplCopyWith<_$GapSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
