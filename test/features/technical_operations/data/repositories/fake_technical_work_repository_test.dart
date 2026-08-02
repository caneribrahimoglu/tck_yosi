import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/create_field_report_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/assignment_target.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/assignment_target_type.dart';

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
}
