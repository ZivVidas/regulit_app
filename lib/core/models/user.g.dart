// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: $enumDecodeNullable(_$UserRoleEnumMap, json['role']),
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'email': instance.email,
      'name': instance.name,
      'role': _$UserRoleEnumMap[instance.role],
      'avatarUrl': instance.avatarUrl,
    };

const _$UserRoleEnumMap = {
  UserRole.regulitAdmin: 'regulit_admin',
  UserRole.csm: 'csm',
  UserRole.analyst: 'regulit_analyst',
  UserRole.clientAdmin: 'client_admin',
  UserRole.itExecutor: 'it_executor',
  UserRole.employee: 'employee',
};
