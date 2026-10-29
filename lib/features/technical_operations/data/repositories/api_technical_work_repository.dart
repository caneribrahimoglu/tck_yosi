import 'dart:math';

import '../../../../core/network/api_exception.dart';
import '../../../auth/data/services/api_auth_service.dart';
import '../../../auth/domain/enums/app_permission.dart';
import '../../domain/enums/assignment_target_type.dart';
import '../../domain/enums/technical_work_category.dart';
import '../../domain/enums/technical_work_priority.dart';
import '../../domain/enums/technical_work_status.dart';
import '../../domain/errors/technical_work_detail_read_exception.dart';
import '../../domain/errors/technical_work_start_exception.dart';
import '../../domain/errors/technical_work_progress_exception.dart';
import '../../domain/errors/technical_work_hold_exception.dart';
import '../../domain/errors/technical_work_completion_exception.dart';
import '../../domain/enums/technical_work_completion_decision.dart';
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

/// Real technical lifecycle and completion review; never falls back to demo writes.
class ApiTechnicalWorkRepository
    implements TechnicalWorkRepository, TechnicalWorkRepositoryCapabilities {
  final ApiAuthService api;
  final _submissionIds = Expando<String>();
  final Map<String, int> _revisions = {};
  ApiTechnicalWorkRepository({required this.api});

  @override
  bool get supportsExecution => true;
  @override
  bool get supportsCompletion => true;
  @override
  bool get supportsCompletionRequests => true;

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

  String _path(String workId, String suffix) =>
      'technical-works/${Uri.encodeComponent(workId)}/$suffix';

  Future<Object?> _read(String path, String actorUserId) async {
    await _requireActor(actorUserId);
    try {
      return await api.requestBusiness(path);
    } on ApiException catch (error) {
      if (error.code == 'technical_work_read_not_allowed' ||
          error.code == 'not_allowed') {
        throw const TechnicalWorkDetailReadNotAllowedException();
      }
      rethrow;
    }
  }

  Future<Object?> _mutate(
    String path,
    String actorUserId,
    Map<String, Object?> body,
    String operation,
  ) async {
    try {
      try {
        await _requireActor(actorUserId);
      } on TechnicalWorkDetailReadNotAllowedException {
        throw const ApiException('not_allowed');
      }
      return await api.requestBusiness(path, body: body);
    } on ApiException catch (error) {
      final denied =
          error.code == 'not_allowed' || error.code.endsWith('_not_allowed');
      if (operation == 'start') {
        if (denied) throw const TechnicalWorkStartNotAllowedException();
        if (error.code == 'technical_work_already_started') {
          throw const TechnicalWorkAlreadyStartedException();
        }
      } else if (operation == 'progress') {
        if (denied) throw const TechnicalWorkProgressNotAllowedException();
        if (error.code == 'invalid_input') {
          throw const TechnicalWorkProgressInvalidInputException();
        }
        if (error.code == 'technical_work_progress_invalid_state') {
          throw const TechnicalWorkProgressInvalidStateException();
        }
        if (error.code == 'technical_work_progress_submission_conflict') {
          throw const TechnicalWorkProgressSubmissionInFlightException();
        }
      } else if (operation == 'review') {
        if (denied) {
          throw const TechnicalWorkCompletionReviewNotAllowedException();
        }
        if (error.code == 'invalid_input') {
          throw const TechnicalWorkCompletionInvalidInputException();
        }
        if (error.code == 'technical_work_completion_already_decided') {
          throw const TechnicalWorkCompletionAlreadyDecidedException();
        }
        if (error.code == 'technical_work_completion_review_invalid_state') {
          throw const TechnicalWorkCompletionInvalidStateException();
        }
      } else if (operation == 'completion') {
        if (denied) throw const TechnicalWorkCompletionNotAllowedException();
        if (error.code == 'invalid_input') {
          throw const TechnicalWorkCompletionInvalidInputException();
        }
        if (error.code == 'technical_work_completion_invalid_state' ||
            error.code == 'technical_work_completion_revision_conflict') {
          throw const TechnicalWorkCompletionInvalidStateException();
        }
        if (error.code == 'technical_work_completion_submission_conflict') {
          throw const TechnicalWorkCompletionSubmissionInFlightException();
        }
      } else {
        if (denied) throw const TechnicalWorkHoldNotAllowedException();
        if (error.code == 'invalid_input') {
          throw const TechnicalWorkHoldInvalidInputException();
        }
        if (error.code == 'technical_work_hold_invalid_state') {
          throw const TechnicalWorkHoldInvalidStateException();
        }
        if (error.code == 'technical_work_hold_transition_conflict') {
          throw const TechnicalWorkHoldTransitionInFlightException();
        }
      }
      rethrow;
    }
  }

  int _revision(String workId) =>
      _revisions[workId] ??
      (throw const ApiException('work_revision_conflict'));

  TechnicalWorkProgressNote _note(Object? value) {
    final data = value as Map<String, dynamic>;
    return TechnicalWorkProgressNote(
      id: data['id'] as String,
      workId: data['work_id'] as String,
      authorUserId: data['author_user_id'] as String,
      content: data['content'] as String,
      createdAt: DateTime.parse(data['created_at'] as String).toLocal(),
    );
  }

  TechnicalWorkHoldRecord _hold(Object? value) {
    final data = value as Map<String, dynamic>;
    return TechnicalWorkHoldRecord(
      id: data['id'] as String,
      workId: data['work_id'] as String,
      heldByUserId: data['held_by_user_id'] as String,
      heldAt: DateTime.parse(data['held_at'] as String).toLocal(),
      reason: data['reason'] as String,
      resumedByUserId: data['resumed_by_user_id'] as String?,
      resumedAt: data['resumed_at'] == null
          ? null
          : DateTime.parse(data['resumed_at'] as String).toLocal(),
    );
  }

  Future<bool> _can(String workId, String userId, String capability) async {
    final data =
        await _read(_path(workId, 'capabilities'), userId)
            as Map<String, dynamic>;
    return data[capability] as bool;
  }

  @override
  Future<bool> canUserStartTechnicalWork(String userId) async {
    final data =
        await _read('technical-works/actor-capabilities', userId)
            as Map<String, dynamic>;
    return data['can_start'] as bool;
  }

  @override
  Future<bool> canUserAddProgress({
    required String workId,
    required String userId,
  }) => _can(workId, userId, 'can_add_progress');
  @override
  Future<bool> canUserRequestCompletion({
    required String workId,
    required String userId,
  }) => _can(workId, userId, 'can_request_completion');
  @override
  Future<bool> canUserPauseWork({
    required String workId,
    required String userId,
  }) => _can(workId, userId, 'can_pause');
  @override
  Future<bool> canUserResumeWork({
    required String workId,
    required String userId,
  }) => _can(workId, userId, 'can_resume');
  @override
  Future<List<TechnicalWorkProgressNote>> getProgressNotes({
    required String workId,
    required String actorUserId,
  }) async => List.unmodifiable(
    (await _read(_path(workId, 'progress'), actorUserId) as List).map(_note),
  );
  @override
  Future<List<TechnicalWorkCompletionRequest>> getCompletionRequests({
    required String workId,
    required String actorUserId,
  }) async => List.unmodifiable(
    (await _read(_path(workId, 'completion-requests'), actorUserId) as List)
        .map(_completion),
  );
  @override
  Future<List<TechnicalWorkCompletionReviewItem>> getPendingCompletionReviews({
    required String actorUserId,
  }) async {
    try {
      return List.unmodifiable(
        (await _read('technical-works/completion-requests/pending', actorUserId)
                as List)
            .map((value) {
              final data = value as Map<String, dynamic>;
              return TechnicalWorkCompletionReviewItem(
                work: _parse(data['work']),
                request: _completion(data['request']),
              );
            }),
      );
    } on TechnicalWorkDetailReadNotAllowedException {
      throw const TechnicalWorkCompletionReviewNotAllowedException();
    }
  }

  @override
  Future<List<TechnicalWorkHoldRecord>> getHoldHistory({
    required String workId,
    required String actorUserId,
  }) async => List.unmodifiable(
    (await _read(_path(workId, 'holds'), actorUserId) as List).map(_hold),
  );
  @override
  Future<TechnicalWork> startWork({
    required String workId,
    required String actorUserId,
  }) async {
    final revision = _revision(workId);
    return _parse(
      await _mutate(_path(workId, 'start'), actorUserId, {
        'expected_revision': revision,
      }, 'start'),
    );
  }

  @override
  Future<TechnicalWorkProgressNote> addProgressNote({
    required AddTechnicalWorkProgressRequest request,
    required String actorUserId,
  }) async {
    final submissionId = _submissionIds[request] ??= _uuid();
    return _note(
      await _mutate(_path(request.workId, 'progress'), actorUserId, {
        'submission_id': submissionId,
        'content': request.content,
      }, 'progress'),
    );
  }

  @override
  Future<TechnicalWorkCompletionRequest> submitCompletionRequest({
    required SubmitTechnicalWorkCompletionRequest request,
    required String actorUserId,
  }) async {
    final revision = _revision(request.workId);
    final submissionId = _submissionIds[request] ??= _uuid();
    final data =
        await _mutate(
              _path(request.workId, 'completion-requests'),
              actorUserId,
              {
                'expected_revision': revision,
                'submission_id': submissionId,
                'summary': request.summary,
              },
              'completion',
            )
            as Map<String, dynamic>;
    _parse(data['work']);
    return _completion(data['request']);
  }

  TechnicalWorkCompletionRequest _completion(Object? value) {
    final data = value as Map<String, dynamic>;
    return TechnicalWorkCompletionRequest(
      id: data['id'] as String,
      workId: data['work_id'] as String,
      requestedByUserId: data['requested_by_user_id'] as String,
      summary: data['summary'] as String,
      requestedAt: DateTime.parse(data['requested_at'] as String).toLocal(),
      decision: TechnicalWorkCompletionDecision.values.byName(
        data['decision'] as String,
      ),
      reviewedByUserId: data['reviewed_by_user_id'] as String?,
      reviewedAt: data['reviewed_at'] == null
          ? null
          : DateTime.parse(data['reviewed_at'] as String).toLocal(),
      rejectionReason: data['rejection_reason'] as String?,
    );
  }

  @override
  Future<TechnicalWorkCompletionRequest> approveCompletionRequest({
    required String requestId,
    required String actorUserId,
  }) => _reviewCompletion(requestId, actorUserId, const {}, 'approve');
  @override
  Future<TechnicalWorkCompletionRequest> rejectCompletionRequest({
    required String requestId,
    required String actorUserId,
    required String rejectionReason,
  }) => _reviewCompletion(requestId, actorUserId, {
    'reason': rejectionReason,
  }, 'reject');

  Future<TechnicalWorkCompletionRequest> _reviewCompletion(
    String requestId,
    String actorUserId,
    Map<String, Object?> body,
    String action,
  ) async {
    final data =
        await _mutate(
              'technical-works/completion-requests/${Uri.encodeComponent(requestId)}/$action',
              actorUserId,
              body,
              'review',
            )
            as Map<String, dynamic>;
    _parse(data['work']);
    return _completion(data['request']);
  }

  @override
  Future<TechnicalWorkHoldRecord> putWorkOnHold({
    required PutTechnicalWorkOnHoldRequest request,
    required String actorUserId,
  }) async {
    final revision = _revision(request.workId);
    final data =
        await _mutate(_path(request.workId, 'hold'), actorUserId, {
              'expected_revision': revision,
              'reason': request.reason,
            }, 'hold')
            as Map<String, dynamic>;
    _parse(data['work']);
    return _hold(data['record']);
  }

  @override
  Future<TechnicalWorkHoldRecord> resumeWork({
    required String workId,
    required String actorUserId,
  }) async {
    final revision = _revision(workId);
    final data =
        await _mutate(_path(workId, 'resume'), actorUserId, {
              'expected_revision': revision,
            }, 'hold')
            as Map<String, dynamic>;
    _parse(data['work']);
    return _hold(data['record']);
  }
}
