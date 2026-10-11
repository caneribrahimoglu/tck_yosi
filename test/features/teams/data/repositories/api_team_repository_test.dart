import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tck_yosi/core/network/api_exception.dart';
import 'package:tck_yosi/features/auth/data/services/api_auth_service.dart';
import 'package:tck_yosi/features/auth/data/services/api_user_directory.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/data/session/session_store.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/teams/data/repositories/api_team_repository.dart';
import 'package:tck_yosi/features/teams/data/adapters/user_assignment_target_adapter.dart';
import 'package:tck_yosi/features/teams/domain/errors/archived_team_name_conflict.dart';
import 'package:tck_yosi/features/teams/domain/services/team_archive_guard.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_assignment_target_adapter.dart';
import '../../../auth/data/services/api_auth_service_test.dart'
    show apiUser, loginResponse;

class ArchiveGuard implements TeamArchiveGuard {
  bool open = false;
  @override
  Future<bool> hasOpenTechnicalWork(String teamId) async => open;
}

final teamJson = <String, Object?>{
  'id': 'real-team-id',
  'name': 'Gerçek Teknik Ekip',
  'description': 'Sunucu ekibi',
  'is_active': true,
  'is_archived': false,
  'permissions': ['startTechnicalWork'],
};
http.Response jsonResponse(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  Future<ApiAuthService> service(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final api = ApiAuthService(
      baseUrl: Uri.parse('http://localhost/api/v1/'),
      sessionStore: MemorySessionStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) return loginResponse();
        if (request.url.path.endsWith('/me')) return jsonResponse(apiUser());
        expect(request.headers['Authorization'], 'Bearer test-token');
        return handler(request);
      }),
    );
    await api.login(username: 'sef', password: 'Test-Parola-2026');
    addTearDown(api.dispose);
    return api;
  }

  test(
    'real immutable teams and members; client grants never sent to API',
    () async {
      final api = await service((r) async {
        if (r.method == 'POST') {
          expect(jsonDecode(r.body), {
            'name': 'Yeni Ekip',
            'description': 'Yeni',
          });
          return jsonResponse(teamJson, 201);
        }
        if (r.url.path.endsWith('/memberships')) {
          return jsonResponse([
            {
              'id': 'member-id',
              'team_id': 'real-team-id',
              'user_id': 'real-engineer-id',
              'is_active': false,
            },
          ]);
        }
        return jsonResponse([teamJson]);
      });
      final repository = ApiTeamRepository(
        api: api,
        archiveGuard: ArchiveGuard(),
      );
      final teams = await repository.getTeams();
      expect(teams.single.name, 'Gerçek Teknik Ekip');
      expect(() => teams.clear(), throwsUnsupportedError);
      expect(() => teams.single.permissions.clear(), throwsUnsupportedError);
      expect((await repository.getMemberships()).single.isActive, isFalse);
      await repository.createTeam(
        name: 'Yeni Ekip',
        description: 'Yeni',
        actorPermissions: {AppPermission.manageUsers},
      );
    },
  );

  test(
    'typed archived name conflict and server authorization mapped safely',
    () async {
      final api = await service(
        (r) async => r.url.path.endsWith('/teams')
            ? jsonResponse({
                'detail': {
                  'code': 'archived_team_name',
                  'team_id': 'real-team-id',
                  'team_name': 'Gerçek Teknik Ekip',
                },
              }, 409)
            : jsonResponse({
                'detail': {'code': 'not_allowed'},
              }, 403),
      );
      final repository = ApiTeamRepository(
        api: api,
        archiveGuard: ArchiveGuard(),
      );
      await expectLater(
        repository.createTeam(
          name: 'Yeni Ekip',
          description: '',
          actorPermissions: {},
        ),
        throwsA(isA<ArchivedTeamNameConflict>()),
      );
      await expectLater(
        repository.setTeamActive(
          teamId: 'real-team-id',
          isActive: true,
          actorPermissions: {AppPermission.manageTeamPermissions},
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'effective permissions resolve only current identity and ignore passed grants',
    () async {
      var calls = 0;
      final api = await service((r) async {
        calls++;
        return jsonResponse(['startTechnicalWork']);
      });
      final repository = ApiTeamRepository(
        api: api,
        archiveGuard: ArchiveGuard(),
      );
      expect(
        await repository.getEffectivePermissions(
          userId: 'other',
          directPermissions: {AppPermission.manageUsers},
        ),
        isEmpty,
      );
      expect(calls, 0);
      expect(
        await repository.getEffectivePermissions(
          userId: 'real-chief-uuid',
          directPermissions: {},
        ),
        {AppPermission.startTechnicalWork},
      );
      expect(calls, 1);
    },
  );

  test(
    'archive retains local open-work guard while operations remain fake',
    () async {
      var calls = 0;
      final api = await service((r) async {
        calls++;
        return jsonResponse(teamJson);
      });
      final guard = ArchiveGuard()..open = true;
      final repository = ApiTeamRepository(api: api, archiveGuard: guard);
      await expectLater(
        repository.archiveTeam(teamId: 'real-team-id', actorPermissions: {}),
        throwsStateError,
      );
      expect(calls, 0);
    },
  );

  test(
    'actual users and teams feed assignment targets; no demo identities',
    () async {
      final engineer = {
        ...apiUser(),
        'id': 'real-engineer-id',
        'role': 'engineer',
        'full_name': 'Gerçek Mühendis',
        'username': 'muhendis',
        'permissions': <String>[],
      };
      final api = await service(
        (r) async => jsonResponse(
          r.url.path.endsWith('/directory')
              ? [
                  engineer,
                  {...engineer, 'id': 'passive-id', 'is_active': false},
                ]
              : [
                  teamJson,
                  {...teamJson, 'id': 'passive-team', 'is_active': false},
                  {...teamJson, 'id': 'archived-team', 'is_archived': true},
                ],
        ),
      );
      final teams = ApiTeamRepository(api: api, archiveGuard: ArchiveGuard());
      final directory = ApiUserDirectory(
        api: api,
        legacyNames: FakeAuthService(),
      );
      final repository = FakeTechnicalWorkRepository(
        delay: Duration.zero,
        individualAssignmentTargetSource: UserAssignmentTargetAdapter(
          userDirectory: directory,
        ),
        teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
          repository: teams,
        ),
      );
      final targets = await repository.getAssignmentTargets();
      expect(targets.map((t) => t.id), ['real-engineer-id', 'real-team-id']);
      expect(
        (await directory.findUserById('real-engineer-id'))!.isActive,
        isFalse,
      );
      expect(
        (await directory.findUserById('user-engineer-001'))!.isActive,
        isFalse,
      );
      expect(
        (await directory.getAllUsers()).any((u) => u.id == 'user-engineer-001'),
        isFalse,
      );
    },
  );

  test(
    'business response after logout cannot restore data from previous session',
    () async {
      final pending = Completer<http.Response>();
      final api = await service((r) => pending.future);
      final request = api.requestBusiness('teams');
      await Future<void>.delayed(Duration.zero);
      await api.logout();
      pending.complete(jsonResponse([teamJson]));
      await expectLater(
        request,
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'session_expired'),
        ),
      );
    },
  );
}
