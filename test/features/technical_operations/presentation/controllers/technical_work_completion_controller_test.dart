import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_actor_access.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_participant_names.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_participant_name_source.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_status.dart';

void main() {
  test(
    'talep gönderimi loading, success ve çift gönderim koruması sağlar',
    () async {
      final repository = _repository(delay: const Duration(milliseconds: 5));
      final controller = _controller(repository);
      await controller.loadForWork(workId: 'work-1', userId: 'engineer');

      final first = controller.submit('İş tamamlandı.');
      expect(controller.isSubmittingRequest, isTrue);
      expect(controller.detailStatus, TechnicalWorkCompletionStatus.submitting);
      final second = controller.submit('İş tamamlandı.');

      expect(await second, isFalse);
      expect(await first, isTrue);
      expect(controller.history, hasLength(1));
      expect(controller.canRequestCompletion, isFalse);
      expect(controller.detailStatus, TechnicalWorkCompletionStatus.success);
    },
  );

  test('boş özet güvenli kullanıcı mesajına çevrilir', () async {
    final controller = _controller(_repository());
    await controller.loadForWork(workId: 'work-1', userId: 'engineer');

    expect(await controller.submit('  '), isFalse);
    expect(controller.detailStatus, TechnicalWorkCompletionStatus.failure);
    expect(controller.errorMessage, 'Tamamlama özeti boş olamaz.');
  });

  test('review kuyruğu yüklenir ve onaydan sonra sayaç yenilenir', () async {
    final repository = _repository();
    final engineerController = _controller(repository);
    await engineerController.loadForWork(workId: 'work-1', userId: 'engineer');
    await engineerController.submit('İş tamamlandı.');
    final reviewerController = _controller(repository);

    await reviewerController.loadPending('chief');
    expect(reviewerController.pendingCount, 1);
    expect(reviewerController.userName('engineer'), 'Zeynep Demir');
    final requestId = reviewerController.pendingReviews.single.request.id;
    expect(await reviewerController.approve(requestId), isTrue);
    expect(reviewerController.pendingCount, 0);
    expect(
      reviewerController.queueStatus,
      TechnicalWorkCompletionStatus.success,
    );
  });
}

FakeTechnicalWorkRepository _repository({Duration delay = Duration.zero}) {
  return FakeTechnicalWorkRepository(
    works: [
      TechnicalWork(
        id: 'work-1',
        title: 'Aydınlatma işi',
        description: 'Onarım',
        location: 'D-100',
        category: TechnicalWorkCategory.lighting,
        priority: TechnicalWorkPriority.high,
        status: TechnicalWorkStatus.inProgress,
        createdByUserId: 'chief',
        assignedToUserId: 'engineer',
        createdAt: DateTime(2026, 8, 16),
      ),
    ],
    delay: delay,
    technicalWorkAccessSource: const _AccessSource(),
    now: () => DateTime(2026, 8, 16, 12),
  );
}

TechnicalWorkCompletionController _controller(
  FakeTechnicalWorkRepository repository,
) {
  return TechnicalWorkCompletionController(
    repository: repository,
    participantNameSource: const _NameSource(),
  );
}

class _AccessSource implements TechnicalWorkAccessSource {
  const _AccessSource();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    if (userId == 'chief') {
      return const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canReviewTechnicalWorkCompletion: true,
        canViewAllTechnicalWork: true,
      );
    }
    return const TechnicalWorkActorAccess(
      activeTeamIds: {},
      canStartTechnicalWork: false,
      canRequestTechnicalWorkCompletion: true,
    );
  }
}

class _NameSource implements TechnicalWorkParticipantNameSource {
  const _NameSource();

  @override
  Future<TechnicalWorkParticipantNames> resolveNames({
    required Set<String> userIds,
    required Set<String> teamIds,
  }) async {
    return TechnicalWorkParticipantNames(
      userNames: {
        if (userIds.contains('engineer')) 'engineer': 'Zeynep Demir',
        if (userIds.contains('chief')) 'chief': 'Ahmet Dulkadir',
      },
      teamNames: const {},
    );
  }
}
