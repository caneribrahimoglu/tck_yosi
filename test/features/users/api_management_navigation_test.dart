import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tck_yosi/app/app.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import '../auth/data/services/api_auth_service_test.dart'
    show apiUser, loginResponse;

void main() {
  testWidgets(
    'chief home opens actual user management; create survives logout and team pool uses real users',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const grants = [
        'manageUsers',
        'manageTeamPermissions',
        'viewPersonnel',
        'viewAllTechnicalWork',
      ];
      final chief = apiUser(permissions: grants);
      final users = <Map<String, Object?>>[chief];
      final api = ApiAuthService(
        baseUrl: Uri.parse('http://localhost/api/v1/'),
        sessionStore: MemorySessionStore(),
        client: MockClient((request) async {
          Object? result;
          final path = request.url.path;
          if (path.endsWith('/login')) {
            return loginResponse(permissions: grants);
          }
          if (path.endsWith('/actor-capabilities')) {
            result = {'can_start': false};
          } else if (path.endsWith('/me')) {
            result = chief;
          } else if (path.endsWith('/users') && request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            result = <String, Object?>{
              'id': 'real-new-user',
              'full_name': body['full_name'],
              'username': body['username'],
              'role': body['role'],
              'is_active': true,
              'must_change_password': true,
              'permissions': <String>[],
            };
            users.add(result as Map<String, Object?>);
          } else if (path.endsWith('/users') || path.endsWith('/directory')) {
            result = users;
          } else if (path.endsWith('/effective-permissions')) {
            result = grants;
          } else if (path.endsWith('/teams')) {
            result = [
              {
                'id': 'real-team',
                'name': 'Teknik Ekip',
                'description': 'Kalıcı ekip',
                'is_active': true,
                'is_archived': false,
                'permissions': <String>[],
              },
            ];
          } else {
            result = [];
          }
          return http.Response(
            jsonEncode(result),
            request.method == 'POST' ? 201 : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(TckYosiApp(authService: api));
      await tester.pumpAndSettle();
      Future<void> login() async {
        await tester.enterText(find.byType(TextFormField).at(0), 'sef');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Test-Parola-2026',
        );
        await tester.tap(find.text('Giriş Yap'));
        await tester.pumpAndSettle();
      }

      await login();
      await tester.tap(find.text('Personel Yönetimi').first);
      await tester.pumpAndSettle();
      expect(find.text('Kullanıcı Yönetimi'), findsOneWidget);
      await tester.tap(find.text('Kullanıcı Oluştur'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'Gerçek Yeni Mühendis',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kullanıcı adı'),
        'yenimuhendis',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Geçici parola'),
        'Gecici-Parola-2026',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Gerçek Yeni Mühendis'), findsOneWidget);
      expect(find.text('real-new-user'), findsNothing);
      await tester.tap(find.byTooltip('Çıkış yap'));
      await tester.pumpAndSettle();
      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text('Kullanıcı Yönetimi'), findsNothing);
      await login();
      await tester.tap(find.text('Personel Yönetimi').first);
      await tester.pumpAndSettle();
      expect(find.text('Gerçek Yeni Mühendis'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operasyon Merkezi').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ekip Yönetimi'));
      await tester.pumpAndSettle();
      expect(find.text('Teknik Ekip'), findsWidgets);
      expect(find.textContaining('Gerçek Yeni Mühendis'), findsWidgets);
      expect(find.textContaining('Zeynep Demir'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
