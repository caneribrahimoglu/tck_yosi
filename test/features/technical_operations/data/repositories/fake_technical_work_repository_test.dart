import 'dart:async';

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
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_technical_work_access_adapter.dart';
import 'package:tck_yosi/features/teams/domain/models/team.dart';
import 'package:tck_yosi/features/teams/domain/models/team_membership.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_start_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_actor_access.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';

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

  test('aktif ekip üyesi ekibe atanmış açık işi görür', () async {
    final teamRepository = FakeTeamRepository(delay: Duration.zero);
    final teamWork = testWorks[1].copyWith(
      status: TechnicalWorkStatus.assigned,
      assignedToTeamId: 'team-technical',
    );
    final repository = _createRepositoryWithTeamAccess(
      works: [teamWork],
      teamRepository: teamRepository,
    );

    final result = await repository.getAssignedWorks('user-engineer-001');

    expect(result, hasLength(1));
    expect(result.single.id, teamWork.id);
  });

  test('pasif üyelik üzerinden ekibe atanmış iş görünmez', () async {
    final teamRepository = FakeTeamRepository(
      teams: const [_technicalTeam],
      memberships: const [
        TeamMembership(
          id: 'membership-passive',
          teamId: 'team-technical',
          userId: 'user-engineer-001',
          isActive: false,
        ),
      ],
      delay: Duration.zero,
    );
    final repository = _createRepositoryWithTeamAccess(
      works: [_teamAssignedWork()],
      teamRepository: teamRepository,
    );

    expect(await repository.getAssignedWorks('user-engineer-001'), isEmpty);
  });

  test('pasif veya arşivli ekip üzerinden atanmış iş görünmez', () async {
    for (final team in [
      _technicalTeam.copyWith(isActive: false),
      _technicalTeam.copyWith(isArchived: true),
    ]) {
      final teamRepository = FakeTeamRepository(
        teams: [team],
        memberships: const [_technicalMembership],
        delay: Duration.zero,
      );
      final repository = _createRepositoryWithTeamAccess(
        works: [_teamAssignedWork()],
        teamRepository: teamRepository,
      );

      expect(await repository.getAssignedWorks('user-engineer-001'), isEmpty);
    }
  });

  test('doğrudan ve ekip yoluyla eşleşen iş yalnız bir kez görünür', () async {
    final work = _teamAssignedWork().copyWith(
      assignedToUserId: 'user-engineer-001',
    );
    final repository = _createRepositoryWithTeamAccess(works: [work]);

    final result = await repository.getAssignedWorks('user-engineer-001');

    expect(result.map((item) => item.id), [work.id]);
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
    'yetkili aktif ekip üyesi işi başlatır ve ekip atamasını korur',
    () async {
      final startedAt = DateTime(2026, 8, 16, 10, 30);
      final repository = _createRepositoryWithTeamAccess(
        works: [_teamAssignedWork()],
        now: () => startedAt,
      );

      final result = await repository.startWork(
        workId: 'work-team',
        actorUserId: 'user-engineer-001',
      );

      expect(result.status, TechnicalWorkStatus.inProgress);
      expect(result.assignedToTeamId, 'team-technical');
      expect(result.assignedToUserId, isNull);
      expect(result.startedByUserId, 'user-engineer-001');
      expect(identical(result.startedAt, startedAt), isTrue);
    },
  );

  test('doğrudan atanmış yetkili kullanıcı işi başlatabilir', () async {
    final directWork = _teamAssignedWork().copyWith(
      assignedToTeamId: null,
      assignedToUserId: 'user-engineer-001',
    );
    final repository = _createRepositoryWithTeamAccess(works: [directWork]);

    final result = await repository.startWork(
      workId: directWork.id,
      actorUserId: 'user-engineer-001',
    );

    expect(result.status, TechnicalWorkStatus.inProgress);
    expect(result.assignedToUserId, 'user-engineer-001');
  });

  test('üye olmayan veya yetkisiz kullanıcı işi başlatamaz', () async {
    final repository = _createRepositoryWithTeamAccess(
      works: [_teamAssignedWork()],
    );

    expect(
      () => repository.startWork(
        workId: 'work-team',
        actorUserId: 'user-driver-001',
      ),
      throwsA(isA<TechnicalWorkStartNotAllowedException>()),
    );
  });

  test(
    'yetkisiz istek kilit tutup yetkili isteği alreadyStarted yapamaz',
    () async {
      final accessSource = _CoordinatedAccessSource();
      final repository = FakeTechnicalWorkRepository(
        works: [_teamAssignedWork()],
        delay: Duration.zero,
        technicalWorkAccessSource: accessSource,
      );

      final unauthorizedStart = repository.startWork(
        workId: 'work-team',
        actorUserId: 'unauthorized-user',
      );
      await accessSource.unauthorizedCheckStarted.future;

      final authorizedResult = await repository.startWork(
        workId: 'work-team',
        actorUserId: 'user-engineer-001',
      );
      accessSource.releaseUnauthorizedCheck.complete();

      expect(authorizedResult.status, TechnicalWorkStatus.inProgress);
      await expectLater(
        unauthorizedStart,
        throwsA(isA<TechnicalWorkStartNotAllowedException>()),
      );
    },
  );

  test('yetkisiz aktör devam eden işte status bilgisi alamaz', () async {
    final work = _teamAssignedWork().copyWith(
      status: TechnicalWorkStatus.inProgress,
      startedByUserId: 'user-engineer-001',
      startedAt: DateTime(2026, 8, 16, 9),
    );
    final repository = FakeTechnicalWorkRepository(
      works: [work],
      delay: Duration.zero,
      technicalWorkAccessSource: const _AccessSourceWithoutStartPermission(),
    );

    expect(
      () => repository.startWork(
        workId: work.id,
        actorUserId: 'unauthorized-user',
      ),
      throwsA(isA<TechnicalWorkStartNotAllowedException>()),
    );
  });

  test('aktif üye etkin başlatma yetkisi yoksa işi başlatamaz', () async {
    final repository = FakeTechnicalWorkRepository(
      works: [_teamAssignedWork()],
      delay: Duration.zero,
      technicalWorkAccessSource: const _AccessSourceWithoutStartPermission(),
    );

    expect(
      () => repository.startWork(
        workId: 'work-team',
        actorUserId: 'user-engineer-001',
      ),
      throwsA(isA<TechnicalWorkStartNotAllowedException>()),
    );
  });

  test(
    'pasif üyelik işi başlatma yetkisi verse bile erişimi reddeder',
    () async {
      final teamRepository = FakeTeamRepository(
        teams: const [_technicalTeam],
        memberships: const [
          TeamMembership(
            id: 'membership-passive',
            teamId: 'team-technical',
            userId: 'user-engineer-001',
            isActive: false,
          ),
        ],
        delay: Duration.zero,
      );
      final repository = _createRepositoryWithTeamAccess(
        works: [_teamAssignedWork()],
        teamRepository: teamRepository,
      );

      expect(
        () => repository.startWork(
          workId: 'work-team',
          actorUserId: 'user-engineer-001',
        ),
        throwsA(isA<TechnicalWorkStartNotAllowedException>()),
      );
    },
  );

  test('pasif veya arşivli ekibin aktif üyesi işi başlatamaz', () async {
    for (final team in [
      _technicalTeam.copyWith(isActive: false),
      _technicalTeam.copyWith(isArchived: true),
    ]) {
      final teamRepository = FakeTeamRepository(
        teams: [team],
        memberships: const [_technicalMembership],
        delay: Duration.zero,
      );
      final repository = _createRepositoryWithTeamAccess(
        works: [_teamAssignedWork()],
        teamRepository: teamRepository,
      );

      expect(
        () => repository.startWork(
          workId: 'work-team',
          actorUserId: 'user-engineer-001',
        ),
        throwsA(isA<TechnicalWorkStartNotAllowedException>()),
      );
    }
  });

  test('zaten başlatılmış iş typed hata verir ve metadata değişmez', () async {
    final originalStartedAt = DateTime(2026, 8, 15, 9);
    final work = _teamAssignedWork().copyWith(
      status: TechnicalWorkStatus.inProgress,
      startedByUserId: 'user-engineer-001',
      startedAt: originalStartedAt,
    );
    final repository = _createRepositoryWithTeamAccess(works: [work]);

    expect(
      () => repository.startWork(
        workId: work.id,
        actorUserId: 'user-engineer-001',
      ),
      throwsA(isA<TechnicalWorkAlreadyStartedException>()),
    );
    final unchanged = (await repository.getAllWorks()).single;
    expect(unchanged.startedByUserId, 'user-engineer-001');
    expect(identical(unchanged.startedAt, originalStartedAt), isTrue);
  });

  test('eşzamanlı iki start çağrısından yalnız biri başarılı olur', () async {
    final repository = _createRepositoryWithTeamAccess(
      works: [_teamAssignedWork()],
      delay: const Duration(milliseconds: 20),
    );

    Future<Object> start() async {
      try {
        return await repository.startWork(
          workId: 'work-team',
          actorUserId: 'user-engineer-001',
        );
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([start(), start()]);

    expect(results.whereType<TechnicalWork>(), hasLength(1));
    expect(
      results.whereType<TechnicalWorkAlreadyStartedException>(),
      hasLength(1),
    );
    final stored = (await repository.getAllWorks()).single;
    expect(stored.status, TechnicalWorkStatus.inProgress);
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

const _technicalTeam = Team(
  id: 'team-technical',
  name: 'Teknik Ekip',
  description: '',
  isActive: true,
  permissions: {AppPermission.startTechnicalWork},
);

const _technicalMembership = TeamMembership(
  id: 'membership-technical',
  teamId: 'team-technical',
  userId: 'user-engineer-001',
);

TechnicalWork _teamAssignedWork() => TechnicalWork(
  id: 'work-team',
  title: 'Ekip işi',
  description: 'Teknik ekip tarafından yürütülecek iş.',
  location: 'D-100 / Km 30+000',
  category: TechnicalWorkCategory.lighting,
  priority: TechnicalWorkPriority.high,
  status: TechnicalWorkStatus.assigned,
  createdByUserId: 'user-chief-001',
  assignedToTeamId: 'team-technical',
  createdAt: DateTime(2026, 8, 16),
);

FakeTechnicalWorkRepository _createRepositoryWithTeamAccess({
  required List<TechnicalWork> works,
  FakeTeamRepository? teamRepository,
  Duration delay = Duration.zero,
  DateTime Function()? now,
}) {
  final teams = teamRepository ?? FakeTeamRepository(delay: Duration.zero);
  return FakeTechnicalWorkRepository(
    works: works,
    delay: delay,
    now: now,
    technicalWorkAccessSource: TeamTechnicalWorkAccessAdapter(
      teamRepository: teams,
      userDirectory: FakeAuthService(),
    ),
  );
}

class _AccessSourceWithoutStartPermission implements TechnicalWorkAccessSource {
  const _AccessSourceWithoutStartPermission();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    return const TechnicalWorkActorAccess(
      activeTeamIds: {'team-technical'},
      canStartTechnicalWork: false,
    );
  }
}

class _CoordinatedAccessSource implements TechnicalWorkAccessSource {
  final unauthorizedCheckStarted = Completer<void>();
  final releaseUnauthorizedCheck = Completer<void>();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    if (userId == 'unauthorized-user') {
      unauthorizedCheckStarted.complete();
      await releaseUnauthorizedCheck.future;
      return const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
      );
    }
    return const TechnicalWorkActorAccess(
      activeTeamIds: {'team-technical'},
      canStartTechnicalWork: true,
    );
  }
}
