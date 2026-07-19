import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';

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
}
