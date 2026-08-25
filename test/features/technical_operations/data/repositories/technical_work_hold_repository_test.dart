import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_technical_work_access_adapter.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_completion_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_hold_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_progress_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/add_technical_work_progress_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/put_technical_work_on_hold_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/submit_technical_work_completion_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_actor_access.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';

void main() {
  test(
    'doğrudan atanmış yetkili kullanıcı işi bekletip devam ettirir',
    () async {
      final repository = _repository();

      final held = await repository.putWorkOnHold(
        request: const PutTechnicalWorkOnHoldRequest(
          workId: 'work-hold',
          reason: '  Yedek parça bekleniyor. ',
        ),
        actorUserId: 'direct-user',
      );
      final onHoldWork = await repository.getWorkById(
        workId: 'work-hold',
        actorUserId: 'direct-user',
      );

      expect(held.reason, 'Yedek parça bekleniyor.');
      expect(onHoldWork.status, TechnicalWorkStatus.onHold);
      expect(onHoldWork.assignedToUserId, 'direct-user');
      expect(onHoldWork.startedByUserId, 'starter-user');
      expect(onHoldWork.startedAt, DateTime(2026, 8, 20, 9));

      final resumed = await repository.resumeWork(
        workId: 'work-hold',
        actorUserId: 'direct-user',
      );
      final resumedWork = await repository.getWorkById(
        workId: 'work-hold',
        actorUserId: 'direct-user',
      );
      expect(resumed.resumedByUserId, 'direct-user');
      expect(resumed.resumedAt, isNotNull);
      expect(resumedWork.status, TechnicalWorkStatus.inProgress);
      expect(resumedWork.startedByUserId, 'starter-user');
      expect(resumedWork.startedAt, DateTime(2026, 8, 20, 9));
    },
  );

  test(
    'aktif ekip üyesi devredilmiş yetkiyle bekletip devam ettirir',
    () async {
      final teamRepository = FakeTeamRepository(delay: Duration.zero);
      final repository = FakeTechnicalWorkRepository(
        works: [
          _work(assignedToUserId: null, assignedToTeamId: 'team-technical'),
        ],
        delay: Duration.zero,
        technicalWorkAccessSource: TeamTechnicalWorkAccessAdapter(
          teamRepository: teamRepository,
          userDirectory: FakeAuthService(),
        ),
      );

      await repository.putWorkOnHold(
        request: const PutTechnicalWorkOnHoldRequest(
          workId: 'work-hold',
          reason: 'Saha güvenliği sağlanıyor.',
        ),
        actorUserId: 'user-engineer-001',
      );
      await repository.resumeWork(
        workId: 'work-hold',
        actorUserId: 'user-engineer-001',
      );

      final work = await repository.getWorkById(
        workId: 'work-hold',
        actorUserId: 'user-engineer-001',
      );
      expect(work.status, TechnicalWorkStatus.inProgress);
      expect(work.assignedToTeamId, 'team-technical');
    },
  );

  test('boş bekleme nedeni typed hata verir', () async {
    final repository = _repository();
    await expectLater(
      repository.putWorkOnHold(
        request: const PutTechnicalWorkOnHoldRequest(
          workId: 'work-hold',
          reason: '   ',
        ),
        actorUserId: 'direct-user',
      ),
      throwsA(isA<TechnicalWorkHoldInvalidInputException>()),
    );
  });

  test(
    'yetkisiz, atanmamış ve pasif aktör state bilgisini öğrenemez',
    () async {
      for (final actor in ['without-permission', 'unassigned', 'inactive']) {
        final repository = _repository();
        await expectLater(
          repository.putWorkOnHold(
            request: const PutTechnicalWorkOnHoldRequest(
              workId: 'work-hold',
              reason: 'Neden',
            ),
            actorUserId: actor,
          ),
          throwsA(isA<TechnicalWorkHoldNotAllowedException>()),
        );
      }
    },
  );

  test('pasif veya arşivli ekip üzerinden mutasyon reddedilir', () async {
    const manager = {AppPermission.manageTeamPermissions};
    for (final archive in [false, true]) {
      final teams = FakeTeamRepository(delay: Duration.zero);
      if (archive) {
        await teams.archiveTeam(
          teamId: 'team-technical',
          actorPermissions: manager,
        );
      } else {
        await teams.setTeamActive(
          teamId: 'team-technical',
          isActive: false,
          actorPermissions: manager,
        );
      }
      final repository = FakeTechnicalWorkRepository(
        works: [
          _work(assignedToUserId: null, assignedToTeamId: 'team-technical'),
        ],
        delay: Duration.zero,
        technicalWorkAccessSource: TeamTechnicalWorkAccessAdapter(
          teamRepository: teams,
          userDirectory: FakeAuthService(),
        ),
      );
      await expectLater(
        repository.putWorkOnHold(
          request: const PutTechnicalWorkOnHoldRequest(
            workId: 'work-hold',
            reason: 'Neden',
          ),
          actorUserId: 'user-engineer-001',
        ),
        throwsA(isA<TechnicalWorkHoldNotAllowedException>()),
      );
    }
  });

  test(
    'yalnız inProgress bekletilir ve yalnız onHold devam ettirilir',
    () async {
      for (final status in TechnicalWorkStatus.values.where(
        (status) => status != TechnicalWorkStatus.inProgress,
      )) {
        final repository = _repository(work: _work(status: status));
        await expectLater(
          repository.putWorkOnHold(
            request: const PutTechnicalWorkOnHoldRequest(
              workId: 'work-hold',
              reason: 'Neden',
            ),
            actorUserId: 'direct-user',
          ),
          throwsA(isA<TechnicalWorkHoldInvalidStateException>()),
        );
      }
      final repository = _repository();
      await expectLater(
        repository.resumeWork(workId: 'work-hold', actorUserId: 'direct-user'),
        throwsA(isA<TechnicalWorkHoldInvalidStateException>()),
      );
    },
  );

  test(
    'onHold iken progress ve completion request repositoryde engellenir',
    () async {
      final repository = _repository();
      await repository.putWorkOnHold(
        request: const PutTechnicalWorkOnHoldRequest(
          workId: 'work-hold',
          reason: 'Parça bekleniyor.',
        ),
        actorUserId: 'direct-user',
      );

      await expectLater(
        repository.addProgressNote(
          request: const AddTechnicalWorkProgressRequest(
            workId: 'work-hold',
            content: 'Not',
          ),
          actorUserId: 'direct-user',
        ),
        throwsA(isA<TechnicalWorkProgressInvalidStateException>()),
      );
      await expectLater(
        repository.submitCompletionRequest(
          request: const SubmitTechnicalWorkCompletionRequest(
            workId: 'work-hold',
            summary: 'Tamamlandı.',
          ),
          actorUserId: 'direct-user',
        ),
        throwsA(isA<TechnicalWorkCompletionInvalidStateException>()),
      );
    },
  );

  test(
    'geçmiş immutable kalır ve ikinci çevrim yeni kayıt oluşturur',
    () async {
      final repository = _repository();
      await repository.putWorkOnHold(
        request: const PutTechnicalWorkOnHoldRequest(
          workId: 'work-hold',
          reason: 'Birinci neden',
        ),
        actorUserId: 'direct-user',
      );
      await repository.resumeWork(
        workId: 'work-hold',
        actorUserId: 'direct-user',
      );
      await repository.putWorkOnHold(
        request: const PutTechnicalWorkOnHoldRequest(
          workId: 'work-hold',
          reason: 'İkinci neden',
        ),
        actorUserId: 'direct-user',
      );

      final history = await repository.getHoldHistory(
        workId: 'work-hold',
        actorUserId: 'direct-user',
      );
      expect(history, hasLength(2));
      expect(history.first.reason, 'Birinci neden');
      expect(history.first.isResumed, isTrue);
      expect(history.last.reason, 'İkinci neden');
      expect(history.last.isResumed, isFalse);
      expect(() => history.add(history.first), throwsUnsupportedError);
    },
  );

  test('eşzamanlı iki hold yalnız bir geçiş ve kayıt üretir', () async {
    final repository = _repository();
    const request = PutTechnicalWorkOnHoldRequest(
      workId: 'work-hold',
      reason: 'Neden',
    );
    final outcomes = await Future.wait<Object>([
      repository
          .putWorkOnHold(request: request, actorUserId: 'direct-user')
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      repository
          .putWorkOnHold(request: request, actorUserId: 'direct-user')
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);
    expect(outcomes.where((value) => value is! Exception), hasLength(1));
    expect(
      await repository.getHoldHistory(
        workId: 'work-hold',
        actorUserId: 'direct-user',
      ),
      hasLength(1),
    );
  });

  test('eşzamanlı iki resume yalnız bir geçiş üretir', () async {
    final repository = _repository();
    await repository.putWorkOnHold(
      request: const PutTechnicalWorkOnHoldRequest(
        workId: 'work-hold',
        reason: 'Neden',
      ),
      actorUserId: 'direct-user',
    );
    final outcomes = await Future.wait<Object>([
      repository
          .resumeWork(workId: 'work-hold', actorUserId: 'direct-user')
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      repository
          .resumeWork(workId: 'work-hold', actorUserId: 'direct-user')
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);
    expect(outcomes.where((value) => value is! Exception), hasLength(1));
  });

  test(
    'hold ve resume yarışında yalnız mevcut durumun geçişi kazanır',
    () async {
      final repository = _repository();
      final outcomes = await Future.wait<Object>([
        repository
            .putWorkOnHold(
              request: const PutTechnicalWorkOnHoldRequest(
                workId: 'work-hold',
                reason: 'Neden',
              ),
              actorUserId: 'direct-user',
            )
            .then<Object>((value) => value)
            .catchError((Object error) => error),
        repository
            .resumeWork(workId: 'work-hold', actorUserId: 'direct-user')
            .then<Object>((value) => value)
            .catchError((Object error) => error),
      ]);
      expect(outcomes.where((value) => value is! Exception), hasLength(1));
      final work = await repository.getWorkById(
        workId: 'work-hold',
        actorUserId: 'direct-user',
      );
      expect(work.status, TechnicalWorkStatus.onHold);
    },
  );
}

FakeTechnicalWorkRepository _repository({TechnicalWork? work}) {
  var minute = 0;
  return FakeTechnicalWorkRepository(
    works: [work ?? _work()],
    delay: Duration.zero,
    technicalWorkAccessSource: const _HoldAccessSource(),
    now: () => DateTime(2026, 8, 25, 10, minute++),
  );
}

TechnicalWork _work({
  TechnicalWorkStatus status = TechnicalWorkStatus.inProgress,
  String? assignedToUserId = 'direct-user',
  String? assignedToTeamId,
}) {
  return TechnicalWork(
    id: 'work-hold',
    title: 'Teknik iş',
    description: 'Açıklama',
    location: 'D-100',
    category: TechnicalWorkCategory.lighting,
    priority: TechnicalWorkPriority.high,
    status: status,
    createdByUserId: 'creator-user',
    assignedToUserId: assignedToUserId,
    assignedToTeamId: assignedToTeamId,
    createdAt: DateTime(2026, 8, 20, 8),
    startedByUserId: 'starter-user',
    startedAt: DateTime(2026, 8, 20, 9),
  );
}

class _HoldAccessSource implements TechnicalWorkAccessSource {
  const _HoldAccessSource();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    return switch (userId) {
      'direct-user' => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canAddTechnicalWorkProgress: true,
        canRequestTechnicalWorkCompletion: true,
        canPauseTechnicalWork: true,
        canResumeTechnicalWork: true,
      ),
      'team-user' => const TechnicalWorkActorAccess(
        activeTeamIds: {'active-team'},
        canStartTechnicalWork: false,
        canPauseTechnicalWork: true,
        canResumeTechnicalWork: true,
      ),
      'inactive' => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canPauseTechnicalWork: true,
        canResumeTechnicalWork: true,
        isActive: false,
      ),
      'unassigned' => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canPauseTechnicalWork: true,
        canResumeTechnicalWork: true,
      ),
      _ => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
      ),
    };
  }
}
