import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/create_field_report_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/assignment_target.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_submission_status.dart';

void main() {
  const request = CreateFieldReportRequest(
    category: TechnicalWorkCategory.lighting,
    title: 'Aydınlatma arızası',
    description: 'Yol aydınlatmalarının bir bölümü çalışmıyor.',
    location: 'D-100 / Km 14+200',
  );

  test('saha bildirimi başarıyla gönderilir', () async {
    final controller = FieldReportController(
      repository: FakeTechnicalWorkRepository(works: [], delay: Duration.zero),
    );

    addTearDown(controller.dispose);

    await controller.submit(
      request: request,
      createdByUserId: 'user-driver-001',
    );

    expect(controller.status, FieldReportSubmissionStatus.success);
    expect(controller.createdWork, isNotNull);
    expect(controller.createdWork!.title, 'Aydınlatma arızası');
    expect(controller.errorMessage, isNull);
  });

  test('gönderim sürerken ikinci bildirim oluşturulmaz', () async {
    final repository = FakeTechnicalWorkRepository(
      works: [],
      delay: const Duration(milliseconds: 50),
    );

    final controller = FieldReportController(repository: repository);

    addTearDown(controller.dispose);

    final firstSubmission = controller.submit(
      request: request,
      createdByUserId: 'user-driver-001',
    );

    final secondSubmission = controller.submit(
      request: request,
      createdByUserId: 'user-driver-001',
    );

    await Future.wait([firstSubmission, secondSubmission]);

    final works = await repository.getAllWorks();

    expect(works, hasLength(1));
    expect(controller.status, FieldReportSubmissionStatus.success);
  });

  test('repository hata verirse failure durumuna geçer', () async {
    final controller = FieldReportController(
      repository: _FailingTechnicalWorkRepository(),
    );

    addTearDown(controller.dispose);

    await controller.submit(
      request: request,
      createdByUserId: 'user-driver-001',
    );

    expect(controller.status, FieldReportSubmissionStatus.failure);
    expect(controller.createdWork, isNull);
    expect(controller.errorMessage, 'Rapor gönderilemedi.');
  });
}

class _FailingTechnicalWorkRepository implements TechnicalWorkRepository {
  @override
  Future<bool> canUserStartTechnicalWork(String userId) async {
    throw Exception('Repository error');
  }

  @override
  Future<bool> hasOpenWorkAssignedToTeam(String teamId) async {
    throw Exception('Repository error');
  }

  @override
  Future<TechnicalWork> assignWork({
    required String workId,
    required TechnicalWorkPriority priority,
    required AssignmentTarget target,
  }) async {
    throw Exception('Repository error');
  }

  @override
  Future<TechnicalWork> createFieldReport({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  }) async {
    throw Exception('Repository error');
  }

  @override
  Future<List<TechnicalWork>> getAllWorks() async {
    throw Exception('Repository error');
  }

  @override
  Future<List<TechnicalWork>> getAssignedWorks(String userId) async {
    throw Exception('Repository error');
  }

  @override
  Future<List<AssignmentTarget>> getAssignmentTargets() async {
    throw Exception('Repository error');
  }

  @override
  Future<TechnicalWork> startWork({
    required String workId,
    required String actorUserId,
  }) async {
    throw Exception('Repository error');
  }
}
