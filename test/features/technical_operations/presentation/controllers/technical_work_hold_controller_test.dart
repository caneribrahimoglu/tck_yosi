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
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_hold_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_hold_status.dart';

void main() {
  test('hold loading/success ve çift gönderim koruması çalışır', () async {
    final controller = _controller(delay: const Duration(milliseconds: 5));
    await controller.load(workId: 'work-1', userId: 'engineer');

    final first = controller.putOnHold('Parça bekleniyor.');
    expect(controller.status, TechnicalWorkHoldStatus.submitting);
    final second = controller.putOnHold('Tekrar');

    expect(await second, isFalse);
    expect(await first, isTrue);
    expect(controller.status, TechnicalWorkHoldStatus.success);
    expect(controller.canPause, isFalse);
    expect(controller.canResume, isTrue);
    expect(controller.history, hasLength(1));
    expect(controller.userName('engineer'), 'Zeynep Demir');
  });

  test('resume başarıyla geçmişi tamamlar', () async {
    final controller = _controller();
    await controller.load(workId: 'work-1', userId: 'engineer');
    await controller.putOnHold('Parça bekleniyor.');

    expect(await controller.resume(), isTrue);
    expect(controller.canPause, isTrue);
    expect(controller.canResume, isFalse);
    expect(controller.history.single.isResumed, isTrue);
  });

  test('blank reason güvenli mesaja çevrilir', () async {
    final controller = _controller();
    await controller.load(workId: 'work-1', userId: 'engineer');

    expect(await controller.putOnHold('  '), isFalse);
    expect(controller.status, TechnicalWorkHoldStatus.failure);
    expect(controller.errorMessage, 'Bekleme nedeni boş olamaz.');
  });
}

TechnicalWorkHoldController _controller({Duration delay = Duration.zero}) {
  return TechnicalWorkHoldController(
    repository: FakeTechnicalWorkRepository(
      works: [
        TechnicalWork(
          id: 'work-1',
          title: 'İş',
          description: 'Açıklama',
          location: 'D-100',
          category: TechnicalWorkCategory.lighting,
          priority: TechnicalWorkPriority.high,
          status: TechnicalWorkStatus.inProgress,
          createdByUserId: 'chief',
          assignedToUserId: 'engineer',
          createdAt: DateTime(2026, 8, 25),
        ),
      ],
      delay: delay,
      technicalWorkAccessSource: const _AccessSource(),
      now: () => DateTime(2026, 8, 25, 10),
    ),
    participantNameSource: const _NameSource(),
  );
}

class _AccessSource implements TechnicalWorkAccessSource {
  const _AccessSource();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    return const TechnicalWorkActorAccess(
      activeTeamIds: {},
      canStartTechnicalWork: false,
      canPauseTechnicalWork: true,
      canResumeTechnicalWork: true,
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
      userNames: {if (userIds.contains('engineer')) 'engineer': 'Zeynep Demir'},
      teamNames: const {},
    );
  }
}
