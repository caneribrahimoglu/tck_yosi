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
}

class _FailingTechnicalWorkRepository implements TechnicalWorkRepository {
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
}
