import '../../domain/models/technical_work.dart';
import '../../domain/repositories/technical_work_repository.dart';
import '../fake_technical_work_data.dart';
import '../../domain/enums/technical_work_priority.dart';
import '../../domain/enums/technical_work_status.dart';
import '../../domain/models/create_field_report_request.dart';
import '../../domain/enums/assignment_target_type.dart';
import '../../domain/models/assignment_target.dart';
import '../../domain/repositories/team_assignment_target_source.dart';
import '../../domain/repositories/technical_work_access_source.dart';
import '../../domain/errors/technical_work_start_exception.dart';
import '../../domain/errors/technical_work_progress_exception.dart';
import '../../domain/models/add_technical_work_progress_request.dart';
import '../../domain/models/technical_work_progress_note.dart';
import '../../domain/errors/technical_work_detail_read_exception.dart';
import '../../domain/enums/technical_work_completion_decision.dart';
import '../../domain/errors/technical_work_completion_exception.dart';
import '../../domain/models/submit_technical_work_completion_request.dart';
import '../../domain/models/technical_work_completion_request.dart';
import '../../domain/models/technical_work_completion_review_item.dart';

class FakeTechnicalWorkRepository implements TechnicalWorkRepository {
  static const _individualAssignmentTargets = [
    AssignmentTarget(
      id: 'user-engineer-001',
      name: 'Zeynep Demir',
      type: AssignmentTargetType.engineer,
    ),
  ];
  final List<TechnicalWork> _works;
  final TeamAssignmentTargetSource? _teamAssignmentTargetSource;
  final TechnicalWorkAccessSource? _technicalWorkAccessSource;
  final DateTime Function() _now;
  final Set<String> _startingWorkIds = {};
  final List<TechnicalWorkProgressNote> _progressNotes;
  final Set<String> _progressSubmissionsInFlight = {};
  int _nextProgressNoteNumber;
  final List<TechnicalWorkCompletionRequest> _completionRequests;
  final Set<String> _completionRequestWorkIdsInFlight = {};
  final Set<String> _completionReviewRequestIdsInFlight = {};
  int _nextCompletionRequestNumber;
  final Duration delay;

  FakeTechnicalWorkRepository({
    List<TechnicalWork>? works,
    TeamAssignmentTargetSource? teamAssignmentTargetSource,
    TechnicalWorkAccessSource? technicalWorkAccessSource,
    List<TechnicalWorkProgressNote>? progressNotes,
    List<TechnicalWorkCompletionRequest>? completionRequests,
    DateTime Function()? now,
    this.delay = const Duration(milliseconds: 500),
  }) : _works = List.of(works ?? FakeTechnicalWorkData.works),
       _teamAssignmentTargetSource = teamAssignmentTargetSource,
       _technicalWorkAccessSource = technicalWorkAccessSource,
       _progressNotes = List.of(progressNotes ?? const []),
       _nextProgressNoteNumber = (progressNotes ?? const []).length + 1,
       _completionRequests = List.of(completionRequests ?? const []),
       _nextCompletionRequestNumber =
           (completionRequests ?? const []).length + 1,
       _now = now ?? DateTime.now;

  @override
  Future<List<TechnicalWork>> getAllWorks() async {
    await _simulateNetworkDelay();

    return List.unmodifiable(_works);
  }

  @override
  Future<List<TechnicalWork>> getAssignedWorks(String userId) async {
    await _simulateNetworkDelay();
    final activeTeamIds =
        (await _technicalWorkAccessSource?.getActorAccess(
          userId,
        ))?.activeTeamIds ??
        const <String>{};
    final matches = <String, TechnicalWork>{};
    for (final work in _works) {
      final isDirectlyAssigned = work.assignedToUserId == userId;
      final isAssignedThroughActiveTeam =
          work.isOpen && activeTeamIds.contains(work.assignedToTeamId);
      if (isDirectlyAssigned || isAssignedThroughActiveTeam) {
        matches[work.id] = work;
      }
    }
    return List.unmodifiable(matches.values);
  }

  @override
  Future<TechnicalWork> getWorkById({
    required String workId,
    required String actorUserId,
  }) async {
    await _simulateNetworkDelay();
    return _authorizeDetailRead(workId: workId, actorUserId: actorUserId);
  }

  @override
  Future<List<TechnicalWorkProgressNote>> getProgressNotes({
    required String workId,
    required String actorUserId,
  }) async {
    await _simulateNetworkDelay();
    await _authorizeDetailRead(workId: workId, actorUserId: actorUserId);
    final notes =
        _progressNotes
            .where((note) => note.workId == workId)
            .toList(growable: false)
          ..sort(
            (first, second) => first.createdAt.compareTo(second.createdAt),
          );
    return List.unmodifiable(notes);
  }

  @override
  Future<bool> canUserAddProgress({
    required String workId,
    required String userId,
  }) async {
    await _simulateNetworkDelay();
    final access = await _technicalWorkAccessSource?.getActorAccess(userId);
    final workIndex = _works.indexWhere((work) => work.id == workId);
    if (access == null || !access.isActive || workIndex == -1) {
      return false;
    }
    final work = _works[workIndex];
    final actorMatchesAssignment =
        work.assignedToUserId == userId ||
        (work.assignedToTeamId != null &&
            access.activeTeamIds.contains(work.assignedToTeamId));
    return access.canAddTechnicalWorkProgress &&
        actorMatchesAssignment &&
        work.status == TechnicalWorkStatus.inProgress;
  }

  @override
  Future<bool> canUserRequestCompletion({
    required String workId,
    required String userId,
  }) async {
    await _simulateNetworkDelay();
    try {
      final work = await _authorizeCompletionRequest(
        workId: workId,
        actorUserId: userId,
      );
      return work.status == TechnicalWorkStatus.inProgress;
    } on TechnicalWorkCompletionNotAllowedException {
      return false;
    }
  }

  @override
  Future<List<TechnicalWorkCompletionRequest>> getCompletionRequests({
    required String workId,
    required String actorUserId,
  }) async {
    await _simulateNetworkDelay();
    await _authorizeDetailRead(workId: workId, actorUserId: actorUserId);
    final requests =
        _completionRequests
            .where((request) => request.workId == workId)
            .toList(growable: false)
          ..sort(
            (first, second) => first.requestedAt.compareTo(second.requestedAt),
          );
    return List.unmodifiable(requests);
  }

  @override
  Future<List<TechnicalWorkCompletionReviewItem>> getPendingCompletionReviews({
    required String actorUserId,
  }) async {
    await _simulateNetworkDelay();
    await _ensureActorCanReviewCompletion(actorUserId);
    final items = <TechnicalWorkCompletionReviewItem>[];
    for (final request in _completionRequests) {
      if (request.decision != TechnicalWorkCompletionDecision.pending) {
        continue;
      }
      final workIndex = _works.indexWhere((work) => work.id == request.workId);
      if (workIndex != -1) {
        items.add(
          TechnicalWorkCompletionReviewItem(
            work: _works[workIndex],
            request: request,
          ),
        );
      }
    }
    items.sort(
      (first, second) =>
          first.request.requestedAt.compareTo(second.request.requestedAt),
    );
    return List.unmodifiable(items);
  }

  @override
  Future<bool> canUserStartTechnicalWork(String userId) async {
    final access = await _technicalWorkAccessSource?.getActorAccess(userId);
    return access?.canStartTechnicalWork ?? false;
  }

  @override
  Future<List<AssignmentTarget>> getAssignmentTargets() async {
    await _simulateNetworkDelay();
    final teamTargets =
        await _teamAssignmentTargetSource?.getActiveTeamTargets() ?? const [];
    return List.unmodifiable([..._individualAssignmentTargets, ...teamTargets]);
  }

  @override
  Future<bool> hasOpenWorkAssignedToTeam(String teamId) async {
    await _simulateNetworkDelay();
    return _works.any((work) => work.assignedToTeamId == teamId && work.isOpen);
  }

  @override
  Future<TechnicalWork> assignWork({
    required String workId,
    required TechnicalWorkPriority priority,
    required AssignmentTarget target,
  }) async {
    await _simulateNetworkDelay();

    final workIndex = _works.indexWhere((work) => work.id == workId);
    if (workIndex == -1) {
      throw StateError('Atanacak teknik iş bulunamadı.');
    }

    final updatedWork = _works[workIndex].copyWith(
      priority: priority,
      status: TechnicalWorkStatus.assigned,
      assignedToUserId: target.type == AssignmentTargetType.engineer
          ? target.id
          : null,
      assignedToTeamId: target.type == AssignmentTargetType.team
          ? target.id
          : null,
    );
    _works[workIndex] = updatedWork;
    return updatedWork;
  }

  @override
  Future<TechnicalWork> startWork({
    required String workId,
    required String actorUserId,
  }) async {
    await _simulateNetworkDelay();
    var workIndex = _works.indexWhere((work) => work.id == workId);
    if (workIndex == -1) {
      throw StateError('Başlatılacak teknik iş bulunamadı.');
    }
    var work = _works[workIndex];
    await _ensureActorCanStartWork(work: work, actorUserId: actorUserId);
    _ensureWorkCanBeStarted(work);

    if (!_startingWorkIds.add(workId)) {
      workIndex = _works.indexWhere((candidate) => candidate.id == workId);
      if (workIndex == -1) {
        throw StateError('Başlatılacak teknik iş bulunamadı.');
      }
      await _ensureActorCanStartWork(
        work: _works[workIndex],
        actorUserId: actorUserId,
      );
      throw const TechnicalWorkAlreadyStartedException();
    }
    try {
      workIndex = _works.indexWhere((candidate) => candidate.id == workId);
      if (workIndex == -1) {
        throw StateError('Başlatılacak teknik iş bulunamadı.');
      }
      work = _works[workIndex];
      await _ensureActorCanStartWork(work: work, actorUserId: actorUserId);
      _ensureWorkCanBeStarted(work);
      final startedAt = _now();
      final updatedWork = work.copyWith(
        status: TechnicalWorkStatus.inProgress,
        startedByUserId: actorUserId,
        startedAt: startedAt,
      );
      _works[workIndex] = updatedWork;
      return updatedWork;
    } finally {
      _startingWorkIds.remove(workId);
    }
  }

  @override
  Future<TechnicalWorkProgressNote> addProgressNote({
    required AddTechnicalWorkProgressRequest request,
    required String actorUserId,
  }) async {
    await _simulateNetworkDelay();
    var work = _findWork(request.workId);
    await _ensureActorCanAddProgress(work: work, actorUserId: actorUserId);
    final content = request.content.trim();
    if (content.isEmpty) {
      throw const TechnicalWorkProgressInvalidInputException();
    }
    if (work.status != TechnicalWorkStatus.inProgress) {
      throw const TechnicalWorkProgressInvalidStateException();
    }

    final submissionKey = '${request.workId}:$actorUserId';
    if (!_progressSubmissionsInFlight.add(submissionKey)) {
      work = _findWork(request.workId);
      await _ensureActorCanAddProgress(work: work, actorUserId: actorUserId);
      throw const TechnicalWorkProgressSubmissionInFlightException();
    }
    try {
      work = _findWork(request.workId);
      await _ensureActorCanAddProgress(work: work, actorUserId: actorUserId);
      if (work.status != TechnicalWorkStatus.inProgress) {
        throw const TechnicalWorkProgressInvalidStateException();
      }
      final note = TechnicalWorkProgressNote(
        id: 'progress-${_nextProgressNoteNumber++}',
        workId: work.id,
        authorUserId: actorUserId,
        content: content,
        createdAt: _now(),
      );
      _progressNotes.add(note);
      return note;
    } finally {
      _progressSubmissionsInFlight.remove(submissionKey);
    }
  }

  @override
  Future<TechnicalWorkCompletionRequest> submitCompletionRequest({
    required SubmitTechnicalWorkCompletionRequest request,
    required String actorUserId,
  }) async {
    await _simulateNetworkDelay();
    var work = await _authorizeCompletionRequest(
      workId: request.workId,
      actorUserId: actorUserId,
    );
    final summary = request.summary.trim();
    if (summary.isEmpty) {
      throw const TechnicalWorkCompletionInvalidInputException();
    }
    if (work.status != TechnicalWorkStatus.inProgress) {
      throw const TechnicalWorkCompletionInvalidStateException();
    }
    if (!_completionRequestWorkIdsInFlight.add(request.workId)) {
      throw const TechnicalWorkCompletionSubmissionInFlightException();
    }
    try {
      work = await _authorizeCompletionRequest(
        workId: request.workId,
        actorUserId: actorUserId,
      );
      if (work.status != TechnicalWorkStatus.inProgress ||
          _completionRequests.any(
            (candidate) =>
                candidate.workId == work.id &&
                candidate.decision == TechnicalWorkCompletionDecision.pending,
          )) {
        throw const TechnicalWorkCompletionInvalidStateException();
      }
      final requestedAt = _now();
      final completionRequest = TechnicalWorkCompletionRequest(
        id: 'completion-${_nextCompletionRequestNumber++}',
        workId: work.id,
        requestedByUserId: actorUserId,
        summary: summary,
        requestedAt: requestedAt,
      );
      _completionRequests.add(completionRequest);
      final workIndex = _works.indexWhere(
        (candidate) => candidate.id == work.id,
      );
      _works[workIndex] = work.copyWith(
        status: TechnicalWorkStatus.awaitingCompletionApproval,
      );
      return completionRequest;
    } finally {
      _completionRequestWorkIdsInFlight.remove(request.workId);
    }
  }

  @override
  Future<TechnicalWorkCompletionRequest> approveCompletionRequest({
    required String requestId,
    required String actorUserId,
  }) {
    return _reviewCompletionRequest(
      requestId: requestId,
      actorUserId: actorUserId,
      decision: TechnicalWorkCompletionDecision.approved,
    );
  }

  @override
  Future<TechnicalWorkCompletionRequest> rejectCompletionRequest({
    required String requestId,
    required String actorUserId,
    required String rejectionReason,
  }) {
    return _reviewCompletionRequest(
      requestId: requestId,
      actorUserId: actorUserId,
      decision: TechnicalWorkCompletionDecision.rejected,
      rejectionReason: rejectionReason,
    );
  }

  Future<TechnicalWorkCompletionRequest> _reviewCompletionRequest({
    required String requestId,
    required String actorUserId,
    required TechnicalWorkCompletionDecision decision,
    String? rejectionReason,
  }) async {
    await _simulateNetworkDelay();
    await _ensureActorCanReviewCompletion(actorUserId);
    final trimmedReason = rejectionReason?.trim();
    if (decision == TechnicalWorkCompletionDecision.rejected &&
        (trimmedReason == null || trimmedReason.isEmpty)) {
      throw const TechnicalWorkCompletionInvalidInputException();
    }
    var requestIndex = _completionRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (requestIndex == -1) {
      throw StateError('Tamamlama talebi bulunamadı.');
    }
    if (_completionRequests[requestIndex].decision !=
        TechnicalWorkCompletionDecision.pending) {
      throw const TechnicalWorkCompletionAlreadyDecidedException();
    }
    if (!_completionReviewRequestIdsInFlight.add(requestId)) {
      throw const TechnicalWorkCompletionAlreadyDecidedException();
    }
    try {
      await _ensureActorCanReviewCompletion(actorUserId);
      requestIndex = _completionRequests.indexWhere(
        (request) => request.id == requestId,
      );
      if (requestIndex == -1 ||
          _completionRequests[requestIndex].decision !=
              TechnicalWorkCompletionDecision.pending) {
        throw const TechnicalWorkCompletionAlreadyDecidedException();
      }
      final request = _completionRequests[requestIndex];
      final workIndex = _works.indexWhere((work) => work.id == request.workId);
      if (workIndex == -1 ||
          _works[workIndex].status !=
              TechnicalWorkStatus.awaitingCompletionApproval) {
        throw const TechnicalWorkCompletionInvalidStateException();
      }
      final reviewedAt = _now();
      final decidedRequest = request.decided(
        decision: decision,
        reviewedByUserId: actorUserId,
        reviewedAt: reviewedAt,
        rejectionReason: trimmedReason,
      );
      _completionRequests[requestIndex] = decidedRequest;
      _works[workIndex] = _works[workIndex].copyWith(
        status: decision == TechnicalWorkCompletionDecision.approved
            ? TechnicalWorkStatus.completed
            : TechnicalWorkStatus.inProgress,
        completedAt: decision == TechnicalWorkCompletionDecision.approved
            ? reviewedAt
            : null,
      );
      return decidedRequest;
    } finally {
      _completionReviewRequestIdsInFlight.remove(requestId);
    }
  }

  Future<void> _ensureActorCanStartWork({
    required TechnicalWork work,
    required String actorUserId,
  }) async {
    final access = await _technicalWorkAccessSource?.getActorAccess(
      actorUserId,
    );
    final actorMatchesAssignment =
        work.assignedToUserId == actorUserId ||
        (work.assignedToTeamId != null &&
            (access?.activeTeamIds.contains(work.assignedToTeamId) ?? false));
    if (access == null ||
        !access.canStartTechnicalWork ||
        !actorMatchesAssignment) {
      throw const TechnicalWorkStartNotAllowedException();
    }
  }

  void _ensureWorkCanBeStarted(TechnicalWork work) {
    if (work.status == TechnicalWorkStatus.inProgress) {
      throw const TechnicalWorkAlreadyStartedException();
    }
    if (work.status != TechnicalWorkStatus.assigned) {
      throw const TechnicalWorkStartNotAllowedException();
    }
  }

  Future<void> _ensureActorCanAddProgress({
    required TechnicalWork work,
    required String actorUserId,
  }) async {
    final access = await _technicalWorkAccessSource?.getActorAccess(
      actorUserId,
    );
    final actorMatchesAssignment =
        work.assignedToUserId == actorUserId ||
        (work.assignedToTeamId != null &&
            (access?.activeTeamIds.contains(work.assignedToTeamId) ?? false));
    if (access == null ||
        !access.canAddTechnicalWorkProgress ||
        !actorMatchesAssignment) {
      throw const TechnicalWorkProgressNotAllowedException();
    }
  }

  Future<TechnicalWork> _authorizeCompletionRequest({
    required String workId,
    required String actorUserId,
  }) async {
    final access = await _technicalWorkAccessSource?.getActorAccess(
      actorUserId,
    );
    final workIndex = _works.indexWhere((work) => work.id == workId);
    if (access == null ||
        !access.isActive ||
        !access.canRequestTechnicalWorkCompletion ||
        workIndex == -1) {
      throw const TechnicalWorkCompletionNotAllowedException();
    }
    final work = _works[workIndex];
    final actorMatchesAssignment =
        work.assignedToUserId == actorUserId ||
        (work.assignedToTeamId != null &&
            access.activeTeamIds.contains(work.assignedToTeamId));
    if (!actorMatchesAssignment) {
      throw const TechnicalWorkCompletionNotAllowedException();
    }
    return work;
  }

  Future<void> _ensureActorCanReviewCompletion(String actorUserId) async {
    final access = await _technicalWorkAccessSource?.getActorAccess(
      actorUserId,
    );
    if (access == null ||
        !access.isActive ||
        !access.canReviewTechnicalWorkCompletion) {
      throw const TechnicalWorkCompletionReviewNotAllowedException();
    }
  }

  Future<TechnicalWork> _authorizeDetailRead({
    required String workId,
    required String actorUserId,
  }) async {
    final access = await _technicalWorkAccessSource?.getActorAccess(
      actorUserId,
    );
    final workIndex = _works.indexWhere((work) => work.id == workId);
    if (access == null || !access.isActive) {
      throw const TechnicalWorkDetailReadNotAllowedException();
    }
    if (workIndex == -1) {
      if (!access.canViewAllTechnicalWork) {
        throw const TechnicalWorkDetailReadNotAllowedException();
      }
      throw StateError('Teknik iş bulunamadı.');
    }
    final work = _works[workIndex];
    final actorMatchesAssignment =
        work.assignedToUserId == actorUserId ||
        (work.assignedToTeamId != null &&
            access.activeTeamIds.contains(work.assignedToTeamId));
    if (!access.canViewAllTechnicalWork && !actorMatchesAssignment) {
      throw const TechnicalWorkDetailReadNotAllowedException();
    }
    return work;
  }

  TechnicalWork _findWork(String workId) {
    return _works.firstWhere(
      (work) => work.id == workId,
      orElse: () => throw StateError('Teknik iş bulunamadı.'),
    );
  }

  @override
  Future<TechnicalWork> createFieldReport({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  }) async {
    await _simulateNetworkDelay();

    final now = DateTime.now();
    final newWork = TechnicalWork(
      id: 'work-${now.millisecondsSinceEpoch}',
      title: request.title,
      location: request.location,
      description: request.description,
      category: request.category,
      status: TechnicalWorkStatus.reported,
      priority: TechnicalWorkPriority.normal,
      createdByUserId: createdByUserId,
      createdAt: now,
    );
    _works.add(newWork);
    return newWork;
  }

  Future<void> _simulateNetworkDelay() async {
    if (delay == Duration.zero) {
      return;
    }

    await Future<void>.delayed(delay);
  }
}
