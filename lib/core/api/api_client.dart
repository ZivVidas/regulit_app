import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_client.g.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://regulit-api.onrender.com',
);
//https://regulit-api.onrender.com
const _tokenKey = 'auth_token';
const _refreshTokenKey = 'refresh_token';
//dpg-d74esf450q8c73dv55ag-a.frankfurt-postgres.render.com
// ── Secure Storage Provider ─────────────────────────────────
@riverpod
FlutterSecureStorage secureStorage(SecureStorageRef ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}

// ── Dio Instance Provider ────────────────────────────────────
@riverpod
Dio dio(DioRef ref) {
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // ── JWT Interceptor ────────────────────────────────────────
  // Automatically attaches Bearer token to every request.
  // Handles 401 by attempting token refresh, then retrying.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },

      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try refresh
          final refreshed = await _tryRefresh(dio, storage);
          if (refreshed) {
            // Retry original request with new token
            final token = await storage.read(key: _tokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final clonedRequest = await dio.fetch(error.requestOptions);
            return handler.resolve(clonedRequest);
          }
          // Refresh failed → clear tokens (router will redirect to login)
          await storage.deleteAll();
        }
        handler.next(error);
      },
    ),
  );

  // ── Tenant Context Interceptor ─────────────────────────────
  // Adds X-Tenant-ID header so the server sets RLS context.
  // The tenant_id is embedded in the JWT but we also send it as a
  // header for easier server-side debugging.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final tenantId = await storage.read(key: 'tenant_id');
        if (tenantId != null) {
          options.headers['X-Tenant-ID'] = tenantId;
        }
        handler.next(options);
      },
    ),
  );

  // ── Logger (dev only) ──────────────────────────────────────
  assert(() {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        error: true,
        compact: true,
      ),
    );
    return true;
  }());

  return dio;
}

Future<bool> _tryRefresh(Dio dio, FlutterSecureStorage storage) async {
  try {
    final refresh = await storage.read(key: _refreshTokenKey);
    if (refresh == null) return false;

    final response = await dio.post(
      '/auth/refresh',
      data: {'refresh_token': refresh},
      options: Options(headers: {'Authorization': null}), // no token on refresh
    );

    final newToken = response.data['access_token'] as String?;
    final newRefresh = response.data['refresh_token'] as String?;

    if (newToken == null) return false;

    await storage.write(key: _tokenKey, value: newToken);
    if (newRefresh != null) {
      await storage.write(key: _refreshTokenKey, value: newRefresh);
    }
    return true;
  } catch (_) {
    return false;
  }
}

// ── API Exception ───────────────────────────────────────────
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  const ApiException({
    this.statusCode,
    required this.message,
    this.errors,
  });

  factory ApiException.fromDioError(DioException e) {
    final data = e.response?.data;
    return ApiException(
      statusCode: e.response?.statusCode,
      message: (data is Map ? data['detail'] as String? : null) ??
          e.message ??
          'Unknown error',
      errors: data is Map ? data['errors'] as Map<String, dynamic>? : null,
    );
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
