import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/add_technical_work_progress_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_actor_access.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_participant_names.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_progress_note.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_participant_name_source.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_load_status.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_progress_submission_status.dart';

void main() {
  test('detayı yükler ve ilerleme kaydını başarıyla ekler', () async {
    final controller = _createController();
    addTearDown(controller.dispose);

    await controller.load(workId: 'work-detail', userId: 'engineer-001');

    expect(controller.loadStatus, TechnicalWorkLoadStatus.loaded);
    expect(controller.canAddProgress, isTrue);
    expect(controller.assignedToName, 'Zeynep Demir');

    final submission = controller.addProgress('Kontrol tamamlandı.');
    expect(
      controller.submissionStatus,
      TechnicalWorkProgressSubmissionStatus.submitting,
    );
    expect(await submission, isTrue);
    expect(
      controller.submissionStatus,
      TechnicalWorkProgressSubmissionStatus.success,
    );
    expect(controller.notes.single.content, 'Kontrol tamamlandı.');
    expect(controller.authorName(controller.notes.single), 'Zeynep Demir');
  });

  test('geçersiz notu failure ve kullanıcı mesajına dönüştürür', () async {
    final controller = _createController();
    addTearDown(controller.dispose);
    await controller.load(workId: 'work-detail', userId: 'engineer-001');

    final succeeded = await controller.addProgress('   ');

    expect(succeeded, isFalse);
    expect(
      controller.submissionStatus,
      TechnicalWorkProgressSubmissionStatus.failure,
    );
    expect(controller.errorMessage, 'İlerleme notu boş olamaz.');
    expect(controller.notes, isEmpty);
  });

  test(
    'submission sürerken ikinci controller isteğini repositoryye göndermez',
    () async {
      final repository = _CountingProgressRepository(
        works: [_inProgressWork],
        delay: const Duration(milliseconds: 20),
        technicalWorkAccessSource: const _ProgressAccessSource(),
      );
      final controller = TechnicalWorkDetailController(
        repository: repository,
        participantNameSource: const _NameSource(),
      );
      addTearDown(controller.dispose);
      await controller.load(workId: 'work-detail', userId: 'engineer-001');

      final first = controller.addProgress('Tek kayıt');
      final second = await controller.addProgress('İkinci kayıt');

      expect(second, isFalse);
      expect(await first, isTrue);
      expect(repository.addCallCount, 1);
      expect(controller.notes, hasLength(1));
    },
  );

  test(
    'yetkisiz detay okumasını generic load failure olarak gösterir',
    () async {
      final controller = _createController();
      addTearDown(controller.dispose);

      await controller.load(workId: 'work-detail', userId: 'unrelated-user');

      expect(controller.loadStatus, TechnicalWorkLoadStatus.failure);
      expect(controller.work, isNull);
      expect(controller.notes, isEmpty);
      expect(controller.errorMessage, 'Teknik iş detayı yüklenemedi.');
    },
  );
}

TechnicalWorkDetailController _createController() {
  return TechnicalWorkDetailController(
    repository: FakeTechnicalWorkRepository(
      works: [_inProgressWork],
      delay: Duration.zero,
      technicalWorkAccessSource: const _ProgressAccessSource(),
      now: () => DateTime(2026, 8, 17, 12),
    ),
    participantNameSource: const _NameSource(),
  );
}

final _inProgressWork = TechnicalWork(
  id: 'work-detail',
  title: 'Detay işi',
  description: 'Controller testi',
  location: 'D-100',
  category: TechnicalWorkCategory.lighting,
  priority: TechnicalWorkPriority.high,
  status: TechnicalWorkStatus.inProgress,
  createdByUserId: 'chief-001',
  assignedToUserId: 'engineer-001',
  startedByUserId: 'engineer-001',
  startedAt: DateTime(2026, 8, 17, 10),
  createdAt: DateTime(2026, 8, 17, 9),
);

class _ProgressAccessSource implements TechnicalWorkAccessSource {
  const _ProgressAccessSource();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    return const TechnicalWorkActorAccess(
      activeTeamIds: {},
      canStartTechnicalWork: true,
      canAddTechnicalWorkProgress: true,
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
    return const TechnicalWorkParticipantNames(
      userNames: {
        'engineer-001': 'Zeynep Demir',
        'chief-001': 'Ahmet Dulkadir',
      },
      teamNames: {},
    );
  }
}

class _CountingProgressRepository extends FakeTechnicalWorkRepository {
  int addCallCount = 0;

  _CountingProgressRepository({
    required super.works,
    required super.delay,
    required super.technicalWorkAccessSource,
  });

  @override
  Future<TechnicalWorkProgressNote> addProgressNote({
    required AddTechnicalWorkProgressRequest request,
    required String actorUserId,
  }) {
    addCallCount++;
    return super.addProgressNote(request: request, actorUserId: actorUserId);
  }
}
