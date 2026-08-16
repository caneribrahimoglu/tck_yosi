import '../models/technical_work.dart';
import '../models/create_field_report_request.dart';
import '../models/assignment_target.dart';
import '../enums/technical_work_priority.dart';

abstract interface class TechnicalWorkRepository {
  Future<List<TechnicalWork>> getAllWorks();

  Future<List<TechnicalWork>> getAssignedWorks(String userId);

  Future<bool> canUserStartTechnicalWork(String userId);

  Future<List<AssignmentTarget>> getAssignmentTargets();

  Future<bool> hasOpenWorkAssignedToTeam(String teamId);

  Future<TechnicalWork> assignWork({
    required String workId,
    required TechnicalWorkPriority priority,
    required AssignmentTarget target,
  });

  Future<TechnicalWork> startWork({
    required String workId,
    required String actorUserId,
  });

  Future<TechnicalWork> createFieldReport({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  });
}
