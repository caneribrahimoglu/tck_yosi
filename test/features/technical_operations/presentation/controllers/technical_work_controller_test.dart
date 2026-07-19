import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_load_status.dart';

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
}

class _FailingTechnicalWorkRepository implements TechnicalWorkRepository {
  @override
  Future<List<TechnicalWork>> getAllWorks() {
    throw Exception('Repository error');
  }

  @override
  Future<List<TechnicalWork>> getAssignedWorks(String userId) {
    throw Exception('Repository error');
  }
}
