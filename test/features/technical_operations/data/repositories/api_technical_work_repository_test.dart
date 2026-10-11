import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tck_yosi/core/network/api_exception.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/api_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/assignment_target_type.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_detail_read_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/assignment_target.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/create_field_report_request.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_load_status.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_submission_status.dart';
import '../../../auth/data/services/api_auth_service_test.dart'
    show apiUser, loginResponse;

const grants = [
  'viewAllTechnicalWork',
  'assignTechnicalWork',
  'createFieldReport',
];
Map<String, Object?> workJson({int revision = 0, String? team, String? user}) =>
    {
      'id': 'work-uuid',
      'title': 'Gerçek yol bildirimi',
      'description': 'Yol açıklaması',
      'location': 'Test km 1',
      'category': 'roadSurface',
      'priority': 'normal',
      'status': team != null || user != null ? 'assigned' : 'reported',
      'created_by_user_id': 'real-chief-uuid',
      'assigned_to_user_id': user,
      'assigned_to_team_id': team,
      'created_at': '2026-10-11T10:00:00Z',
      'revision': revision,
      'planned_at': null,
      'completed_at': null,
      'started_by_user_id': null,
      'started_at': null,
    };
http.Response jsonResponse(Object? body, [int code = 200]) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json'},
);

Future<ApiTechnicalWorkRepository> repository(
  Future<http.Response> Function(http.Request) handler, {
  List<String> permissions = grants,
}) async {
  final api = ApiAuthService(
    baseUrl: Uri.parse('http://localhost/api/v1/'),
    sessionStore: MemorySessionStore(),
    client: MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return loginResponse(permissions: permissions);
      }
      if (request.url.path.endsWith('/me')) {
        return jsonResponse(apiUser(permissions: permissions));
      }
      expect(request.url.path, startsWith('/api/v1/technical-works'));
      expect(request.headers['Authorization'], 'Bearer test-token');
      return handler(request);
    }),
  );
  await api.login(username: 'sef', password: 'test');
  addTearDown(api.dispose);
  return ApiTechnicalWorkRepository(api: api);
}

void main() {
  test(
    'real immutable lists, secure actor and local timestamps; revisions survive copyWith',
    () async {
      final repo = await repository(
        (r) async => r.url.path.endsWith('/work-uuid')
            ? jsonResponse(workJson(revision: 4))
            : jsonResponse([workJson(revision: 4)]),
      );
      final works = await repo.getAllWorks();
      expect(works.single.title, 'Gerçek yol bildirimi');
      expect(works.single.createdAt.toUtc(), DateTime.utc(2026, 10, 11, 10));
      expect(works.single.copyWith().revision, 4);
      expect(() => works.clear(), throwsUnsupportedError);
      expect((await repo.getAssignedWorks('real-chief-uuid')).length, 1);
      expect(
        (await repo.getWorkById(
          workId: 'work-uuid',
          actorUserId: 'real-chief-uuid',
        )).id,
        'work-uuid',
      );
      await expectLater(
        repo.getAssignedWorks('forged-user'),
        throwsA(isA<TechnicalWorkDetailReadNotAllowedException>()),
      );
    },
  );

  test(
    'same report retry reuses UUID; never sends creator/status/priority from client',
    () async {
      final keys = <String>[];
      final repo = await repository((r) async {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        expect(data.keys.toSet(), {
          'submission_id',
          'title',
          'description',
          'location',
          'category',
        });
        keys.add(data['submission_id'] as String);
        return jsonResponse(workJson(), 201);
      });
      final request = CreateFieldReportRequest(
        category: TechnicalWorkCategory.roadSurface,
        title: 'T',
        description: 'D',
        location: 'L',
      );
      await repo.createFieldReport(
        request: request,
        createdByUserId: 'real-chief-uuid',
      );
      await repo.createFieldReport(
        request: request,
        createdByUserId: 'real-chief-uuid',
      );
      expect(keys.toSet().length, 1);
      expect(keys.singleOrNull, isNull);
      expect(
        keys.first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    },
  );

  test(
    'real assignment targets and explicit captured revision, exactly one target',
    () async {
      final repo = await repository((r) async {
        if (r.url.path.endsWith('/assignment-targets')) {
          return jsonResponse([
            {'id': 'team-uuid', 'name': 'Teknik Ekip', 'type': 'team'},
          ]);
        }
        if (r.method == 'POST') {
          expect(jsonDecode(r.body), {
            'priority': 'high',
            'assigned_to_user_id': null,
            'assigned_to_team_id': 'team-uuid',
            'expected_revision': 0,
          });
          return jsonResponse(workJson(revision: 1, team: 'team-uuid'));
        }
        return jsonResponse([workJson(revision: 3)]);
      });
      final targets = await repo.getAssignmentTargets();
      expect(targets.single.name, 'Teknik Ekip');
      expect(() => targets.clear(), throwsUnsupportedError);
      await repo.getAllWorks();
      final work = await repo.assignWork(
        workId: 'work-uuid',
        expectedRevision: 0,
        priority: TechnicalWorkPriority.high,
        target: targets.single,
      );
      expect(work.assignedToUserId, isNull);
      expect(work.assignedToTeamId, 'team-uuid');
      expect(work.revision, 1);
    },
  );

  test(
    'no global assign grant; real execution but no demo completion fallback',
    () async {
      var requests = 0;
      final repo = await repository((r) async {
        requests++;
        return jsonResponse({'can_start': false});
      }, permissions: const []);
      expect(await repo.getAssignmentTargets(), isEmpty);
      expect(requests, 0);
      expect(repo.supportsExecution, isTrue);
      expect(repo.supportsCompletion, isFalse);
      expect(await repo.canUserStartTechnicalWork('real-chief-uuid'), isFalse);
      await expectLater(
        repo.getPendingCompletionReviews(actorUserId: 'real-chief-uuid'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'feature_not_available',
          ),
        ),
      );
      expect(requests, 1);
    },
  );

  test('detail denial is typed and does not expose existence', () async {
    final repo = await repository(
      (r) async => jsonResponse({
        'detail': {'code': 'technical_work_read_not_allowed'},
      }, 403),
    );
    for (final id in ['existing', 'missing']) {
      await expectLater(
        repo.getWorkById(workId: id, actorUserId: 'real-chief-uuid'),
        throwsA(isA<TechnicalWorkDetailReadNotAllowedException>()),
      );
    }
  });

  test(
    'controller catches parallel load failures without unhandled future errors',
    () async {
      final repo = await repository(
        (r) async => jsonResponse({
          'detail': {'code': 'not_allowed'},
        }, 403),
      );
      final controller = TechnicalWorkController(repository: repo);
      addTearDown(controller.dispose);
      await controller.load('real-chief-uuid');
      expect(controller.status, TechnicalWorkLoadStatus.failure);
      expect(controller.allWorks, isEmpty);
    },
  );

  test(
    'stale assignment refreshes actual state and uses safe conflict message',
    () async {
      final repo = await repository((r) async {
        if (r.method == 'POST') {
          return jsonResponse({
            'detail': {'code': 'work_revision_conflict'},
          }, 409);
        }
        if (r.url.path.endsWith('/assignment-targets')) return jsonResponse([]);
        if (r.url.path.endsWith('/actor-capabilities')) {
          return jsonResponse({'can_start': false});
        }
        return jsonResponse([workJson(revision: 1, team: 'another-team')]);
      });
      final controller = TechnicalWorkController(repository: repo);
      addTearDown(controller.dispose);
      await controller.load('real-chief-uuid');
      expect(
        await controller.assignWork(
          workId: 'work-uuid',
          expectedRevision: 0,
          priority: TechnicalWorkPriority.high,
          target: const AssignmentTarget(
            id: 'team',
            name: 'T',
            type: AssignmentTargetType.team,
          ),
        ),
        isFalse,
      );
      expect(controller.allWorks.single.assignedToTeamId, 'another-team');
      expect(controller.errorMessage, contains('başka bir işlemle'));
      expect(controller.isAssigning, isFalse);
    },
  );

  test(
    'report controller prevents double submit and logout discards late response',
    () async {
      final gate = Completer<http.Response>();
      var posts = 0;
      final repo = await repository((r) async {
        posts++;
        return gate.future;
      });
      final controller = FieldReportController(repository: repo);
      addTearDown(controller.dispose);
      final request = CreateFieldReportRequest(
        category: TechnicalWorkCategory.other,
        title: 'T',
        description: 'D',
        location: 'L',
      );
      final first = controller.submit(
        request: request,
        createdByUserId: 'real-chief-uuid',
      );
      await Future<void>.delayed(Duration.zero);
      await controller.submit(
        request: request,
        createdByUserId: 'real-chief-uuid',
      );
      expect(posts, 1);
      expect(controller.status, FieldReportSubmissionStatus.submitting);
      controller.resetSession();
      gate.complete(jsonResponse(workJson(), 201));
      await first;
      expect(controller.createdWork, isNull);
      expect(controller.status, FieldReportSubmissionStatus.initial);
    },
  );
}
