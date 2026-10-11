import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import 'package:tck_yosi/features/auth/domain/enums/auth_failure.dart';
import 'package:tck_yosi/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tck_yosi/features/auth/presentation/controllers/auth_status.dart';
import '../../data/services/api_auth_service_test.dart'
    show apiUser, loginResponse;

void main() {
  test(
    'required password blocks dashboard, submit guard and success transitions',
    () async {
      var changes = 0;
      final response = Completer<http.Response>();
      final service = ApiAuthService(
        baseUrl: Uri.parse('http://localhost/api/v1/'),
        sessionStore: MemorySessionStore(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return loginResponse(mustChange: true);
          }
          if (r.url.path.endsWith('/change-password')) {
            changes++;
            return response.future;
          }
          return http.Response(
            jsonEncode(apiUser()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final controller = AuthController(authService: service);
      await controller.login(username: 'sef', password: 'x');
      expect(controller.status, AuthStatus.passwordChangeRequired);
      expect(controller.isAuthenticated, isFalse);
      final pending = controller.changePassword(
        currentPassword: 'x',
        newPassword: 'new-password-123',
      );
      expect(controller.isChangingPassword, isTrue);
      expect(
        await controller.changePassword(
          currentPassword: 'x',
          newPassword: 'new-password-123',
        ),
        isFalse,
      );
      response.complete(http.Response('{}', 200));
      expect(await pending, isTrue);
      expect(changes, 1);
      expect(controller.isAuthenticated, isTrue);
      controller.dispose();
      service.dispose();
    },
  );

  test('network failure during initialize is safe and returns login', () async {
    final store = MemorySessionStore();
    final service = ApiAuthService(
      baseUrl: Uri.parse('http://localhost/api/v1/'),
      sessionStore: store,
      client: MockClient(
        (r) async => r.url.path.endsWith('/login')
            ? loginResponse()
            : throw http.ClientException('private'),
      ),
    );
    await service.login(username: 'sef', password: 'x');
    final controller = AuthController(authService: service);
    await controller.initialize();
    expect(controller.status, AuthStatus.unauthenticated);
    expect(controller.failure, AuthFailure.networkError);
    controller.dispose();
    service.dispose();
  });

  test(
    'expiry clears authenticated state without waiting for user action',
    () async {
      final service = ApiAuthService(
        baseUrl: Uri.parse('http://localhost/api/v1/'),
        now: () => DateTime.now().subtract(const Duration(milliseconds: 950)),
        sessionStore: MemorySessionStore(),
        client: MockClient((_) async => loginResponse(seconds: 1)),
      );
      final controller = AuthController(authService: service);
      await controller.login(username: 'sef', password: 'x');
      expect(controller.isAuthenticated, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.currentUser, isNull);
      expect(controller.failure, AuthFailure.sessionExpired);
      controller.dispose();
      service.dispose();
    },
  );

  test('controller logout cancels a stale login response', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    final service = ApiAuthService(
      baseUrl: Uri.parse('http://localhost/api/v1/'),
      sessionStore: MemorySessionStore(),
      client: MockClient((_) {
        requested.complete();
        return response.future;
      }),
    );
    final controller = AuthController(authService: service);
    final login = controller.login(username: 'sef', password: 'x');
    expect(await controller.login(username: 'sef', password: 'x'), isFalse);
    await requested.future;
    await controller.logout();
    response.complete(loginResponse());
    expect(await login, isFalse);
    expect(controller.status, AuthStatus.unauthenticated);
    controller.dispose();
    service.dispose();
  });
}
