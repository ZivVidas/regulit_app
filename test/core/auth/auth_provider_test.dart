import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:regulit_app/core/api/api_client.dart';
import 'package:regulit_app/core/auth/auth_provider.dart';
import 'package:regulit_app/core/models/user.dart';

class _MockDio extends Mock implements Dio {}
class _MockStorage extends Mock implements FlutterSecureStorage {}

// Subclass that skips _restoreSession so no network call happens during build.
class _TestAuthState extends AuthState {
  @override
  Future<AppUser?> build() async => null;
}

// Successful POST response that loginAndHold expects.
Response<dynamic> _successResponse() => Response(
      data: {
        'access_token': 'tok_access',
        'refresh_token': 'tok_refresh',
        'tenant_id': 'ten_001',
        'user': {
          'id': 'u1',
          'tenantId': 'ten_001',
          'email': 'alice@test.com',
          'name': 'Alice',
          'role': 'employee',
        },
      },
      statusCode: 200,
      requestOptions: RequestOptions(path: '/auth/login'),
    );

void main() {
  late _MockDio mockDio;
  late _MockStorage mockStorage;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = _MockDio();
    mockStorage = _MockStorage();

    when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    when(() => mockStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);

    container = ProviderContainer(overrides: [
      secureStorageProvider.overrideWith((ref) => mockStorage),
      dioProvider.overrideWith((ref) => mockDio),
      authStateProvider.overrideWith(_TestAuthState.new),
    ]);
    // Prevent auto-dispose while the test runs.
    container.listen(authStateProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  group('loginAndHold — success', () {
    setUp(() {
      when(() => mockDio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _successResponse());
    });

    test('leaves state as AsyncLoading after API call completes', () async {
      await container.read(authStateProvider.future); // wait for build()
      final notifier = container.read(authStateProvider.notifier);

      await notifier.loginAndHold(email: 'alice@test.com', password: 'pass1234');

      expect(container.read(authStateProvider), isA<AsyncLoading<AppUser?>>());
    });

    test('completeLogin sets AsyncData with the pending user', () async {
      await container.read(authStateProvider.future);
      final notifier = container.read(authStateProvider.notifier);

      await notifier.loginAndHold(email: 'alice@test.com', password: 'pass1234');
      notifier.completeLogin();

      final state = container.read(authStateProvider);
      expect(state, isA<AsyncData<AppUser?>>());
      expect(state.value?.email, 'alice@test.com');
    });

    test('completeLogin is idempotent — second call is a no-op', () async {
      await container.read(authStateProvider.future);
      final notifier = container.read(authStateProvider.notifier);

      await notifier.loginAndHold(email: 'alice@test.com', password: 'pass1234');
      notifier.completeLogin();
      notifier.completeLogin(); // must not crash or change state back to null

      expect(container.read(authStateProvider).value?.email, 'alice@test.com');
    });
  });

  group('loginAndHold — error', () {
    setUp(() {
      when(() => mockDio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => throw DioException(
                requestOptions: RequestOptions(path: '/auth/login'),
                response: Response(
                  statusCode: 401,
                  requestOptions: RequestOptions(path: '/auth/login'),
                ),
                type: DioExceptionType.badResponse,
              ));
    });

    test('resets state to AsyncData(null) and throws', () async {
      await container.read(authStateProvider.future);
      final notifier = container.read(authStateProvider.notifier);

      await expectLater(
        notifier.loginAndHold(email: 'alice@test.com', password: 'wrong'),
        throwsA(isA<DioException>()),
      );

      final state = container.read(authStateProvider);
      expect(state, isA<AsyncData<AppUser?>>());
      expect(state.value, isNull);
    });
  });
}
