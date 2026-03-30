import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Roles that exist in the system.
/// Used in router.dart for redirect logic and in UI for conditional rendering.
enum UserRole {
  @JsonValue('regulit_admin') regulitAdmin,
  @JsonValue('csm') csm,
  @JsonValue('regulit_analyst') analyst,
  @JsonValue('client_admin') clientAdmin,
  @JsonValue('it_executor') itExecutor,
  @JsonValue('employee') employee,
}

extension UserRoleX on UserRole {
  bool get isReguLitStaff => [
    UserRole.regulitAdmin,
    UserRole.csm,
    UserRole.analyst,
  ].contains(this);

  bool get isClientSide => !isReguLitStaff;

  String get displayName => switch (this) {
    UserRole.regulitAdmin => 'Regulit Admin',
    UserRole.csm          => 'Customer Success Manager',
    UserRole.analyst      => 'Compliance Analyst',
    UserRole.clientAdmin  => 'Client Admin',
    UserRole.itExecutor   => 'IT Manager',
    UserRole.employee     => 'Employee',
  };
}

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String tenantId,
    required String email,
    required String name,
    UserRole? role,
    String? avatarUrl,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
