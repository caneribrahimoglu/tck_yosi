import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/data/services/session_user_directory.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import 'api_auth_service_test.dart' show apiUser, loginResponse;

void main() {
  test(
    'password-change pending actor has no business mutation access',
    () async {
      final service = ApiAuthService(
        baseUrl: Uri.parse('http://localhost/api/v1/'),
        sessionStore: MemorySessionStore(),
        client: MockClient(
          (r) async => r.url.path.endsWith('/login')
              ? loginResponse(mustChange: true)
              : http.Response(
                  jsonEncode(apiUser(mustChange: true)),
                  200,
                  headers: {'content-type': 'application/json'},
                ),
        ),
      );
      await service.login(username: 'sef', password: 'x');
      final directory = SessionUserDirectory(
        authService: service,
        demoDirectory: FakeAuthService(),
      );
      final actor = await directory.findUserById('real-chief-uuid');
      expect(actor!.isActive, isFalse);
      expect(actor.permissions, isEmpty);
      service.dispose();
    },
  );
  test(
    'real actor never aliases demo IDs; former users are display-only after logout',
    () async {
      final service = ApiAuthService(
        baseUrl: Uri.parse('http://localhost/api/v1/'),
        sessionStore: MemorySessionStore(),
        client: MockClient(
          (r) async => r.url.path.endsWith('/login')
              ? loginResponse()
              : http.Response(
                  jsonEncode(apiUser()),
                  200,
                  headers: {'content-type': 'application/json'},
                ),
        ),
      );
      final directory = SessionUserDirectory(
        authService: service,
        demoDirectory: FakeAuthService(),
      );
      await service.login(username: 'sef', password: 'x');
      final real = await directory.findUserById('real-chief-uuid');
      expect(real!.isActive, isTrue);
      final demo = await directory.findUserById('user-chief-001');
      expect(demo!.isActive, isFalse);
      expect(demo.permissions, isEmpty);
      expect(demo.id, isNot(real.id));
      final users = await directory.getAllUsers();
      expect(() => users.clear(), throwsUnsupportedError);
      await service.logout();
      final former = await directory.findUserById(real.id);
      expect(former!.fullName, real.fullName);
      expect(former.isActive, isFalse);
      expect(former.permissions, isEmpty);
      service.dispose();
    },
  );
}
