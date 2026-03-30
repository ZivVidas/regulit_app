// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentUserHash() => r'2cbb899b5ce8f7a26eb391e91b841465b79f84f3';

/// See also [currentUser].
@ProviderFor(currentUser)
final currentUserProvider = AutoDisposeProvider<AppUser?>.internal(
  currentUser,
  name: r'currentUserProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserRef = AutoDisposeProviderRef<AppUser?>;
String _$isReguLitStaffHash() => r'570ed51c01f55e5f78ede6f741e221c2e001291a';

/// See also [isReguLitStaff].
@ProviderFor(isReguLitStaff)
final isReguLitStaffProvider = AutoDisposeProvider<bool>.internal(
  isReguLitStaff,
  name: r'isReguLitStaffProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isReguLitStaffHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsReguLitStaffRef = AutoDisposeProviderRef<bool>;
String _$isClientAdminHash() => r'9c00ea1c5054d7723ed74edf1b19713fb19fb9ff';

/// See also [isClientAdmin].
@ProviderFor(isClientAdmin)
final isClientAdminProvider = AutoDisposeProvider<bool>.internal(
  isClientAdmin,
  name: r'isClientAdminProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isClientAdminHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsClientAdminRef = AutoDisposeProviderRef<bool>;
String _$isItExecutorHash() => r'c57ab4cd3616e8d74330c241a6497cc320325cf5';

/// See also [isItExecutor].
@ProviderFor(isItExecutor)
final isItExecutorProvider = AutoDisposeProvider<bool>.internal(
  isItExecutor,
  name: r'isItExecutorProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isItExecutorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsItExecutorRef = AutoDisposeProviderRef<bool>;
String _$authStateHash() => r'feb797dd8624f593a57d6785f49e4f3019bd487a';

/// See also [AuthState].
@ProviderFor(AuthState)
final authStateProvider =
    AutoDisposeAsyncNotifierProvider<AuthState, AppUser?>.internal(
  AuthState.new,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthState = AutoDisposeAsyncNotifier<AppUser?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
