import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tck_yosi/app/app.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import '../../data/services/api_auth_service_test.dart'
    show apiUser, loginResponse;

void main() {
  testWidgets('expired session removes a chief child route', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemorySessionStore();
    final service = ApiAuthService(
      baseUrl: Uri.parse('http://localhost/api/v1/'),
      sessionStore: store,
      client: MockClient(
        (r) async =>
            r.url.path.contains('/teams') ||
                r.url.path.contains('/technical-works') ||
                r.url.path.endsWith('/directory')
            ? http.Response(
                '[]',
                200,
                headers: {'content-type': 'application/json'},
              )
            : r.url.path.endsWith('/login')
            ? loginResponse(seconds: 10, permissions: ['viewAllTechnicalWork'])
            : http.Response(
                jsonEncode(apiUser(permissions: ['viewAllTechnicalWork'])),
                200,
                headers: {'content-type': 'application/json'},
              ),
      ),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(TckYosiApp(authService: service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'sef');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operasyon Merkezi').first);
    await tester.pumpAndSettle();
    expect(find.text('Şeflik Operasyon Merkezi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.text('Şeflik Operasyon Merkezi'), findsNothing);
    expect(await store.read(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'password form is mobile-safe and blocks mismatched confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var requests = 0;
      final service = ApiAuthService(
        baseUrl: Uri.parse('http://localhost/api/v1/'),
        sessionStore: MemorySessionStore(),
        client: MockClient((r) async {
          requests++;
          return loginResponse(mustChange: true);
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(TckYosiApp(authService: service));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'sef');
      await tester.enterText(find.byType(TextFormField).at(1), 'temporary');
      await tester.ensureVisible(find.text('Giriş Yap'));
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'temporary');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'valid-password-123',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'mismatch');
      await tester.ensureVisible(find.text('Parolayı Değiştir'));
      await tester.tap(find.text('Parolayı Değiştir'));
      await tester.pumpAndSettle();
      expect(find.text('Parolalar eşleşmiyor.'), findsOneWidget);
      expect(requests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'real auth password gate, chief home, child logout and different role',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var changed = false;
      var engineer = false;
      final store = MemorySessionStore();
      final service = ApiAuthService(
        baseUrl: Uri.parse('http://localhost/api/v1/'),
        sessionStore: store,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            engineer = jsonDecode(r.body)['username'] == 'engineer';
            if (!engineer) {
              return loginResponse(
                mustChange: !changed,
                permissions: ['viewVehicleFleet', 'viewAllTechnicalWork'],
              );
            }
          }
          if (r.url.path.endsWith('/change-password')) {
            changed = true;
            return http.Response('{}', 200);
          }
          if (r.url.path.contains('/teams') ||
              r.url.path.contains('/technical-works') ||
              r.url.path.endsWith('/directory')) {
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          final user = apiUser(mustChange: !changed);
          user['permissions'] = ['viewVehicleFleet', 'viewAllTechnicalWork'];
          if (engineer) {
            user.addAll({
              'id': 'real-engineer',
              'role': 'engineer',
              'full_name': 'Gerçek Mühendis',
              'username': 'engineer',
              'permissions': <String>[],
            });
          }
          if (r.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({
                'access_token': 'engineer-token',
                'token_type': 'bearer',
                'expires_in': 1800,
                'user': user,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(user),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(TckYosiApp(authService: service));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'sef');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'temporary-password',
      );
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      expect(find.text('Parolanızı Değiştirin'), findsOneWidget);
      expect(find.text('Şeflik Ana Sayfası'), findsNothing);
      await tester.tap(find.text('Parolayı Değiştir'));
      await tester.pumpAndSettle();
      expect(find.text('Mevcut parola zorunludur.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'temporary-password',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'new-password-123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'new-password-123',
      );
      await tester.tap(find.text('Parolayı Değiştir'));
      await tester.pumpAndSettle();
      expect(find.text('Şeflik Ana Sayfası'), findsOneWidget);
      await tester.tap(find.text('Operasyon Merkezi').first);
      await tester.pumpAndSettle();
      expect(find.text('Şeflik Operasyon Merkezi'), findsOneWidget);
      await tester.tap(find.byTooltip('Çıkış yap'));
      await tester.pumpAndSettle();
      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text('Şeflik Operasyon Merkezi'), findsNothing);
      expect(await store.read(), isNull);
      await tester.enterText(find.byType(TextFormField).at(0), 'engineer');
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      expect(find.text('Bana Atanan Teknik İşler'), findsOneWidget);
      expect(find.text('Şeflik Operasyon Merkezi'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
