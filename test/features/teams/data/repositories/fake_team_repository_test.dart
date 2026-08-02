import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/domain/services/team_archive_guard.dart';
import 'package:tck_yosi/features/teams/domain/errors/archived_team_name_conflict.dart';
import 'package:tck_yosi/features/teams/domain/models/team.dart';

void main() {
  const managerPermissions = {AppPermission.manageTeamPermissions};

  test('başlangıçta Teknik Ekip ve Zeynep üyeliği bulunur', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    final teams = await repository.getTeams();
    final memberships = await repository.getMemberships();

    expect(teams.single.name, 'Teknik Ekip');
    expect(memberships.single.userId, 'user-engineer-001');
    expect(memberships.single.teamId, teams.single.id);
  });

  test('aynı kullanıcı birden fazla ekibe eklenebilir', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);
    final secondTeam = await repository.createTeam(
      name: 'İkinci Ekip',
      description: '',
      actorPermissions: managerPermissions,
    );

    await repository.addMember(
      teamId: secondTeam.id,
      userId: 'user-engineer-001',
      actorPermissions: managerPermissions,
    );

    final memberships = await repository.getMemberships();
    expect(
      memberships.where((item) => item.userId == 'user-engineer-001'),
      hasLength(2),
    );
  });

  test('aynı üyelik iki kez oluşturulamaz', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    expect(
      () => repository.addMember(
        teamId: 'team-technical',
        userId: 'user-engineer-001',
        actorPermissions: managerPermissions,
      ),
      throwsStateError,
    );
  });

  test('üye ekipten çıkarılabilir', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    await repository.removeMember(
      teamId: 'team-technical',
      userId: 'user-engineer-001',
      actorPermissions: managerPermissions,
    );

    expect(await repository.getMemberships(), isEmpty);
  });

  test('ekip aktif ve pasif yapılabilir', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    final inactive = await repository.setTeamActive(
      teamId: 'team-technical',
      isActive: false,
      actorPermissions: managerPermissions,
    );
    final active = await repository.setTeamActive(
      teamId: 'team-technical',
      isActive: true,
      actorPermissions: managerPermissions,
    );

    expect(inactive.isActive, isFalse);
    expect(active.isActive, isTrue);
  });

  test('ekip adı ve açıklaması güncellenebilir', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    final updated = await repository.updateTeam(
      teamId: 'team-technical',
      name: 'Teknik Operasyon Ekibi',
      description: 'Güncellenmiş açıklama',
      actorPermissions: managerPermissions,
    );

    expect(updated.name, 'Teknik Operasyon Ekibi');
    expect(updated.description, 'Güncellenmiş açıklama');
  });

  test('ekip yetkileri güncellenir', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    final result = await repository.updatePermissions(
      teamId: 'team-technical',
      permissions: {AppPermission.assignTechnicalWork},
      actorPermissions: {
        AppPermission.assignTechnicalWork,
        AppPermission.manageTeamPermissions,
      },
    );

    expect(result.permissions, {AppPermission.assignTechnicalWork});
  });

  test('grant edilemeyen sistem yetkisi ekibe verilemez', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    expect(
      () => repository.updatePermissions(
        teamId: 'team-technical',
        permissions: {AppPermission.manageUsers},
        actorPermissions: {
          AppPermission.manageUsers,
          AppPermission.manageTeamPermissions,
        },
      ),
      throwsStateError,
    );
  });

  test('pasif ekip yetkileri etkin yetkilere katılmaz', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);
    await repository.updatePermissions(
      teamId: 'team-technical',
      permissions: {AppPermission.viewReports},
      actorPermissions: {
        AppPermission.viewReports,
        AppPermission.manageTeamPermissions,
      },
    );
    await repository.setTeamActive(
      teamId: 'team-technical',
      isActive: false,
      actorPermissions: managerPermissions,
    );

    final effective = await repository.getEffectivePermissions(
      userId: 'user-engineer-001',
      directPermissions: {AppPermission.createFieldReport},
    );

    expect(effective, {AppPermission.createFieldReport});
  });

  test('yetkisiz kullanıcı ekip mutasyonlarını yapamaz', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);
    final operations = <Future<Object?> Function()>[
      () => repository.createTeam(
        name: 'Yeni Ekip',
        description: '',
        actorPermissions: const {},
      ),
      () => repository.updateTeam(
        teamId: 'team-technical',
        name: 'Yeni Ad',
        description: '',
        actorPermissions: const {},
      ),
      () => repository.setTeamActive(
        teamId: 'team-technical',
        isActive: false,
        actorPermissions: const {},
      ),
      () => repository.addMember(
        teamId: 'team-technical',
        userId: 'user-driver-001',
        actorPermissions: const {},
      ),
      () => repository.removeMember(
        teamId: 'team-technical',
        userId: 'user-engineer-001',
        actorPermissions: const {},
      ),
      () => repository.archiveTeam(
        teamId: 'team-technical',
        actorPermissions: const {},
      ),
    ];

    for (final operation in operations) {
      await expectLater(operation, throwsStateError);
    }
    expect(await repository.getTeams(), hasLength(1));
    expect(await repository.getMemberships(), hasLength(1));
  });

  test('ekip adı trim ve büyük küçük harf farkıyla tekrar oluşturulamaz', () {
    final repository = FakeTeamRepository(delay: Duration.zero);

    expect(
      () => repository.createTeam(
        name: '  TEKNİK EKİP  ',
        description: '',
        actorPermissions: managerPermissions,
      ),
      throwsStateError,
    );
  });

  test('ekip başka ekibin normalize edilmiş adıyla güncellenemez', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);
    final secondTeam = await repository.createTeam(
      name: 'Gece Ekibi',
      description: '',
      actorPermissions: managerPermissions,
    );

    expect(
      () => repository.updateTeam(
        teamId: secondTeam.id,
        name: ' teknik ekip ',
        description: '',
        actorPermissions: managerPermissions,
      ),
      throwsStateError,
    );
  });

  test('ekip kendi mevcut adıyla güncellenebilir', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    final updated = await repository.updateTeam(
      teamId: 'team-technical',
      name: ' teknik ekip ',
      description: 'Yeni açıklama',
      actorPermissions: managerPermissions,
    );

    expect(updated.name, 'teknik ekip');
    expect(updated.description, 'Yeni açıklama');
  });

  test('arşivleme hard delete yapmaz', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);

    final archived = await repository.archiveTeam(
      teamId: 'team-technical',
      actorPermissions: managerPermissions,
    );

    expect(archived.isArchived, isTrue);
    expect(archived.isActive, isFalse);
    expect((await repository.getTeams()).single.id, 'team-technical');
    expect(await repository.getMemberships(), hasLength(1));
  });

  test('yetkisiz arşivleme reddedilir', () {
    final repository = FakeTeamRepository(delay: Duration.zero);

    expect(
      () => repository.archiveTeam(
        teamId: 'team-technical',
        actorPermissions: const {},
      ),
      throwsStateError,
    );
  });

  test('açık teknik işi bulunan ekip arşivlenemez', () {
    final repository = FakeTeamRepository(
      delay: Duration.zero,
      archiveGuard: const _FakeArchiveGuard(hasOpenWork: true),
    );

    expect(
      () => repository.archiveTeam(
        teamId: 'team-technical',
        actorPermissions: managerPermissions,
      ),
      throwsStateError,
    );
  });

  test('restore aynı kimlik, üyelik ve yetkileri pasif olarak korur', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);
    final before = (await repository.getTeams()).single;
    final membershipsBefore = await repository.getMemberships();
    await repository.archiveTeam(
      teamId: before.id,
      actorPermissions: managerPermissions,
    );

    final restored = await repository.restoreTeam(
      teamId: before.id,
      actorPermissions: managerPermissions,
    );

    expect(restored.id, before.id);
    expect(restored.permissions, before.permissions);
    expect(restored.isArchived, isFalse);
    expect(restored.isActive, isFalse);
    expect(await repository.getMemberships(), membershipsBefore);
  });

  test('yetkisiz restore reddedilir', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);
    await repository.archiveTeam(
      teamId: 'team-technical',
      actorPermissions: managerPermissions,
    );

    expect(
      () => repository.restoreTeam(
        teamId: 'team-technical',
        actorPermissions: const {},
      ),
      throwsStateError,
    );
  });

  test('arşivlenmemiş ekip restore edilemez', () {
    final repository = FakeTeamRepository(delay: Duration.zero);

    expect(
      () => repository.restoreTeam(
        teamId: 'team-technical',
        actorPermissions: managerPermissions,
      ),
      throwsStateError,
    );
  });

  test('arşivlenmiş ad çakışması typed hata olarak ayırt edilir', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);
    await repository.archiveTeam(
      teamId: 'team-technical',
      actorPermissions: managerPermissions,
    );

    expect(
      () => repository.createTeam(
        name: ' TEKNİK EKİP ',
        description: '',
        actorPermissions: managerPermissions,
      ),
      throwsA(
        isA<ArchivedTeamNameConflict>()
            .having((error) => error.teamId, 'teamId', 'team-technical')
            .having((error) => error.teamName, 'teamName', 'Teknik Ekip'),
      ),
    );
  });

  test('arşivlenmiş ekip restore dışındaki mutasyonlara kapalıdır', () async {
    final repository = FakeTeamRepository(delay: Duration.zero);
    final archived = await repository.archiveTeam(
      teamId: 'team-technical',
      actorPermissions: managerPermissions,
    );
    final operations = <Future<Object?> Function()>[
      () => repository.updateTeam(
        teamId: archived.id,
        name: 'Yeni Ad',
        description: '',
        actorPermissions: managerPermissions,
      ),
      () => repository.setTeamActive(
        teamId: archived.id,
        isActive: true,
        actorPermissions: managerPermissions,
      ),
      () => repository.addMember(
        teamId: archived.id,
        userId: 'user-driver-001',
        actorPermissions: managerPermissions,
      ),
      () => repository.removeMember(
        teamId: archived.id,
        userId: 'user-engineer-001',
        actorPermissions: managerPermissions,
      ),
      () => repository.updatePermissions(
        teamId: archived.id,
        permissions: const {},
        actorPermissions: managerPermissions,
      ),
    ];

    for (final operation in operations) {
      await expectLater(operation, throwsStateError);
    }
    final stillArchived = (await repository.getTeams()).single;
    expect(stillArchived.isArchived, isTrue);
    expect(stillArchived.isActive, isFalse);
    expect(await repository.getMemberships(), hasLength(1));

    final archivedAgain = await repository.archiveTeam(
      teamId: archived.id,
      actorPermissions: managerPermissions,
    );
    expect(archivedAgain.id, archived.id);
    expect(archivedAgain.isArchived, isTrue);
  });

  test('create legacy çakışmada non-archived kayda öncelik verir', () {
    const archived = Team(
      id: 'team-archived',
      name: 'Ortak Ekip',
      description: '',
      isActive: false,
      isArchived: true,
      permissions: {},
    );
    const active = Team(
      id: 'team-active',
      name: ' ortak ekip ',
      description: '',
      isActive: true,
      permissions: {},
    );
    final repository = FakeTeamRepository(
      teams: const [archived, active],
      memberships: const [],
      delay: Duration.zero,
    );

    expect(
      () => repository.createTeam(
        name: 'ORTAK EKİP',
        description: '',
        actorPermissions: managerPermissions,
      ),
      throwsStateError,
    );
  });

  test('restore başka non-archived ekiple isim çakışırsa reddedilir', () {
    const archived = Team(
      id: 'team-archived',
      name: 'Ortak Ekip',
      description: '',
      isActive: false,
      isArchived: true,
      permissions: {},
    );
    const passive = Team(
      id: 'team-passive',
      name: ' ortak ekip ',
      description: '',
      isActive: false,
      permissions: {},
    );
    final repository = FakeTeamRepository(
      teams: const [archived, passive],
      memberships: const [],
      delay: Duration.zero,
    );

    expect(
      () => repository.restoreTeam(
        teamId: archived.id,
        actorPermissions: managerPermissions,
      ),
      throwsStateError,
    );
  });
}

class _FakeArchiveGuard implements TeamArchiveGuard {
  final bool hasOpenWork;

  const _FakeArchiveGuard({required this.hasOpenWork});

  @override
  Future<bool> hasOpenTechnicalWork(String teamId) async => hasOpenWork;
}
