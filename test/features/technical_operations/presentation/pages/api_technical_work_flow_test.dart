import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:tck_yosi/app/app.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/assignment_target.dart';
import 'package:tck_yosi/shared/widgets/app_dropdown.dart';
import '../../data/repositories/api_technical_work_repository_test.dart'
    show workJson, jsonResponse, grants;
import '../../../auth/data/services/api_auth_service_test.dart' show apiUser;

void main() {
  testWidgets(
    'real report, team assignment and execution persist across chief/engineer sessions',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chief = apiUser(permissions: grants);
      final engineer = <String, Object?>{
        ...apiUser(permissions: const []),
        'id': 'engineer-uuid',
        'username': 'engineer',
        'role': 'engineer',
        'full_name': 'Gerçek Mühendis',
      };
      Map<String, Object?> current = chief;
      Map<String, Object?>? stored;
      final notes = <Map<String, Object?>>[];
      final holds = <Map<String, Object?>>[];
      final team = {
        'id': 'team-uuid',
        'name': 'Gerçek Teknik Ekip',
        'description': 'Sunucu ekibi',
        'is_active': true,
        'is_archived': false,
        'permissions': [
          'startTechnicalWork',
          'addTechnicalWorkProgress',
          'pauseTechnicalWork',
          'resumeTechnicalWork',
        ],
      };
      var creates = 0;
      final submissionIds = <String>[];
      var assignments = 0;
      final api = ApiAuthService(
        baseUrl: Uri.parse('http://localhost/api/v1/'),
        sessionStore: MemorySessionStore(),
        client: MockClient((r) async {
          final path = r.url.path;
          if (path.endsWith('/login')) {
            current = jsonDecode(r.body)['username'] == 'engineer'
                ? engineer
                : chief;
            return jsonResponse({
              'access_token': current == chief
                  ? 'chief-token'
                  : 'engineer-token',
              'token_type': 'bearer',
              'expires_in': 1800,
              'user': current,
            });
          }
          if (path.endsWith('/me')) return jsonResponse(current);
          if (path.endsWith('/directory')) {
            return jsonResponse([chief, engineer]);
          }
          if (path.endsWith('/teams')) return jsonResponse([team]);
          if (path.endsWith('/actor-capabilities')) {
            return jsonResponse({'can_start': current == engineer});
          }
          if (path.endsWith('/capabilities')) {
            return jsonResponse({
              'can_start':
                  current == engineer && stored?['status'] == 'assigned',
              'can_add_progress':
                  current == engineer && stored?['status'] == 'inProgress',
              'can_pause':
                  current == engineer && stored?['status'] == 'inProgress',
              'can_resume':
                  current == engineer && stored?['status'] == 'onHold',
            });
          }
          if (path.endsWith('/start')) {
            expect(jsonDecode(r.body), {'expected_revision': 1});
            stored = {
              ...stored!,
              'status': 'inProgress',
              'revision': 2,
              'started_by_user_id': 'engineer-uuid',
              'started_at': '2026-10-11T10:10:00Z',
            };
            return jsonResponse(stored);
          }
          if (path.endsWith('/progress')) {
            if (r.method == 'POST') {
              notes.add({
                'id': 'note-uuid',
                'work_id': 'work-uuid',
                'author_user_id': 'engineer-uuid',
                'content': jsonDecode(r.body)['content'],
                'created_at': '2026-10-11T10:12:00Z',
              });
              return jsonResponse(notes.last, 201);
            }
            return jsonResponse(notes);
          }
          if (path.endsWith('/holds')) return jsonResponse(holds);
          if (path.endsWith('/hold') || path.endsWith('/resume')) {
            final body = jsonDecode(r.body);
            expect(body['expected_revision'], stored!['revision']);
            if (path.endsWith('/hold')) {
              holds.add({
                'id': 'hold-${holds.length}',
                'work_id': 'work-uuid',
                'held_by_user_id': 'engineer-uuid',
                'held_at': '2026-10-11T10:15:00Z',
                'reason': body['reason'],
                'resumed_by_user_id': null,
                'resumed_at': null,
              });
              stored = {
                ...stored!,
                'status': 'onHold',
                'revision': (stored!['revision'] as int) + 1,
              };
            } else {
              holds[holds.length - 1] = {
                ...holds.last,
                'resumed_by_user_id': 'engineer-uuid',
                'resumed_at': '2026-10-11T10:20:00Z',
              };
              stored = {
                ...stored!,
                'status': 'inProgress',
                'revision': (stored!['revision'] as int) + 1,
              };
            }
            return jsonResponse({'work': stored, 'record': holds.last});
          }
          if (path.endsWith('/assignment-targets')) {
            return jsonResponse([
              {'id': 'team-uuid', 'name': 'Gerçek Teknik Ekip', 'type': 'team'},
            ]);
          }
          if (path.endsWith('/technical-works') && r.method == 'POST') {
            creates++;
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            submissionIds.add(body['submission_id'] as String);
            stored = {
              ...workJson(),
              'title': body['title'],
              'description': body['description'],
              'location': body['location'],
              'category': body['category'],
            };
            if (creates == 1) {
              // Server saved the report, but the client did not receive success.
              return jsonResponse({
                'detail': {'code': 'unknown'},
              }, 500);
            }
            return jsonResponse(stored, 201);
          }
          if (path.endsWith('/assign')) {
            assignments++;
            final body = jsonDecode(r.body);
            expect(body['assigned_to_team_id'], 'team-uuid');
            expect(body['expected_revision'], 0);
            stored = {
              ...stored!,
              'assigned_to_team_id': 'team-uuid',
              'status': 'assigned',
              'revision': 1,
            };
            return jsonResponse(stored);
          }
          if (path.endsWith('/technical-works')) {
            final assignedOnly =
                r.url.queryParameters['assigned_only'] == 'true';
            return jsonResponse(
              stored == null || (assignedOnly && current == chief)
                  ? []
                  : [stored],
            );
          }
          if (path.endsWith('/work-uuid')) return jsonResponse(stored);
          throw StateError('Unexpected endpoint: ${r.method} $path');
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(TckYosiApp(authService: api));
      await tester.pumpAndSettle();
      Future<void> login(String user) async {
        await tester.enterText(find.byType(TextFormField).at(0), user);
        await tester.enterText(find.byType(TextFormField).at(1), 'Test');
        await tester.tap(find.text('Giriş Yap'));
        await tester.pumpAndSettle();
      }

      await login('sef');
      expect(find.text('Şeflik Ana Sayfası'), findsOneWidget);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1400, 1100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operasyon Merkezi').first);
      await tester.pumpAndSettle();
      expect(find.text('Onay Kuyruğu'), findsNothing);
      await tester.tap(find.text('Saha Bildirimi Oluştur'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppDropdown<TechnicalWorkCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yol yüzeyi').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Başlık'),
        'Kalıcı yol bildirimi',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Açıklama'),
        'Kalıcı saha açıklaması',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Konum'),
        'Test km 42',
      );
      await tester.ensureVisible(find.text('Bildirimi Gönder'));
      await tester.tap(find.text('Bildirimi Gönder'));
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(find.text('Saha Bildirimi Oluştur'), findsOneWidget);
      await tester.tap(find.text('Bildirimi Gönder'));
      await tester.pumpAndSettle();
      expect(creates, 2);
      expect(submissionIds.toSet().length, 1);
      expect(find.text('Kalıcı yol bildirimi'), findsWidgets);
      await tester.ensureVisible(find.text('İncele ve Ata').first);
      await tester.tap(find.text('İncele ve Ata').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppDropdown<AssignmentTarget>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gerçek Teknik Ekip (Ekip)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Görevi Ata'));
      await tester.pumpAndSettle();
      expect(assignments, 1);
      expect(find.text('Atanan: Gerçek Teknik Ekip'), findsWidgets);
      await tester.tap(find.byTooltip('Çıkış yap'));
      await tester.pumpAndSettle();
      expect(find.text('Giriş Yap'), findsOneWidget);
      await login('engineer');
      expect(find.text('Teknik Operasyonlar'), findsOneWidget);
      expect(find.text('Kalıcı yol bildirimi'), findsOneWidget);
      expect(find.text('İşi Başlat'), findsOneWidget);
      await tester.ensureVisible(find.text('İşi Başlat'));
      await tester.tap(find.text('İşi Başlat'));
      await tester.pumpAndSettle();
      expect(find.text('İşi Başlat'), findsNothing);
      expect(find.text('Devam Ediyor'), findsWidgets);
      expect(stored!['assigned_to_team_id'], 'team-uuid');
      await tester.ensureVisible(find.text('Detayı Gör').first);
      await tester.tap(find.text('Detayı Gör').first);
      await tester.pumpAndSettle();
      expect(find.text('Gerçek Teknik Ekip'), findsOneWidget);
      expect(find.text('Gerçek Test Şef'), findsOneWidget);
      expect(find.text('Kalıcı saha açıklaması'), findsOneWidget);
      expect(find.text('İlerleme Kaydı Ekle'), findsOneWidget);
      expect(find.text('Tamamlanmak Üzere Gönder'), findsNothing);
      await tester.ensureVisible(find.text('İlerleme Kaydı Ekle'));
      await tester.tap(find.text('İlerleme Kaydı Ekle'));
      await tester.pumpAndSettle();
      expect(find.text('İlerleme notu boş olamaz.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'İlerleme notu'),
        'Kalıcı ilerleme notu',
      );
      await tester.ensureVisible(find.text('İlerleme Kaydı Ekle'));
      await tester.tap(find.text('İlerleme Kaydı Ekle'));
      await tester.pumpAndSettle();
      expect(notes.length, 1);
      expect(find.text('Kalıcı ilerleme notu'), findsOneWidget);
      await tester.ensureVisible(find.text('Beklemeye Al'));
      await tester.tap(find.text('Beklemeye Al'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beklemeye Al').last);
      await tester.pumpAndSettle();
      expect(find.text('Bekleme nedeni boş olamaz.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bekleme nedeni'),
        'Malzeme bekleniyor',
      );
      await tester.tap(find.text('Beklemeye Al').last);
      await tester.pumpAndSettle();
      expect(find.text('Beklemeye Alındı'), findsWidgets);
      expect(find.text('İlerleme Kaydı Ekle'), findsNothing);
      expect(find.text('Neden: Malzeme bekleniyor'), findsOneWidget);
      await tester.ensureVisible(find.text('Çalışmaya Devam Et'));
      await tester.tap(find.text('Çalışmaya Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('İlerleme Kaydı Ekle'), findsOneWidget);
      expect(
        find.textContaining('Devam eden: Gerçek Mühendis'),
        findsOneWidget,
      );
      expect(stored!['started_at'], '2026-10-11T10:10:00Z');
      expect(holds.single['id'], 'hold-0');
      expect(find.text('work-uuid'), findsNothing);
      expect(find.text('team-uuid'), findsNothing);
      expect(find.text('real-chief-uuid'), findsNothing);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1400, 1100);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Devam Ediyor'), findsWidgets);
      await tester.tap(find.byTooltip('Çıkış yap'));
      await tester.pumpAndSettle();
      await login('sef');
      await tester.tap(find.text('Operasyon Merkezi').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Detayı Gör').first);
      await tester.tap(find.text('Detayı Gör').first);
      await tester.pumpAndSettle();
      expect(find.text('Kalıcı ilerleme notu'), findsOneWidget);
      expect(find.text('Neden: Malzeme bekleniyor'), findsOneWidget);
      expect(
        find.textContaining('Beklemeye alan: Gerçek Mühendis'),
        findsOneWidget,
      );
      expect(find.text('İlerleme Kaydı Ekle'), findsNothing);
      expect(find.text('Beklemeye Al'), findsNothing);
      expect(find.text('engineer-uuid'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
