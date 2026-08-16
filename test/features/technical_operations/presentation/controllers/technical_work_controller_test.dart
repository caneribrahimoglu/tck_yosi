import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_load_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/create_field_report_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/assignment_target.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/assignment_target_type.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_start_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_actor_access.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/add_technical_work_progress_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_progress_note.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_start_status.dart';

void main() {
  test('yükleme başladığında loading durumuna geçer', () async {
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(
        delay: const Duration(milliseconds: 10),
      ),
    );

    addTearDown(controller.dispose);

    final loadFuture = controller.load('user-engineer-001');

    expect(controller.status, TechnicalWorkLoadStatus.loading);

    await loadFuture;

    expect(controller.status, TechnicalWorkLoadStatus.loaded);
  });

  test('teknik işleri ve sayaçları başarıyla yükler', () async {
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(delay: Duration.zero),
    );

    addTearDown(controller.dispose);

    await controller.load('user-engineer-001');

    expect(controller.status, TechnicalWorkLoadStatus.loaded);
    expect(controller.allWorks, hasLength(4));
    expect(controller.assignedWorks, hasLength(3));
    expect(controller.openWorkCount, 4);
    expect(controller.criticalWorkCount, 2);
    expect(controller.awaitingInspectionCount, 1);
    expect(controller.errorMessage, isNull);
    expect(controller.unassignedWorkCount, 1);
    expect(controller.inProgressWorkCount, 1);
  });

  test('repository hata verirse failure durumuna geçer', () async {
    final controller = TechnicalWorkController(
      repository: _FailingTechnicalWorkRepository(),
    );

    addTearDown(controller.dispose);

    await controller.load('user-engineer-001');

    expect(controller.status, TechnicalWorkLoadStatus.failure);
    expect(controller.allWorks, isEmpty);
    expect(controller.assignedWorks, isEmpty);
    expect(controller.errorMessage, 'Teknik işler yüklenemedi.');
  });

  test('atanmamış işi önceliklendirip ekibe atar', () async {
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);
    await controller.load('user-chief-001');

    const target = AssignmentTarget(
      id: 'team-road-maintenance',
      name: 'Yol Bakım Ekibi',
      type: AssignmentTargetType.team,
    );
    final succeeded = await controller.assignWork(
      workId: 'work-004',
      priority: TechnicalWorkPriority.high,
      target: target,
    );

    expect(succeeded, isTrue);
    expect(controller.unassignedWorkCount, 0);
    final updated = controller.allWorks.singleWhere(
      (work) => work.id == 'work-004',
    );
    expect(updated.priority, TechnicalWorkPriority.high);
    expect(updated.assignedToTeamId, target.id);
  });

  test('atama sürerken ikinci atama isteğini reddeder', () async {
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(
        delay: const Duration(milliseconds: 50),
      ),
    );
    addTearDown(controller.dispose);
    await controller.load('user-chief-001');
    const target = AssignmentTarget(
      id: 'team-road-maintenance',
      name: 'Yol Bakım Ekibi',
      type: AssignmentTargetType.team,
    );

    final firstAssignment = controller.assignWork(
      workId: 'work-004',
      priority: TechnicalWorkPriority.high,
      target: target,
    );
    final secondResult = await controller.assignWork(
      workId: 'work-004',
      priority: TechnicalWorkPriority.critical,
      target: target,
    );

    expect(controller.isAssigning, isTrue);
    expect(secondResult, isFalse);
    expect(await firstAssignment, isTrue);
    expect(controller.isAssigning, isFalse);
    expect(
      controller.allWorks.singleWhere((work) => work.id == 'work-004').priority,
      TechnicalWorkPriority.high,
    );
  });

  test('iş başlatırken loading ve success durumlarını yayınlar', () async {
    final repository = FakeTechnicalWorkRepository(
      works: [_assignedWork()],
      delay: const Duration(milliseconds: 20),
      technicalWorkAccessSource: const _AllowedAccessSource(),
    );
    final controller = TechnicalWorkController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load('user-engineer-001');

    final startFuture = controller.startWork(
      workId: 'work-start',
      actorUserId: 'user-engineer-001',
    );

    expect(controller.startStatus, TechnicalWorkStartStatus.starting);
    expect(controller.isStarting('work-start'), isTrue);
    expect(await startFuture, isTrue);
    expect(controller.startStatus, TechnicalWorkStartStatus.success);
    expect(controller.isStartingWork, isFalse);
    expect(
      controller.assignedWorks.single.status,
      TechnicalWorkStatus.inProgress,
    );
    expect(controller.inProgressWorkCount, 1);
  });

  test('controller aynı anda ikinci başlatma isteğini göndermez', () async {
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(
        works: [_assignedWork()],
        delay: const Duration(milliseconds: 20),
        technicalWorkAccessSource: const _AllowedAccessSource(),
      ),
    );
    addTearDown(controller.dispose);
    await controller.load('user-engineer-001');

    final first = controller.startWork(
      workId: 'work-start',
      actorUserId: 'user-engineer-001',
    );
    final second = await controller.startWork(
      workId: 'work-start',
      actorUserId: 'user-engineer-001',
    );

    expect(second, isFalse);
    expect(await first, isTrue);
  });

  test('zaten başlatılmış işi ayrı kullanıcı mesajına dönüştürür', () async {
    final started = _assignedWork().copyWith(
      status: TechnicalWorkStatus.inProgress,
      startedByUserId: 'user-engineer-001',
      startedAt: DateTime(2026, 8, 16, 9),
    );
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(
        works: [started],
        delay: Duration.zero,
        technicalWorkAccessSource: const _AllowedAccessSource(),
      ),
    );
    addTearDown(controller.dispose);
    await controller.load('user-engineer-001');

    final result = await controller.startWork(
      workId: started.id,
      actorUserId: 'user-engineer-001',
    );

    expect(result, isFalse);
    expect(controller.startStatus, TechnicalWorkStartStatus.alreadyStarted);
    expect(controller.errorMessage, 'İş zaten başlatıldı.');
    expect(controller.assignedWorks.single.startedAt, started.startedAt);
  });
}

TechnicalWork _assignedWork() => TechnicalWork(
  id: 'work-start',
  title: 'Başlatılacak iş',
  description: 'Test işi',
  location: 'D-100',
  category: TechnicalWorkCategory.lighting,
  priority: TechnicalWorkPriority.high,
  status: TechnicalWorkStatus.assigned,
  createdByUserId: 'user-chief-001',
  assignedToUserId: 'user-engineer-001',
  createdAt: DateTime(2026, 8, 16),
);

class _AllowedAccessSource implements TechnicalWorkAccessSource {
  const _AllowedAccessSource();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    return const TechnicalWorkActorAccess(
      activeTeamIds: {'team-technical'},
      canStartTechnicalWork: true,
    );
  }
}

class _FailingTechnicalWorkRepository implements TechnicalWorkRepository {
  @override
  Future<TechnicalWorkProgressNote> addProgressNote({
    required AddTechnicalWorkProgressRequest request,
    required String actorUserId,
  }) {
    throw Exception('Repository error');
  }

  @override
  Future<bool> canUserAddProgress({
    required String workId,
    required String userId,
  }) {
    throw Exception('Repository error');
  }

  @override
  Future<bool> canUserStartTechnicalWork(String userId) {
    throw Exception('Repository error');
  }

  @override
  Future<bool> hasOpenWorkAssignedToTeam(String teamId) {
    throw Exception('Repository error');
  }

  @override
  Future<TechnicalWork> assignWork({
    required String workId,
    required TechnicalWorkPriority priority,
    required AssignmentTarget target,
  }) {
    throw Exception('Repository error');
  }

  @override
  Future<List<TechnicalWork>> getAllWorks() {
    throw Exception('Repository error');
  }

  @override
  Future<List<TechnicalWork>> getAssignedWorks(String userId) {
    throw Exception('Repository error');
  }

  @override
  Future<List<TechnicalWorkProgressNote>> getProgressNotes({
    required String workId,
    required String actorUserId,
  }) {
    throw Exception('Repository error');
  }

  @override
  Future<TechnicalWork> getWorkById({
    required String workId,
    required String actorUserId,
  }) {
    throw Exception('Repository error');
  }

  @override
  Future<List<AssignmentTarget>> getAssignmentTargets() {
    throw Exception('Repository error');
  }

  @override
  Future<TechnicalWork> createFieldReport({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  }) {
    throw Exception('Repository error');
  }

  @override
  Future<TechnicalWork> startWork({
    required String workId,
    required String actorUserId,
  }) {
    throw const TechnicalWorkStartNotAllowedException();
  }
}
