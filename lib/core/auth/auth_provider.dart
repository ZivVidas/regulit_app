import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_client.dart';
import '../models/user.dart';

part 'auth_provider.g.dart';

// ── Auth State ───────────────────────────────────────────────
// Null = logged out. AppUser = logged in.
@riverpod
class AuthState extends _$AuthState {
  @override
  Future<AppUser?> build() async {
    // On first load, try to restore session from secure storage
    return _restoreSession();
  }

  Future<AppUser?> _restoreSession() async {
    final storage = ref.read(secureStorageProvider);

    // Skip network call only when there is truly nothing stored.
    // If only the refresh token is present the Dio interceptor will
    // exchange it for a new access token automatically on the 401.
    final hasAccess  = await storage.read(key: 'auth_token')     != null;
    final hasRefresh = await storage.read(key: 'refresh_token')  != null;
    if (!hasAccess && !hasRefresh) return null;

    try {
      final dio = ref.read(dioProvider);
      // Dio interceptor attaches auth_token (if any) and on 401 calls
      // /auth/refresh transparently, then retries the request.
      final response = await dio.get('/auth/me');
      return AppUser.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      // Both access and refresh tokens exhausted — force re-login.
      // Preserve last_email so the login form can pre-fill it.
      final lastEmail = await storage.read(key: 'last_email');
      await storage.deleteAll();
      if (lastEmail != null) {
        await storage.write(key: 'last_email', value: lastEmail);
      }
      return null;
    }
  }

  /// Login with email + password
  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final storage = ref.read(secureStorageProvider);

      final response = await dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;

      // Persist tokens + remember email for next launch
      await storage.write(key: 'auth_token',     value: data['access_token']  as String);
      await storage.write(key: 'refresh_token',  value: data['refresh_token'] as String);
      await storage.write(key: 'tenant_id',      value: data['tenant_id']     as String);
      await storage.write(key: 'last_email',     value: email);

      return AppUser.fromJson(data['user'] as Map<String, dynamic>);
    });
  }

  /// SSO / OAuth login (Microsoft Entra, Google)
  Future<void> loginWithSSO(String provider) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final storage = ref.read(secureStorageProvider);

      // Server returns a redirect URL; in Flutter Web we use url_launcher
      final response = await dio.get('/auth/sso/$provider/callback');
      final data = response.data as Map<String, dynamic>;

      await storage.write(key: 'auth_token', value: data['access_token'] as String);
      await storage.write(key: 'refresh_token', value: data['refresh_token'] as String);
      await storage.write(key: 'tenant_id', value: data['tenant_id'] as String);

      return AppUser.fromJson(data['user'] as Map<String, dynamic>);
    });
  }

  /// Demo login — no backend required. Used for MVP walkthroughs.
  /// Sets a pre-built AppUser for the requested role instantly.
  Future<void> loginAsMock(UserRole role) async {
    state = const AsyncLoading();
    await Future.delayed(const Duration(milliseconds: 350)); // fake network feel
    state = AsyncData(AppUser(
      id: 'demo-${role.name}',
      tenantId: 'demo-tenant-001',
      email: 'demo@regulit.io',
      name: _demoNameForRole(role),
      role: role,
    ));
  }

  /// Logout — clears tokens but keeps last_email so the login form pre-fills.
  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    final lastEmail = await storage.read(key: 'last_email');
    await storage.deleteAll();
    if (lastEmail != null) {
      await storage.write(key: 'last_email', value: lastEmail);
    }
    state = const AsyncData(null);
  }
}

String _demoNameForRole(UserRole role) => switch (role) {
  UserRole.regulitAdmin => 'Admin Demo',
  UserRole.csm          => 'Noa Cohen (CSM)',
  UserRole.analyst      => 'Yael Mizrahi (Analyst)',
  UserRole.clientAdmin  => 'David Levi (CEO)',
  UserRole.itExecutor   => 'Oren Ben-David (IT)',
  UserRole.employee     => 'Employee Demo',
};

// ── Current User convenience provider ───────────────────────
@riverpod
AppUser? currentUser(CurrentUserRef ref) {
  return ref.watch(authStateProvider).valueOrNull;
}

// ── Role-based computed providers ───────────────────────────
@riverpod
bool isReguLitStaff(IsReguLitStaffRef ref) {
  return ref.watch(currentUserProvider)?.role?.isReguLitStaff ?? false;
}

@riverpod
bool isClientAdmin(IsClientAdminRef ref) {
  return ref.watch(currentUserProvider)?.role == UserRole.clientAdmin;
}

@riverpod
bool isItExecutor(IsItExecutorRef ref) {
  return ref.watch(currentUserProvider)?.role == UserRole.itExecutor;
}
