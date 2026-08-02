import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/domain/models/team.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_controller.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_load_status.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_list_filter.dart';

void main() {
  TeamController createController({Duration delay = Duration.zero}) {
    final controller = TeamController(
      repository: FakeTeamRepository(delay: delay),
      actorPermissions: const {
        AppPermission.createFieldReport,
        AppPermission.viewReports,
        AppPermission.manageUsers,
        AppPermission.manageTeamPermissions,
      },
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('ekipleri, üyelikleri ve adayları yükler', () async {
    final controller = createController();

    await controller.load();

    expect(controller.status, TeamLoadStatus.loaded);
    expect(controller.teams.single.name, 'Teknik Ekip');
    expect(controller.memberships, hasLength(1));
    expect(controller.candidates, isNotEmpty);
  });

  test('ekip oluşturma, üyelik ve yetki akışını yönetir', () async {
    final controller = createController();
    await controller.load();

    expect(
      await controller.createTeam(name: 'Gece Ekibi', description: 'Gece'),
      isTrue,
    );
    final team = controller.selectedTeam!;
    expect(
      await controller.addMember(teamId: team.id, userId: 'user-engineer-001'),
      isTrue,
    );
    expect(
      await controller.updatePermissions(
        teamId: team.id,
        permissions: {AppPermission.viewReports},
      ),
      isTrue,
    );

    expect(
      controller.isMember(teamId: team.id, userId: 'user-engineer-001'),
      isTrue,
    );
    expect(controller.selectedTeam!.permissions, {AppPermission.viewReports});
  });

  test('korunan yetkiler controller grantable listesinde görünmez', () {
    final controller = createController();

    expect(
      controller.grantablePermissions,
      contains(AppPermission.viewReports),
    );
    expect(
      controller.grantablePermissions,
      isNot(contains(AppPermission.manageUsers)),
    );
    expect(
      controller.grantablePermissions,
      isNot(contains(AppPermission.manageTeamPermissions)),
    );
  });

  test('geçersiz ekip adı repository çağrısından önce reddedilir', () async {
    final controller = createController();
    await controller.load();

    final result = await controller.createTeam(name: '  A ', description: '');

    expect(result, isFalse);
    expect(controller.errorMessage, 'Ekip adı en az 3 karakter olmalıdır.');
    expect(controller.teams, hasLength(1));
  });

  test('işlem sürerken tekrar tıklamayı reddeder', () async {
    final controller = createController(
      delay: const Duration(milliseconds: 20),
    );
    await controller.load();

    final first = controller.createTeam(name: 'Birinci Ekip', description: '');
    final second = await controller.createTeam(
      name: 'İkinci Ekip',
      description: '',
    );

    expect(second, isFalse);
    expect(await first, isTrue);
    expect(
      controller.teams.where((team) => team.name == 'Birinci Ekip'),
      hasLength(1),
    );
    expect(
      controller.teams.where((team) => team.name == 'İkinci Ekip'),
      isEmpty,
    );
  });

  test('repository yükleme hatası failure durumuna geçer', () async {
    final controller = TeamController(
      repository: _FailingTeamRepository(),
      actorPermissions: const {},
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.status, TeamLoadStatus.failure);
    expect(controller.errorMessage, 'Ekip bilgileri yüklenemedi.');
  });

  test(
    'yetkisiz kullanıcı bütün ekip mutasyonlarında erken reddedilir',
    () async {
      final controller = TeamController(
        repository: FakeTeamRepository(delay: Duration.zero),
        actorPermissions: const {},
      );
      addTearDown(controller.dispose);
      await controller.load();

      final results = [
        await controller.createTeam(name: 'Yeni Ekip', description: ''),
        await controller.updateTeam(
          teamId: 'team-technical',
          name: 'Yeni Ad',
          description: '',
        ),
        await controller.setTeamActive(
          teamId: 'team-technical',
          isActive: false,
        ),
        await controller.addMember(
          teamId: 'team-technical',
          userId: 'user-driver-001',
        ),
        await controller.removeMember(
          teamId: 'team-technical',
          userId: 'user-engineer-001',
        ),
        await controller.archiveTeam('team-technical'),
        await controller.restoreTeam('team-technical'),
      ];

      expect(results, everyElement(isFalse));
      expect(controller.errorMessage, 'Ekip yönetimi yetkiniz bulunmuyor.');
      expect(controller.teams.single.isActive, isTrue);
      expect(controller.memberships, hasLength(1));
    },
  );

  test('controller arşivlenmiş ekibi pasif olarak geri yükler', () async {
    final controller = createController();
    await controller.load();
    final original = controller.selectedTeam!;
    final originalMemberships = controller.membershipsFor(original.id);
    await controller.archiveTeam(original.id);
    controller.setListFilter(TeamListFilter.archived);

    final result = await controller.restoreTeam(original.id);

    expect(result, isTrue);
    expect(controller.listFilter, TeamListFilter.active);
    expect(controller.selectedTeam!.id, original.id);
    expect(controller.selectedTeam!.isArchived, isFalse);
    expect(controller.selectedTeam!.isActive, isFalse);
    expect(controller.selectedTeam!.permissions, original.permissions);
    expect(controller.membershipsFor(original.id), originalMemberships);
  });

  test(
    'controller archived-name conflict bilgisini typed olarak taşır',
    () async {
      final controller = createController();
      await controller.load();
      await controller.archiveTeam('team-technical');

      final result = await controller.createTeam(
        name: 'teknik ekip',
        description: '',
      );

      expect(result, isFalse);
      expect(controller.archivedNameConflict?.teamId, 'team-technical');
    },
  );
}

class _FailingTeamRepository extends FakeTeamRepository {
  _FailingTeamRepository() : super(delay: Duration.zero);

  @override
  Future<List<Team>> getTeams() async {
    throw Exception('Repository error');
  }
}
