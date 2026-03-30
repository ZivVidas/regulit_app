// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Task _$TaskFromJson(Map<String, dynamic> json) {
  return _Task.fromJson(json);
}

/// @nodoc
mixin _$Task {
  String get id => throw _privateConstructorUsedError;
  String get tenantId => throw _privateConstructorUsedError;
  String get gapId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  TaskStatus get status => throw _privateConstructorUsedError;
  TaskPriority get priority => throw _privateConstructorUsedError; // RACI
  String? get responsibleId =>
      throw _privateConstructorUsedError; // R — does the work
  String? get responsibleName => throw _privateConstructorUsedError;
  String? get accountableId =>
      throw _privateConstructorUsedError; // A — signs off
  String? get accountableName => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get dueDate => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  double? get estimatedCostNIS =>
      throw _privateConstructorUsedError; // Denormalised from gap
  String get gapCode => throw _privateConstructorUsedError;
  String get gapTitle => throw _privateConstructorUsedError;

  /// Serializes this Task to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskCopyWith<Task> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskCopyWith<$Res> {
  factory $TaskCopyWith(Task value, $Res Function(Task) then) =
      _$TaskCopyWithImpl<$Res, Task>;
  @useResult
  $Res call(
      {String id,
      String tenantId,
      String gapId,
      String title,
      String description,
      TaskStatus status,
      TaskPriority priority,
      String? responsibleId,
      String? responsibleName,
      String? accountableId,
      String? accountableName,
      DateTime createdAt,
      DateTime? dueDate,
      DateTime? completedAt,
      double? estimatedCostNIS,
      String gapCode,
      String gapTitle});
}

/// @nodoc
class _$TaskCopyWithImpl<$Res, $Val extends Task>
    implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? gapId = null,
    Object? title = null,
    Object? description = null,
    Object? status = null,
    Object? priority = null,
    Object? responsibleId = freezed,
    Object? responsibleName = freezed,
    Object? accountableId = freezed,
    Object? accountableName = freezed,
    Object? createdAt = null,
    Object? dueDate = freezed,
    Object? completedAt = freezed,
    Object? estimatedCostNIS = freezed,
    Object? gapCode = null,
    Object? gapTitle = null,
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
      gapId: null == gapId
          ? _value.gapId
          : gapId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as TaskPriority,
      responsibleId: freezed == responsibleId
          ? _value.responsibleId
          : responsibleId // ignore: cast_nullable_to_non_nullable
              as String?,
      responsibleName: freezed == responsibleName
          ? _value.responsibleName
          : responsibleName // ignore: cast_nullable_to_non_nullable
              as String?,
      accountableId: freezed == accountableId
          ? _value.accountableId
          : accountableId // ignore: cast_nullable_to_non_nullable
              as String?,
      accountableName: freezed == accountableName
          ? _value.accountableName
          : accountableName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dueDate: freezed == dueDate
          ? _value.dueDate
          : dueDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimatedCostNIS: freezed == estimatedCostNIS
          ? _value.estimatedCostNIS
          : estimatedCostNIS // ignore: cast_nullable_to_non_nullable
              as double?,
      gapCode: null == gapCode
          ? _value.gapCode
          : gapCode // ignore: cast_nullable_to_non_nullable
              as String,
      gapTitle: null == gapTitle
          ? _value.gapTitle
          : gapTitle // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskImplCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$$TaskImplCopyWith(
          _$TaskImpl value, $Res Function(_$TaskImpl) then) =
      __$$TaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String tenantId,
      String gapId,
      String title,
      String description,
      TaskStatus status,
      TaskPriority priority,
      String? responsibleId,
      String? responsibleName,
      String? accountableId,
      String? accountableName,
      DateTime createdAt,
      DateTime? dueDate,
      DateTime? completedAt,
      double? estimatedCostNIS,
      String gapCode,
      String gapTitle});
}

/// @nodoc
class __$$TaskImplCopyWithImpl<$Res>
    extends _$TaskCopyWithImpl<$Res, _$TaskImpl>
    implements _$$TaskImplCopyWith<$Res> {
  __$$TaskImplCopyWithImpl(_$TaskImpl _value, $Res Function(_$TaskImpl) _then)
      : super(_value, _then);

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? gapId = null,
    Object? title = null,
    Object? description = null,
    Object? status = null,
    Object? priority = null,
    Object? responsibleId = freezed,
    Object? responsibleName = freezed,
    Object? accountableId = freezed,
    Object? accountableName = freezed,
    Object? createdAt = null,
    Object? dueDate = freezed,
    Object? completedAt = freezed,
    Object? estimatedCostNIS = freezed,
    Object? gapCode = null,
    Object? gapTitle = null,
  }) {
    return _then(_$TaskImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      gapId: null == gapId
          ? _value.gapId
          : gapId // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as TaskPriority,
      responsibleId: freezed == responsibleId
          ? _value.responsibleId
          : responsibleId // ignore: cast_nullable_to_non_nullable
              as String?,
      responsibleName: freezed == responsibleName
          ? _value.responsibleName
          : responsibleName // ignore: cast_nullable_to_non_nullable
              as String?,
      accountableId: freezed == accountableId
          ? _value.accountableId
          : accountableId // ignore: cast_nullable_to_non_nullable
              as String?,
      accountableName: freezed == accountableName
          ? _value.accountableName
          : accountableName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dueDate: freezed == dueDate
          ? _value.dueDate
          : dueDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimatedCostNIS: freezed == estimatedCostNIS
          ? _value.estimatedCostNIS
          : estimatedCostNIS // ignore: cast_nullable_to_non_nullable
              as double?,
      gapCode: null == gapCode
          ? _value.gapCode
          : gapCode // ignore: cast_nullable_to_non_nullable
              as String,
      gapTitle: null == gapTitle
          ? _value.gapTitle
          : gapTitle // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskImpl implements _Task {
  const _$TaskImpl(
      {required this.id,
      required this.tenantId,
      required this.gapId,
      required this.title,
      required this.description,
      required this.status,
      required this.priority,
      this.responsibleId,
      this.responsibleName,
      this.accountableId,
      this.accountableName,
      required this.createdAt,
      this.dueDate,
      this.completedAt,
      this.estimatedCostNIS,
      required this.gapCode,
      required this.gapTitle});

  factory _$TaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskImplFromJson(json);

  @override
  final String id;
  @override
  final String tenantId;
  @override
  final String gapId;
  @override
  final String title;
  @override
  final String description;
  @override
  final TaskStatus status;
  @override
  final TaskPriority priority;
// RACI
  @override
  final String? responsibleId;
// R — does the work
  @override
  final String? responsibleName;
  @override
  final String? accountableId;
// A — signs off
  @override
  final String? accountableName;
  @override
  final DateTime createdAt;
  @override
  final DateTime? dueDate;
  @override
  final DateTime? completedAt;
  @override
  final double? estimatedCostNIS;
// Denormalised from gap
  @override
  final String gapCode;
  @override
  final String gapTitle;

  @override
  String toString() {
    return 'Task(id: $id, tenantId: $tenantId, gapId: $gapId, title: $title, description: $description, status: $status, priority: $priority, responsibleId: $responsibleId, responsibleName: $responsibleName, accountableId: $accountableId, accountableName: $accountableName, createdAt: $createdAt, dueDate: $dueDate, completedAt: $completedAt, estimatedCostNIS: $estimatedCostNIS, gapCode: $gapCode, gapTitle: $gapTitle)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.gapId, gapId) || other.gapId == gapId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.responsibleId, responsibleId) ||
                other.responsibleId == responsibleId) &&
            (identical(other.responsibleName, responsibleName) ||
                other.responsibleName == responsibleName) &&
            (identical(other.accountableId, accountableId) ||
                other.accountableId == accountableId) &&
            (identical(other.accountableName, accountableName) ||
                other.accountableName == accountableName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.estimatedCostNIS, estimatedCostNIS) ||
                other.estimatedCostNIS == estimatedCostNIS) &&
            (identical(other.gapCode, gapCode) || other.gapCode == gapCode) &&
            (identical(other.gapTitle, gapTitle) ||
                other.gapTitle == gapTitle));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      gapId,
      title,
      description,
      status,
      priority,
      responsibleId,
      responsibleName,
      accountableId,
      accountableName,
      createdAt,
      dueDate,
      completedAt,
      estimatedCostNIS,
      gapCode,
      gapTitle);

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      __$$TaskImplCopyWithImpl<_$TaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskImplToJson(
      this,
    );
  }
}

abstract class _Task implements Task {
  const factory _Task(
      {required final String id,
      required final String tenantId,
      required final String gapId,
      required final String title,
      required final String description,
      required final TaskStatus status,
      required final TaskPriority priority,
      final String? responsibleId,
      final String? responsibleName,
      final String? accountableId,
      final String? accountableName,
      required final DateTime createdAt,
      final DateTime? dueDate,
      final DateTime? completedAt,
      final double? estimatedCostNIS,
      required final String gapCode,
      required final String gapTitle}) = _$TaskImpl;

  factory _Task.fromJson(Map<String, dynamic> json) = _$TaskImpl.fromJson;

  @override
  String get id;
  @override
  String get tenantId;
  @override
  String get gapId;
  @override
  String get title;
  @override
  String get description;
  @override
  TaskStatus get status;
  @override
  TaskPriority get priority; // RACI
  @override
  String? get responsibleId; // R — does the work
  @override
  String? get responsibleName;
  @override
  String? get accountableId; // A — signs off
  @override
  String? get accountableName;
  @override
  DateTime get createdAt;
  @override
  DateTime? get dueDate;
  @override
  DateTime? get completedAt;
  @override
  double? get estimatedCostNIS; // Denormalised from gap
  @override
  String get gapCode;
  @override
  String get gapTitle;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskImplCopyWith<_$TaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Evidence _$EvidenceFromJson(Map<String, dynamic> json) {
  return _Evidence.fromJson(json);
}

/// @nodoc
mixin _$Evidence {
  String get id => throw _privateConstructorUsedError;
  String get taskId => throw _privateConstructorUsedError;
  String get uploaderId => throw _privateConstructorUsedError;
  String get uploaderName => throw _privateConstructorUsedError;
  String get fileUrl => throw _privateConstructorUsedError;
  String get fileName => throw _privateConstructorUsedError;
  String get fileType => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // pending | approved | rejected
  String? get reviewNote => throw _privateConstructorUsedError;
  String? get reviewedById => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;

  /// Serializes this Evidence to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Evidence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EvidenceCopyWith<Evidence> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EvidenceCopyWith<$Res> {
  factory $EvidenceCopyWith(Evidence value, $Res Function(Evidence) then) =
      _$EvidenceCopyWithImpl<$Res, Evidence>;
  @useResult
  $Res call(
      {String id,
      String taskId,
      String uploaderId,
      String uploaderName,
      String fileUrl,
      String fileName,
      String fileType,
      String? notes,
      String status,
      String? reviewNote,
      String? reviewedById,
      DateTime uploadedAt});
}

/// @nodoc
class _$EvidenceCopyWithImpl<$Res, $Val extends Evidence>
    implements $EvidenceCopyWith<$Res> {
  _$EvidenceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Evidence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? taskId = null,
    Object? uploaderId = null,
    Object? uploaderName = null,
    Object? fileUrl = null,
    Object? fileName = null,
    Object? fileType = null,
    Object? notes = freezed,
    Object? status = null,
    Object? reviewNote = freezed,
    Object? reviewedById = freezed,
    Object? uploadedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      uploaderId: null == uploaderId
          ? _value.uploaderId
          : uploaderId // ignore: cast_nullable_to_non_nullable
              as String,
      uploaderName: null == uploaderName
          ? _value.uploaderName
          : uploaderName // ignore: cast_nullable_to_non_nullable
              as String,
      fileUrl: null == fileUrl
          ? _value.fileUrl
          : fileUrl // ignore: cast_nullable_to_non_nullable
              as String,
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      fileType: null == fileType
          ? _value.fileType
          : fileType // ignore: cast_nullable_to_non_nullable
              as String,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      reviewNote: freezed == reviewNote
          ? _value.reviewNote
          : reviewNote // ignore: cast_nullable_to_non_nullable
              as String?,
      reviewedById: freezed == reviewedById
          ? _value.reviewedById
          : reviewedById // ignore: cast_nullable_to_non_nullable
              as String?,
      uploadedAt: null == uploadedAt
          ? _value.uploadedAt
          : uploadedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EvidenceImplCopyWith<$Res>
    implements $EvidenceCopyWith<$Res> {
  factory _$$EvidenceImplCopyWith(
          _$EvidenceImpl value, $Res Function(_$EvidenceImpl) then) =
      __$$EvidenceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String taskId,
      String uploaderId,
      String uploaderName,
      String fileUrl,
      String fileName,
      String fileType,
      String? notes,
      String status,
      String? reviewNote,
      String? reviewedById,
      DateTime uploadedAt});
}

/// @nodoc
class __$$EvidenceImplCopyWithImpl<$Res>
    extends _$EvidenceCopyWithImpl<$Res, _$EvidenceImpl>
    implements _$$EvidenceImplCopyWith<$Res> {
  __$$EvidenceImplCopyWithImpl(
      _$EvidenceImpl _value, $Res Function(_$EvidenceImpl) _then)
      : super(_value, _then);

  /// Create a copy of Evidence
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? taskId = null,
    Object? uploaderId = null,
    Object? uploaderName = null,
    Object? fileUrl = null,
    Object? fileName = null,
    Object? fileType = null,
    Object? notes = freezed,
    Object? status = null,
    Object? reviewNote = freezed,
    Object? reviewedById = freezed,
    Object? uploadedAt = null,
  }) {
    return _then(_$EvidenceImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      uploaderId: null == uploaderId
          ? _value.uploaderId
          : uploaderId // ignore: cast_nullable_to_non_nullable
              as String,
      uploaderName: null == uploaderName
          ? _value.uploaderName
          : uploaderName // ignore: cast_nullable_to_non_nullable
              as String,
      fileUrl: null == fileUrl
          ? _value.fileUrl
          : fileUrl // ignore: cast_nullable_to_non_nullable
              as String,
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      fileType: null == fileType
          ? _value.fileType
          : fileType // ignore: cast_nullable_to_non_nullable
              as String,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      reviewNote: freezed == reviewNote
          ? _value.reviewNote
          : reviewNote // ignore: cast_nullable_to_non_nullable
              as String?,
      reviewedById: freezed == reviewedById
          ? _value.reviewedById
          : reviewedById // ignore: cast_nullable_to_non_nullable
              as String?,
      uploadedAt: null == uploadedAt
          ? _value.uploadedAt
          : uploadedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EvidenceImpl implements _Evidence {
  const _$EvidenceImpl(
      {required this.id,
      required this.taskId,
      required this.uploaderId,
      required this.uploaderName,
      required this.fileUrl,
      required this.fileName,
      required this.fileType,
      this.notes,
      required this.status,
      this.reviewNote,
      this.reviewedById,
      required this.uploadedAt});

  factory _$EvidenceImpl.fromJson(Map<String, dynamic> json) =>
      _$$EvidenceImplFromJson(json);

  @override
  final String id;
  @override
  final String taskId;
  @override
  final String uploaderId;
  @override
  final String uploaderName;
  @override
  final String fileUrl;
  @override
  final String fileName;
  @override
  final String fileType;
  @override
  final String? notes;
  @override
  final String status;
// pending | approved | rejected
  @override
  final String? reviewNote;
  @override
  final String? reviewedById;
  @override
  final DateTime uploadedAt;

  @override
  String toString() {
    return 'Evidence(id: $id, taskId: $taskId, uploaderId: $uploaderId, uploaderName: $uploaderName, fileUrl: $fileUrl, fileName: $fileName, fileType: $fileType, notes: $notes, status: $status, reviewNote: $reviewNote, reviewedById: $reviewedById, uploadedAt: $uploadedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EvidenceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.uploaderId, uploaderId) ||
                other.uploaderId == uploaderId) &&
            (identical(other.uploaderName, uploaderName) ||
                other.uploaderName == uploaderName) &&
            (identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.fileType, fileType) ||
                other.fileType == fileType) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reviewNote, reviewNote) ||
                other.reviewNote == reviewNote) &&
            (identical(other.reviewedById, reviewedById) ||
                other.reviewedById == reviewedById) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      taskId,
      uploaderId,
      uploaderName,
      fileUrl,
      fileName,
      fileType,
      notes,
      status,
      reviewNote,
      reviewedById,
      uploadedAt);

  /// Create a copy of Evidence
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EvidenceImplCopyWith<_$EvidenceImpl> get copyWith =>
      __$$EvidenceImplCopyWithImpl<_$EvidenceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EvidenceImplToJson(
      this,
    );
  }
}

abstract class _Evidence implements Evidence {
  const factory _Evidence(
      {required final String id,
      required final String taskId,
      required final String uploaderId,
      required final String uploaderName,
      required final String fileUrl,
      required final String fileName,
      required final String fileType,
      final String? notes,
      required final String status,
      final String? reviewNote,
      final String? reviewedById,
      required final DateTime uploadedAt}) = _$EvidenceImpl;

  factory _Evidence.fromJson(Map<String, dynamic> json) =
      _$EvidenceImpl.fromJson;

  @override
  String get id;
  @override
  String get taskId;
  @override
  String get uploaderId;
  @override
  String get uploaderName;
  @override
  String get fileUrl;
  @override
  String get fileName;
  @override
  String get fileType;
  @override
  String? get notes;
  @override
  String get status; // pending | approved | rejected
  @override
  String? get reviewNote;
  @override
  String? get reviewedById;
  @override
  DateTime get uploadedAt;

  /// Create a copy of Evidence
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EvidenceImplCopyWith<_$EvidenceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
