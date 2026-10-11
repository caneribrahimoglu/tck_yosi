import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/auth_failure.dart';
import 'package:tck_yosi/features/auth/domain/models/auth_service_exception.dart';

Map<String, Object?> apiUser({
  bool mustChange = false,
  bool active = true,
  List<String> permissions = const ['viewVehicleFleet'],
}) => {
  'id': 'real-chief-uuid',
  'full_name': 'Gerçek Test Şef',
  'username': 'sef',
  'role': 'chief',
  'is_active': active,
  'must_change_password': mustChange,
  'permissions': permissions,
};
http.Response loginResponse({
  bool mustChange = false,
  int seconds = 1800,
  List<String> permissions = const ['viewVehicleFleet'],
}) => http.Response(
  jsonEncode({
    'access_token': 'test-token',
    'token_type': 'bearer',
    'expires_in': seconds,
    'user': apiUser(mustChange: mustChange, permissions: permissions),
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  final base = Uri.parse('http://localhost:8000/api/v1/');
  test(
    'API login maps real identity, explicit grants and stores no password',
    () async {
      final store = MemorySessionStore();
      final service = ApiAuthService(
        baseUrl: base,
        sessionStore: store,
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/login');
          expect(jsonDecode(request.body)['username'], 'sef');
          expect(jsonDecode(request.body)['password'], ' Secret-password ');
          return loginResponse(mustChange: true);
        }),
      );
      final result = await service.login(
        username: ' sef ',
        password: ' Secret-password ',
      );
      expect(result.user!.id, 'real-chief-uuid');
      expect(result.user!.mustChangePassword, isTrue);
      expect(result.user!.permissions, {AppPermission.viewVehicleFleet});
      expect(() => result.user!.permissions.clear(), throwsUnsupportedError);
      final stored = (await store.read())!;
      expect(stored, isNot(contains('password')));
      expect(stored, isNot(contains('permissions')));
      service.dispose();
    },
  );

  test(
    'restored session checks /me; chief role never manufactures permissions',
    () async {
      final store = MemorySessionStore();
      final first = ApiAuthService(
        baseUrl: base,
        sessionStore: store,
        client: MockClient((_) async => loginResponse()),
      );
      await first.login(username: 'sef', password: 'x');
      first.dispose();
      final restored = ApiAuthService(
        baseUrl: base,
        sessionStore: store,
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/me');
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response(
            jsonEncode(apiUser(permissions: [])),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      expect((await restored.getCurrentUser())!.permissions, isEmpty);
      await restored.logout();
      expect(await store.read(), isNull);
      expect(await restored.getCurrentUser(), isNull);
      restored.dispose();
    },
  );

  test('expired stored session is removed without a request', () async {
    final store = MemorySessionStore();
    await store.write(
      jsonEncode({
        'token': 'expired',
        'expires_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      }),
    );
    final service = ApiAuthService(
      baseUrl: base,
      sessionStore: store,
      client: MockClient((_) async => throw StateError('Must not request')),
    );
    expect(await service.getCurrentUser(), isNull);
    expect(await store.read(), isNull);
    service.dispose();
  });

  for (final code in [401, 403]) {
    test('me $code clears token and notifies session owner', () async {
      final store = MemorySessionStore();
      var notified = false;
      final service = ApiAuthService(
        baseUrl: base,
        sessionStore: store,
        client: MockClient(
          (r) async => r.url.path.endsWith('/login')
              ? loginResponse()
              : http.Response('{}', code),
        ),
      );
      service.onSessionInvalidated = () => notified = true;
      await service.login(username: 'sef', password: 'x');
      expect(await service.getCurrentUser(), isNull);
      expect(notified, isTrue);
      expect(await store.read(), isNull);
      service.dispose();
    });
  }

  test('network error is typed, persisted token retained for retry', () async {
    final store = MemorySessionStore();
    final service = ApiAuthService(
      baseUrl: base,
      sessionStore: store,
      client: MockClient(
        (r) async => r.url.path.endsWith('/login')
            ? loginResponse()
            : throw http.ClientException('private transport data'),
      ),
    );
    await service.login(username: 'sef', password: 'x');
    await expectLater(
      service.getCurrentUser(),
      throwsA(
        isA<AuthServiceException>().having(
          (e) => e.failure,
          'failure',
          AuthFailure.networkError,
        ),
      ),
    );
    expect(await store.read(), isNotNull);
    service.dispose();
  });

  test(
    'invalid credentials and malformed responses are generic safe failures',
    () async {
      for (final response in [
        http.Response('{}', 401),
        http.Response('private traceback', 500),
        http.Response('{}', 200),
      ]) {
        final store = MemorySessionStore();
        final service = ApiAuthService(
          baseUrl: base,
          sessionStore: store,
          client: MockClient((_) async => response),
        );
        final result = await service.login(username: 'sef', password: 'x');
        expect(result.isSuccess, isFalse);
        expect(
          result.failure,
          response.statusCode == 401
              ? AuthFailure.invalidCredentials
              : AuthFailure.unknown,
        );
        expect(await store.read(), isNull);
        service.dispose();
      }
    },
  );

  test(
    'password change refreshes user from /me without storing passwords',
    () async {
      final service = ApiAuthService(
        baseUrl: base,
        sessionStore: MemorySessionStore(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return loginResponse(mustChange: true);
          }
          if (r.url.path.endsWith('/change-password')) {
            expect(jsonDecode(r.body)['new_password'], 'new-password-123');
            expect(r.headers['Authorization'], 'Bearer test-token');
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode(apiUser()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await service.login(username: 'sef', password: 'old');
      final result = await service.changePassword(
        currentPassword: 'old',
        newPassword: 'new-password-123',
      );
      expect(result.user!.mustChangePassword, isFalse);
      service.dispose();
    },
  );

  test(
    'password rejection is typed without exposing response detail',
    () async {
      final service = ApiAuthService(
        baseUrl: base,
        sessionStore: MemorySessionStore(),
        client: MockClient(
          (r) async => r.url.path.endsWith('/login')
              ? loginResponse(mustChange: true)
              : http.Response('sensitive', 400),
        ),
      );
      await service.login(username: 'sef', password: 'old');
      expect(
        (await service.changePassword(
          currentPassword: 'wrong',
          newPassword: 'short',
        )).failure,
        AuthFailure.invalidPassword,
      );
      service.dispose();
    },
  );

  test('logout while login is in flight cannot resurrect session', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    final store = MemorySessionStore();
    final service = ApiAuthService(
      baseUrl: base,
      sessionStore: store,
      client: MockClient((r) {
        requested.complete();
        return response.future;
      }),
    );
    final pending = service.login(username: 'sef', password: 'x');
    await requested.future;
    await service.logout();
    response.complete(loginResponse());
    expect((await pending).isSuccess, isFalse);
    expect(await store.read(), isNull);
    expect(await service.getCurrentUser(), isNull);
    service.dispose();
  });

  test('timeout maps to network error', () async {
    final service = ApiAuthService(
      baseUrl: base,
      sessionStore: MemorySessionStore(),
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return loginResponse();
      }),
    );
    expect(
      (await service.login(username: 'sef', password: 'x')).failure,
      AuthFailure.networkError,
    );
    service.dispose();
  });
}
