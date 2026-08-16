import '../models/technical_work.dart';
import '../models/create_field_report_request.dart';
import '../models/assignment_target.dart';
import '../enums/technical_work_priority.dart';
import '../models/add_technical_work_progress_request.dart';
import '../models/technical_work_progress_note.dart';

abstract interface class TechnicalWorkRepository {
  Future<List<TechnicalWork>> getAllWorks();

  Future<List<TechnicalWork>> getAssignedWorks(String userId);

  Future<TechnicalWork> getWorkById({
    required String workId,
    required String actorUserId,
  });

  Future<List<TechnicalWorkProgressNote>> getProgressNotes({
    required String workId,
    required String actorUserId,
  });

  Future<bool> canUserAddProgress({
    required String workId,
    required String userId,
  });

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

  Future<TechnicalWorkProgressNote> addProgressNote({
    required AddTechnicalWorkProgressRequest request,
    required String actorUserId,
  });

  Future<TechnicalWork> createFieldReport({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  });
}
