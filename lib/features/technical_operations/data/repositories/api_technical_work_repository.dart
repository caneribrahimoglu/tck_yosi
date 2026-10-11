import 'dart:math';

import '../../../../core/network/api_exception.dart';
import '../../../auth/data/services/api_auth_service.dart';
import '../../../auth/domain/enums/app_permission.dart';
import '../../domain/enums/assignment_target_type.dart';
import '../../domain/enums/technical_work_category.dart';
import '../../domain/enums/technical_work_priority.dart';
import '../../domain/enums/technical_work_status.dart';
import '../../domain/errors/technical_work_detail_read_exception.dart';
import '../../domain/models/add_technical_work_progress_request.dart';
import '../../domain/models/assignment_target.dart';
import '../../domain/models/create_field_report_request.dart';
import '../../domain/models/put_technical_work_on_hold_request.dart';
import '../../domain/models/submit_technical_work_completion_request.dart';
import '../../domain/models/technical_work.dart';
import '../../domain/models/technical_work_completion_request.dart';
import '../../domain/models/technical_work_completion_review_item.dart';
import '../../domain/models/technical_work_hold_record.dart';
import '../../domain/models/technical_work_progress_note.dart';
import '../../domain/repositories/technical_work_repository.dart';
import '../../domain/repositories/technical_work_repository_capabilities.dart';

/// Real reports/assignment only. Execution is explicitly unavailable until its
/// server slice is implemented; real records never enter the fake repository.
class ApiTechnicalWorkRepository
    implements TechnicalWorkRepository, TechnicalWorkRepositoryCapabilities {
  final ApiAuthService api;
  final _submissionIds = Expando<String>();
  final Map<String, int> _revisions = {};
  ApiTechnicalWorkRepository({required this.api});

  @override
  bool get supportsExecution => false;

  Future<void> _requireActor(String id) async {
    final user = await api.getCurrentUser();
    if (user == null || user.id != id || !user.isActive) {
      throw const TechnicalWorkDetailReadNotAllowedException();
    }
  }

  TechnicalWork _parse(Object? value) {
    final data = value as Map<String, dynamic>;
    DateTime? date(String key) => data[key] == null
        ? null
        : DateTime.parse(data[key] as String).toLocal();
    final work = TechnicalWork(
      id: data['id'] as String,
      revision: data['revision'] as int,
      title: data['title'] as String,
      description: data['description'] as String,
      location: data['location'] as String,
      category: TechnicalWorkCategory.values.byName(data['category'] as String),
      priority: TechnicalWorkPriority.values.byName(data['priority'] as String),
      status: TechnicalWorkStatus.values.byName(data['status'] as String),
      createdByUserId: data['created_by_user_id'] as String,
      assignedToUserId: data['assigned_to_user_id'] as String?,
      assignedToTeamId: data['assigned_to_team_id'] as String?,
      createdAt: date('created_at')!,
      plannedAt: date('planned_at'),
      completedAt: date('completed_at'),
      startedByUserId: data['started_by_user_id'] as String?,
      startedAt: date('started_at'),
    );
    _revisions[work.id] = work.revision;
    return work;
  }

  @override
  Future<List<TechnicalWork>> getAllWorks() async => List.unmodifiable(
    (await api.requestBusiness('technical-works') as List).map(_parse),
  );

  @override
  Future<List<TechnicalWork>> getAssignedWorks(String userId) async {
    await _requireActor(userId);
    return List.unmodifiable(
      (await api.requestBusiness('technical-works?assigned_only=true') as List)
          .map(_parse),
    );
  }

  @override
  Future<TechnicalWork> getWorkById({
    required String workId,
    required String actorUserId,
  }) async {
    await _requireActor(actorUserId);
    try {
      return _parse(
        await api.requestBusiness(
          'technical-works/${Uri.encodeComponent(workId)}',
        ),
      );
    } on ApiException catch (error) {
      if (error.code == 'technical_work_read_not_allowed' ||
          error.code == 'not_allowed') {
        throw const TechnicalWorkDetailReadNotAllowedException();
      }
      rethrow;
    }
  }

  @override
  Future<List<AssignmentTarget>> getAssignmentTargets() async {
    final user = await api.getCurrentUser();
    if (user == null ||
        !user.permissions.contains(AppPermission.assignTechnicalWork) ||
        !user.permissions.contains(AppPermission.viewAllTechnicalWork)) {
      return const [];
    }
    return List.unmodifiable(
      (await api.requestBusiness('technical-works/assignment-targets') as List)
          .map((value) {
            final data = value as Map<String, dynamic>;
            return AssignmentTarget(
              id: data['id'] as String,
              name: data['name'] as String,
              type: AssignmentTargetType.values.byName(data['type'] as String),
            );
          }),
    );
  }

  @override
  Future<TechnicalWork> assignWork({
    required String workId,
    int? expectedRevision,
    required TechnicalWorkPriority priority,
    required AssignmentTarget target,
  }) async {
    final revision = expectedRevision ?? _revisions[workId];
    if (revision == null) throw const ApiException('work_revision_conflict');
    return _parse(
      await api.requestBusiness(
        'technical-works/${Uri.encodeComponent(workId)}/assign',
        body: {
          'priority': priority.name,
          'assigned_to_user_id': target.type == AssignmentTargetType.engineer
              ? target.id
              : null,
          'assigned_to_team_id': target.type == AssignmentTargetType.team
              ? target.id
              : null,
          'expected_revision': revision,
        },
      ),
    );
  }

  @override
  Future<TechnicalWork> createFieldReport({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  }) async {
    await _requireActor(createdByUserId);
    final submissionId = _submissionIds[request] ??= _uuid();
    return _parse(
      await api.requestBusiness(
        'technical-works',
        body: {
          'submission_id': submissionId,
          'title': request.title,
          'description': request.description,
          'location': request.location,
          'category': request.category.name,
        },
      ),
    );
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Future<bool> hasOpenWorkAssignedToTeam(String teamId) async =>
      (await getAllWorks()).any(
        (work) => work.assignedToTeamId == teamId && work.isOpen,
      );

  Never _unavailable() => throw const ApiException('feature_not_available');
  @override
  Future<bool> canUserStartTechnicalWork(String userId) async => false;
  @override
  Future<bool> canUserAddProgress({
    required String workId,
    required String userId,
  }) async => false;
  @override
  Future<bool> canUserRequestCompletion({
    required String workId,
    required String userId,
  }) async => false;
  @override
  Future<bool> canUserPauseWork({
    required String workId,
    required String userId,
  }) async => false;
  @override
  Future<bool> canUserResumeWork({
    required String workId,
    required String userId,
  }) async => false;
  @override
  Future<List<TechnicalWorkProgressNote>> getProgressNotes({
    required String workId,
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<List<TechnicalWorkCompletionRequest>> getCompletionRequests({
    required String workId,
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<List<TechnicalWorkCompletionReviewItem>> getPendingCompletionReviews({
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<List<TechnicalWorkHoldRecord>> getHoldHistory({
    required String workId,
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<TechnicalWork> startWork({
    required String workId,
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<TechnicalWorkProgressNote> addProgressNote({
    required AddTechnicalWorkProgressRequest request,
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<TechnicalWorkCompletionRequest> submitCompletionRequest({
    required SubmitTechnicalWorkCompletionRequest request,
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<TechnicalWorkCompletionRequest> approveCompletionRequest({
    required String requestId,
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<TechnicalWorkCompletionRequest> rejectCompletionRequest({
    required String requestId,
    required String actorUserId,
    required String rejectionReason,
  }) async => _unavailable();
  @override
  Future<TechnicalWorkHoldRecord> putWorkOnHold({
    required PutTechnicalWorkOnHoldRequest request,
    required String actorUserId,
  }) async => _unavailable();
  @override
  Future<TechnicalWorkHoldRecord> resumeWork({
    required String workId,
    required String actorUserId,
  }) async => _unavailable();
}
