import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:tck_yosi/app/app.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import '../../../auth/data/services/api_auth_service_test.dart' show apiUser;
import '../../data/repositories/api_technical_work_repository_test.dart'
    show jsonResponse;
import '../../data/repositories/api_technical_work_execution_test.dart'
    show started;
import '../../data/repositories/api_completion_request_test.dart'
    show requestJson;

void main() {
  for (final reject in [false, true]) {
    testWidgets(
      'literal quick queue opens real API pending list and ${reject ? 'rejects' : 'approves'} with refreshed dashboard',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final chief = apiUser(
          permissions: [
            'viewAllTechnicalWork',
            'reviewTechnicalWorkCompletion',
          ],
        );
        var work = started(status: 'awaitingCompletionApproval', revision: 3);
        var request = requestJson();
        var reviews = 0;
        var pendingReads = 0;
        final api = ApiAuthService(
          baseUrl: Uri.parse('http://localhost/api/v1/'),
          sessionStore: MemorySessionStore(),
          client: MockClient((r) async {
            final path = r.url.path;
            if (path.endsWith('/login')) {
              return jsonResponse({
                'access_token': 'test-token',
                'token_type': 'bearer',
                'expires_in': 1800,
                'user': chief,
              });
            }
            if (path.endsWith('/me')) return jsonResponse(chief);
            if (path.endsWith('/directory')) return jsonResponse([chief]);
            if (path.endsWith('/teams')) {
              return jsonResponse([
                {
                  'id': 'real-team',
                  'name': 'Gercek Teknik Ekip',
                  'description': '',
                  'is_active': true,
                  'is_archived': false,
                  'permissions': <String>[],
                },
              ]);
            }
            if (path.endsWith('/actor-capabilities')) {
              return jsonResponse({'can_start': false});
            }
            if (path.endsWith('/pending')) {
              pendingReads++;
              return jsonResponse(
                request['decision'] == 'pending'
                    ? [
                        {'work': work, 'request': request},
                      ]
                    : [],
              );
            }
            if (path.endsWith('/approve') || path.endsWith('/reject')) {
              reviews++;
              expect(
                jsonDecode(r.body),
                reject ? {'reason': 'Eksik kontrol tamamlanmali.'} : {},
              );
              work = {
                ...work,
                'status': reject ? 'inProgress' : 'completed',
                'revision': 4,
                'completed_at': reject ? null : '2026-10-29T13:00:00Z',
              };
              request = {
                ...request,
                'decision': reject ? 'rejected' : 'approved',
                'reviewed_by_user_id': 'real-chief-uuid',
                'reviewed_at': '2026-10-29T13:00:00Z',
                'rejection_reason': reject
                    ? 'Eksik kontrol tamamlanmali.'
                    : null,
              };
              return jsonResponse({'work': work, 'request': request});
            }
            if (path.endsWith('/technical-works')) return jsonResponse([work]);
            if (path.endsWith('/work-uuid')) return jsonResponse(work);
            if (path.endsWith('/completion-requests')) {
              return jsonResponse([request]);
            }
            if (path.endsWith('/progress') || path.endsWith('/holds')) {
              return jsonResponse([]);
            }
            if (path.endsWith('/capabilities')) {
              return jsonResponse({
                'can_add_progress': false,
                'can_pause': false,
                'can_resume': false,
                'can_request_completion': false,
              });
            }
            throw StateError('Unexpected API ${r.method} $path');
          }),
        );
        addTearDown(api.dispose);
        await tester.pumpWidget(TckYosiApp(authService: api));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), 'sef');
        await tester.enterText(find.byType(TextFormField).at(1), 'Test');
        await tester.tap(find.text('Giriş Yap'));
        await tester.pumpAndSettle();
        expect(pendingReads, greaterThan(0));
        expect(find.text('Tamamlama onayı'), findsOneWidget);
        await tester.tap(find.text('Operasyon Merkezi').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Onay Kuyruğu'));
        await tester.tap(find.text('Onay Kuyruğu'));
        await tester.pumpAndSettle();
        expect(find.text('İş Tamamlama Onayları'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(
          find.textContaining('Talep eden: Gerçek Test Şef'),
          findsOneWidget,
        );
        expect(find.text('request-id'), findsNothing);
        expect(find.text('real-chief-uuid'), findsNothing);
        tester.view.physicalSize = const Size(360, 800);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(reject ? 'Reddet' : 'Onayla'));
        await tester.tap(find.text(reject ? 'Reddet' : 'Onayla'));
        await tester.pumpAndSettle();
        if (reject) {
          await tester.tap(find.text('Reddet').last);
          await tester.pumpAndSettle();
          expect(find.text('Ret nedeni boş olamaz.'), findsOneWidget);
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Ret nedeni'),
            'Eksik kontrol tamamlanmali.',
          );
        }
        await tester.tap(find.text(reject ? 'Reddet' : 'Onayla').last);
        await tester.pumpAndSettle();
        expect(reviews, 1);
        expect(find.text('Bekleyen iş tamamlama onayı yok.'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(1400, 1100);
        await tester.pumpAndSettle();
        expect(find.text(reject ? 'Devam Ediyor' : 'Tamamlandı'), findsWidgets);
        await tester.ensureVisible(find.text('Detayı Gör').first);
        await tester.tap(find.text('Detayı Gör').first);
        await tester.pumpAndSettle();
        expect(find.text(reject ? 'Reddedildi' : 'Onaylandı'), findsOneWidget);
        expect(
          find.textContaining('İnceleyen: Gerçek Test Şef'),
          findsOneWidget,
        );
        if (reject) {
          expect(
            find.text('Ret nedeni: Eksik kontrol tamamlanmali.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
