import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_completion_decision.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_completion_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/submit_technical_work_completion_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_actor_access.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_technical_work_access_adapter.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';

void main() {
  const directUser = 'direct-user';
  const teamUser = 'team-user';
  const reviewer = 'reviewer';
  final nowValues = <DateTime>[
    DateTime(2026, 8, 16, 10),
    DateTime(2026, 8, 16, 11),
    DateTime(2026, 8, 16, 12),
  ];

  FakeTechnicalWorkRepository createRepository({
    TechnicalWork? work,
    Duration delay = Duration.zero,
  }) {
    var nowIndex = 0;
    return FakeTechnicalWorkRepository(
      works: [work ?? _work(assignedToUserId: directUser)],
      delay: delay,
      now: () => nowValues[nowIndex++],
      technicalWorkAccessSource: const _CompletionAccessSource(),
    );
  }

  test(
    'doğrudan atanmış yetkili kullanıcı talep oluşturur ve geçmiş korunur',
    () async {
      final repository = createRepository();

      final request = await repository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-completion',
          summary: '  Çalışma tamamlandı.  ',
        ),
        actorUserId: directUser,
      );

      expect(request.summary, 'Çalışma tamamlandı.');
      expect(request.requestedAt, nowValues.first);
      final work = await repository.getWorkById(
        workId: 'work-completion',
        actorUserId: directUser,
      );
      expect(work.status, TechnicalWorkStatus.awaitingCompletionApproval);
      expect(work.assignedToUserId, directUser);
      final history = await repository.getCompletionRequests(
        workId: work.id,
        actorUserId: directUser,
      );
      expect(history, [same(request)]);
      expect(() => history.add(request), throwsUnsupportedError);
    },
  );

  test('aktif ekip üyesi ekibe atanmış iş için talep oluşturur', () async {
    final repository = createRepository(
      work: _work(assignedToTeamId: 'active-team'),
    );

    final request = await repository.submitCompletionRequest(
      request: const SubmitTechnicalWorkCompletionRequest(
        workId: 'work-completion',
        summary: 'Ekip çalışması tamamlandı.',
      ),
      actorUserId: teamUser,
    );

    final work = await repository.getWorkById(
      workId: request.workId,
      actorUserId: teamUser,
    );
    expect(work.assignedToTeamId, 'active-team');
    expect(work.status, TechnicalWorkStatus.awaitingCompletionApproval);
  });

  test('ilgisiz, pasif veya yetkisiz kullanıcı talep gönderemez', () async {
    for (final actor in ['unrelated', 'passive', 'without-permission']) {
      final repository = createRepository();
      await expectLater(
        repository.submitCompletionRequest(
          request: const SubmitTechnicalWorkCompletionRequest(
            workId: 'work-completion',
            summary: 'Tamamlandı.',
          ),
          actorUserId: actor,
        ),
        throwsA(isA<TechnicalWorkCompletionNotAllowedException>()),
      );
    }
  });

  test('pasif ekip üyeliği üzerinden talep gönderilemez', () async {
    final repository = createRepository(
      work: _work(assignedToTeamId: 'passive-team'),
    );

    await expectLater(
      repository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-completion',
          summary: 'Tamamlandı.',
        ),
        actorUserId: teamUser,
      ),
      throwsA(isA<TechnicalWorkCompletionNotAllowedException>()),
    );
  });

  test(
    'pasif veya arşivlenmiş gerçek ekip üzerinden talep gönderilemez',
    () async {
      const managerPermissions = {AppPermission.manageTeamPermissions};
      for (final archive in [false, true]) {
        final teamRepository = FakeTeamRepository(delay: Duration.zero);
        if (archive) {
          await teamRepository.archiveTeam(
            teamId: 'team-technical',
            actorPermissions: managerPermissions,
          );
        } else {
          await teamRepository.setTeamActive(
            teamId: 'team-technical',
            isActive: false,
            actorPermissions: managerPermissions,
          );
        }
        final repository = FakeTechnicalWorkRepository(
          works: [_work(assignedToTeamId: 'team-technical')],
          delay: Duration.zero,
          technicalWorkAccessSource: TeamTechnicalWorkAccessAdapter(
            teamRepository: teamRepository,
            userDirectory: FakeAuthService(),
          ),
        );

        await expectLater(
          repository.submitCompletionRequest(
            request: const SubmitTechnicalWorkCompletionRequest(
              workId: 'work-completion',
              summary: 'Tamamlandı.',
            ),
            actorUserId: 'user-engineer-001',
          ),
          throwsA(isA<TechnicalWorkCompletionNotAllowedException>()),
        );
      }
    },
  );

  test('boş özet ve yanlış iş durumu typed hata verir', () async {
    final repository = createRepository();
    await expectLater(
      repository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-completion',
          summary: '   ',
        ),
        actorUserId: directUser,
      ),
      throwsA(isA<TechnicalWorkCompletionInvalidInputException>()),
    );
    final assignedRepository = createRepository(
      work: _work(
        assignedToUserId: directUser,
        status: TechnicalWorkStatus.assigned,
      ),
    );
    await expectLater(
      assignedRepository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-completion',
          summary: 'Tamamlandı.',
        ),
        actorUserId: directUser,
      ),
      throwsA(isA<TechnicalWorkCompletionInvalidStateException>()),
    );
  });

  test('eşzamanlı iki talep yalnız bir geçmiş kaydı oluşturur', () async {
    final repository = createRepository();
    const input = SubmitTechnicalWorkCompletionRequest(
      workId: 'work-completion',
      summary: 'Tamamlandı.',
    );

    final results = await Future.wait<Object>([
      repository
          .submitCompletionRequest(request: input, actorUserId: directUser)
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      repository
          .submitCompletionRequest(request: input, actorUserId: directUser)
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);

    expect(results.where((result) => result is! Exception), hasLength(1));
    final history = await repository.getCompletionRequests(
      workId: 'work-completion',
      actorUserId: directUser,
    );
    expect(history, hasLength(1));
  });

  test(
    'yetkili reviewer onaylar; metadata ve tamamlanma zamanı kaydedilir',
    () async {
      final repository = createRepository();
      final request = await repository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-completion',
          summary: 'Tamamlandı.',
        ),
        actorUserId: directUser,
      );

      final decided = await repository.approveCompletionRequest(
        requestId: request.id,
        actorUserId: reviewer,
      );

      expect(decided.decision, TechnicalWorkCompletionDecision.approved);
      expect(decided.reviewedByUserId, reviewer);
      expect(decided.reviewedAt, nowValues[1]);
      final work = await repository.getWorkById(
        workId: request.workId,
        actorUserId: reviewer,
      );
      expect(work.status, TechnicalWorkStatus.completed);
      expect(work.completedAt, nowValues[1]);
    },
  );

  test(
    'ret nedeni zorunludur ve ret işi geçmişi silmeden devam ettirir',
    () async {
      final repository = createRepository();
      final request = await repository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-completion',
          summary: 'Tamamlandı.',
        ),
        actorUserId: directUser,
      );
      await expectLater(
        repository.rejectCompletionRequest(
          requestId: request.id,
          actorUserId: reviewer,
          rejectionReason: ' ',
        ),
        throwsA(isA<TechnicalWorkCompletionInvalidInputException>()),
      );

      final rejected = await repository.rejectCompletionRequest(
        requestId: request.id,
        actorUserId: reviewer,
        rejectionReason: '  Son kontrol eksik. ',
      );

      expect(rejected.decision, TechnicalWorkCompletionDecision.rejected);
      expect(rejected.rejectionReason, 'Son kontrol eksik.');
      final work = await repository.getWorkById(
        workId: request.workId,
        actorUserId: directUser,
      );
      expect(work.status, TechnicalWorkStatus.inProgress);
      expect(
        await repository.getCompletionRequests(
          workId: work.id,
          actorUserId: directUser,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'review yetkisi olmayan kullanıcı pending listeyi ve kararı göremez',
    () async {
      final repository = createRepository();
      final request = await repository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-completion',
          summary: 'Tamamlandı.',
        ),
        actorUserId: directUser,
      );
      await expectLater(
        repository.getPendingCompletionReviews(actorUserId: directUser),
        throwsA(isA<TechnicalWorkCompletionReviewNotAllowedException>()),
      );
      await expectLater(
        repository.approveCompletionRequest(
          requestId: request.id,
          actorUserId: directUser,
        ),
        throwsA(isA<TechnicalWorkCompletionReviewNotAllowedException>()),
      );
    },
  );

  test(
    'approve ve reject yarışında yalnız tek terminal karar oluşur',
    () async {
      final repository = createRepository();
      final request = await repository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-completion',
          summary: 'Tamamlandı.',
        ),
        actorUserId: directUser,
      );

      final outcomes = await Future.wait<Object>([
        repository
            .approveCompletionRequest(
              requestId: request.id,
              actorUserId: reviewer,
            )
            .then<Object>((value) => value)
            .catchError((Object error) => error),
        repository
            .rejectCompletionRequest(
              requestId: request.id,
              actorUserId: reviewer,
              rejectionReason: 'Eksik.',
            )
            .then<Object>((value) => value)
            .catchError((Object error) => error),
      ]);

      expect(
        outcomes.whereType<TechnicalWorkCompletionAlreadyDecidedException>(),
        hasLength(1),
      );
      final history = await repository.getCompletionRequests(
        workId: request.workId,
        actorUserId: reviewer,
      );
      expect(history, hasLength(1));
      expect(
        history.single.decision,
        isNot(TechnicalWorkCompletionDecision.pending),
      );
    },
  );
}

TechnicalWork _work({
  String? assignedToUserId,
  String? assignedToTeamId,
  TechnicalWorkStatus status = TechnicalWorkStatus.inProgress,
}) {
  return TechnicalWork(
    id: 'work-completion',
    title: 'Aydınlatma onarımı',
    description: 'Armatürler yenilendi.',
    location: 'D-100 / Km 10+000',
    category: TechnicalWorkCategory.lighting,
    priority: TechnicalWorkPriority.high,
    status: status,
    createdByUserId: 'creator',
    assignedToUserId: assignedToUserId,
    assignedToTeamId: assignedToTeamId,
    createdAt: DateTime(2026, 8, 15),
  );
}

class _CompletionAccessSource implements TechnicalWorkAccessSource {
  const _CompletionAccessSource();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    return switch (userId) {
      'direct-user' => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canRequestTechnicalWorkCompletion: true,
      ),
      'team-user' => const TechnicalWorkActorAccess(
        activeTeamIds: {'active-team'},
        canStartTechnicalWork: false,
        canRequestTechnicalWorkCompletion: true,
      ),
      'reviewer' => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canReviewTechnicalWorkCompletion: true,
        canViewAllTechnicalWork: true,
      ),
      'passive' => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canRequestTechnicalWorkCompletion: true,
        isActive: false,
      ),
      'without-permission' => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
      ),
      _ => const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canRequestTechnicalWorkCompletion: true,
      ),
    };
  }
}
