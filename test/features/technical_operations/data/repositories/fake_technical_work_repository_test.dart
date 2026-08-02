import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/create_field_report_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/assignment_target.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/assignment_target_type.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_assignment_target_adapter.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/technical_operations/data/adapters/technical_work_team_archive_guard.dart';

void main() {
  final testWorks = [
    TechnicalWork(
      id: 'work-001',
      title: 'Aydınlatma arızası',
      description: 'Aydınlatma sistemi çalışmıyor.',
      location: 'D-100 / Km 10+000',
      category: TechnicalWorkCategory.lighting,
      priority: TechnicalWorkPriority.critical,
      status: TechnicalWorkStatus.assigned,
      createdByUserId: 'user-chief-001',
      assignedToUserId: 'engineer-001',
      createdAt: DateTime(2026, 7, 19),
    ),
    TechnicalWork(
      id: 'work-002',
      title: 'Hasarlı tabela',
      description: 'Yön tabelası hasarlı.',
      location: 'D-100 / Km 20+000',
      category: TechnicalWorkCategory.trafficSign,
      priority: TechnicalWorkPriority.high,
      status: TechnicalWorkStatus.reported,
      createdByUserId: 'user-driver-001',
      createdAt: DateTime(2026, 7, 19),
    ),
  ];

  test('bütün teknik işleri getirir', () async {
    final repository = FakeTechnicalWorkRepository(
      works: testWorks,
      delay: Duration.zero,
    );

    final result = await repository.getAllWorks();

    expect(result, hasLength(2));
    expect(result.first.title, 'Aydınlatma arızası');
  });

  test('yalnızca kullanıcıya atanmış işleri getirir', () async {
    final repository = FakeTechnicalWorkRepository(
      works: testWorks,
      delay: Duration.zero,
    );

    final result = await repository.getAssignedWorks('engineer-001');

    expect(result, hasLength(1));
    expect(result.single.id, 'work-001');
  });

  test('atanmış işi olmayan kullanıcı için boş liste döndürür', () async {
    final repository = FakeTechnicalWorkRepository(
      works: testWorks,
      delay: Duration.zero,
    );

    final result = await repository.getAssignedWorks('engineer-without-work');

    expect(result, isEmpty);
  });

  test('yeni bir saha raporu oluşturur', () async {
    final repository = FakeTechnicalWorkRepository(
      works: [],
      delay: Duration.zero,
    );
    final request = CreateFieldReportRequest(
      title: 'Yeni Arıza',
      description: 'Detaylı açıklama',
      location: 'D-100 / Km 50+000',
      category: TechnicalWorkCategory.lighting,
    );

    final result = await repository.createFieldReport(
      request: request,
      createdByUserId: 'user-001',
    );

    expect(result.title, 'Yeni Arıza');
    expect(result.createdByUserId, 'user-001');
    expect(result.category, TechnicalWorkCategory.lighting);
    expect(result.status, TechnicalWorkStatus.reported);
    expect(result.priority, TechnicalWorkPriority.normal);
    expect(result.assignedToUserId, isNull);

    final allWorks = await repository.getAllWorks();

    expect(allWorks, hasLength(1));
    expect(allWorks.single.id, result.id);
  });

  test('bildirimin önceliğini belirler ve mühendise atar', () async {
    final repository = FakeTechnicalWorkRepository(
      works: testWorks,
      delay: Duration.zero,
    );
    const engineer = AssignmentTarget(
      id: 'engineer-002',
      name: 'Test Mühendis',
      type: AssignmentTargetType.engineer,
    );

    final result = await repository.assignWork(
      workId: 'work-002',
      priority: TechnicalWorkPriority.critical,
      target: engineer,
    );

    expect(result.priority, TechnicalWorkPriority.critical);
    expect(result.status, TechnicalWorkStatus.assigned);
    expect(result.assignedToUserId, engineer.id);
    expect(result.assignedToTeamId, isNull);
  });

  test('bildirimi ekibe atar', () async {
    final repository = FakeTechnicalWorkRepository(
      works: testWorks,
      delay: Duration.zero,
    );
    const team = AssignmentTarget(
      id: 'team-001',
      name: 'Test Ekibi',
      type: AssignmentTargetType.team,
    );

    final result = await repository.assignWork(
      workId: 'work-001',
      priority: TechnicalWorkPriority.high,
      target: team,
    );

    expect(result.assignedToTeamId, team.id);
    expect(result.assignedToUserId, isNull);
  });

  test(
    'ekibe atanmış bildirimi mühendise yeniden atarken ekibi temizler',
    () async {
      final teamAssignedWork = testWorks[1].copyWith(
        assignedToTeamId: 'team-001',
      );
      final repository = FakeTechnicalWorkRepository(
        works: [teamAssignedWork],
        delay: Duration.zero,
      );
      const engineer = AssignmentTarget(
        id: 'engineer-002',
        name: 'Test Mühendis',
        type: AssignmentTargetType.engineer,
      );

      final result = await repository.assignWork(
        workId: teamAssignedWork.id,
        priority: TechnicalWorkPriority.normal,
        target: engineer,
      );

      expect(result.assignedToUserId, engineer.id);
      expect(result.assignedToTeamId, isNull);
    },
  );

  test('yeni oluşturulan aktif ekip atama hedeflerinde görünür', () async {
    final teamRepository = FakeTeamRepository(delay: Duration.zero);
    final team = await teamRepository.createTeam(
      name: 'Yeni Müdahale Ekibi',
      description: '',
      actorPermissions: const {AppPermission.manageTeamPermissions},
    );
    final repository = FakeTechnicalWorkRepository(
      works: [],
      delay: Duration.zero,
      teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
        repository: teamRepository,
      ),
    );

    final targets = await repository.getAssignmentTargets();

    expect(targets.any((target) => target.id == team.id), isTrue);
  });

  test('pasif ve arşivlenmiş ekipler atama hedeflerinde görünmez', () async {
    const manager = {AppPermission.manageTeamPermissions};
    final teamRepository = FakeTeamRepository(delay: Duration.zero);
    final passive = await teamRepository.createTeam(
      name: 'Pasif Ekip',
      description: '',
      actorPermissions: manager,
    );
    final archived = await teamRepository.createTeam(
      name: 'Arşiv Ekip',
      description: '',
      actorPermissions: manager,
    );
    await teamRepository.setTeamActive(
      teamId: passive.id,
      isActive: false,
      actorPermissions: manager,
    );
    await teamRepository.archiveTeam(
      teamId: archived.id,
      actorPermissions: manager,
    );
    final repository = FakeTechnicalWorkRepository(
      works: [],
      delay: Duration.zero,
      teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
        repository: teamRepository,
      ),
    );

    final targets = await repository.getAssignmentTargets();

    expect(targets.any((target) => target.id == passive.id), isFalse);
    expect(targets.any((target) => target.id == archived.id), isFalse);
    expect(targets.any((target) => target.id == 'team-technical'), isTrue);
  });

  test('arşivleme geçmiş teknik işin ekip kimliğini korur', () async {
    const manager = {AppPermission.manageTeamPermissions};
    final historicalWork = testWorks[1].copyWith(
      status: TechnicalWorkStatus.completed,
      assignedToTeamId: 'team-technical',
    );
    late final FakeTechnicalWorkRepository technicalRepository;
    final teamRepository = FakeTeamRepository(
      delay: Duration.zero,
      archiveGuard: TechnicalWorkTeamArchiveGuard(
        repositoryProvider: () => technicalRepository,
      ),
    );
    technicalRepository = FakeTechnicalWorkRepository(
      works: [historicalWork],
      delay: Duration.zero,
    );

    await teamRepository.archiveTeam(
      teamId: 'team-technical',
      actorPermissions: manager,
    );

    expect(
      (await technicalRepository.getAllWorks()).single.assignedToTeamId,
      'team-technical',
    );
  });

  test('gerçek teknik iş guardı açık işi olan ekibi korur', () async {
    const manager = {AppPermission.manageTeamPermissions};
    final openWork = testWorks[1].copyWith(assignedToTeamId: 'team-technical');
    late final FakeTechnicalWorkRepository technicalRepository;
    final teamRepository = FakeTeamRepository(
      delay: Duration.zero,
      archiveGuard: TechnicalWorkTeamArchiveGuard(
        repositoryProvider: () => technicalRepository,
      ),
    );
    technicalRepository = FakeTechnicalWorkRepository(
      works: [openWork],
      delay: Duration.zero,
    );

    expect(
      () => teamRepository.archiveTeam(
        teamId: 'team-technical',
        actorPermissions: manager,
      ),
      throwsStateError,
    );
  });

  test(
    'restore edilen pasif ekip aktifleştirilene kadar hedef olmaz',
    () async {
      const manager = {AppPermission.manageTeamPermissions};
      final teamRepository = FakeTeamRepository(delay: Duration.zero);
      final repository = FakeTechnicalWorkRepository(
        works: [],
        delay: Duration.zero,
        teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
          repository: teamRepository,
        ),
      );
      await teamRepository.archiveTeam(
        teamId: 'team-technical',
        actorPermissions: manager,
      );
      await teamRepository.restoreTeam(
        teamId: 'team-technical',
        actorPermissions: manager,
      );

      expect(
        (await repository.getAssignmentTargets()).any(
          (target) => target.id == 'team-technical',
        ),
        isFalse,
      );

      await teamRepository.setTeamActive(
        teamId: 'team-technical',
        isActive: true,
        actorPermissions: manager,
      );
      expect(
        (await repository.getAssignmentTargets()).any(
          (target) => target.id == 'team-technical',
        ),
        isTrue,
      );
    },
  );
}
