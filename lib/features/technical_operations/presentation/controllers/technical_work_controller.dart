import 'package:flutter/foundation.dart';

import '../../domain/enums/technical_work_status.dart';
import '../../domain/models/technical_work.dart';
import '../../domain/models/assignment_target.dart';
import '../../domain/enums/technical_work_priority.dart';
import '../../domain/repositories/technical_work_repository.dart';
import '../../domain/repositories/technical_work_participant_name_source.dart';
import 'technical_work_load_status.dart';
import 'technical_work_start_status.dart';
import '../../domain/errors/technical_work_start_exception.dart';

class TechnicalWorkController extends ChangeNotifier {
  final TechnicalWorkRepository _repository;
  final TechnicalWorkParticipantNameSource? _participantNameSource;

  TechnicalWorkLoadStatus _status = TechnicalWorkLoadStatus.initial;

  List<TechnicalWork> _allWorks = const [];
  List<TechnicalWork> _assignedWorks = const [];
  List<AssignmentTarget> _assignmentTargets = const [];
  bool _isAssigning = false;
  TechnicalWorkStartStatus _startStatus = TechnicalWorkStartStatus.initial;
  String? _startingWorkId;
  bool _canCurrentUserStartTechnicalWork = false;
  Map<String, String> _userNames = const {};
  Map<String, String> _teamNames = const {};
  String? _errorMessage;

  TechnicalWorkController({
    required TechnicalWorkRepository repository,
    TechnicalWorkParticipantNameSource? participantNameSource,
  }) : _repository = repository,
       _participantNameSource = participantNameSource;

  TechnicalWorkLoadStatus get status => _status;

  List<TechnicalWork> get allWorks => _allWorks;

  List<TechnicalWork> get assignedWorks => _assignedWorks;

  List<AssignmentTarget> get assignmentTargets => _assignmentTargets;

  bool get isAssigning => _isAssigning;

  TechnicalWorkStartStatus get startStatus => _startStatus;

  bool get isStartingWork => _startingWorkId != null;

  bool isStarting(String workId) => _startingWorkId == workId;

  bool get canCurrentUserStartTechnicalWork =>
      _canCurrentUserStartTechnicalWork;

  String? get errorMessage => _errorMessage;

  String? assignedToName(TechnicalWork work) {
    final teamId = work.assignedToTeamId;
    if (teamId != null) {
      return _teamNames[teamId];
    }
    final userId = work.assignedToUserId;
    return userId == null ? null : _userNames[userId];
  }

  String? startedByName(TechnicalWork work) {
    final userId = work.startedByUserId;
    return userId == null ? null : _userNames[userId];
  }

  int get openWorkCount {
    return _allWorks.where((work) => work.isOpen).length;
  }

  int get criticalWorkCount {
    return _allWorks.where((work) => work.isOpen && work.isCritical).length;
  }

  int get awaitingInspectionCount {
    return _allWorks
        .where(
          (work) =>
              work.isOpen &&
              work.status == TechnicalWorkStatus.awaitingInspection,
        )
        .length;
  }

  int get unassignedWorkCount {
    return _allWorks.where((work) => work.isOpen && !work.isAssigned).length;
  }

  int get inProgressWorkCount {
    return _allWorks
        .where(
          (work) =>
              work.isOpen && work.status == TechnicalWorkStatus.inProgress,
        )
        .length;
  }

  Future<void> load(String userId) async {
    _status = TechnicalWorkLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final allWorksFuture = _repository.getAllWorks();
      final assignedWorksFuture = _repository.getAssignedWorks(userId);
      final canStartFuture = _repository.canUserStartTechnicalWork(userId);
      _allWorks = List.unmodifiable(await allWorksFuture);
      _assignedWorks = List.unmodifiable(await assignedWorksFuture);
      _canCurrentUserStartTechnicalWork = await canStartFuture;
      await _refreshParticipantNames();
      _assignmentTargets = List.unmodifiable(
        await _repository.getAssignmentTargets(),
      );
      _status = TechnicalWorkLoadStatus.loaded;
    } catch (_) {
      _allWorks = const [];
      _assignedWorks = const [];
      _assignmentTargets = const [];
      _canCurrentUserStartTechnicalWork = false;
      _userNames = const {};
      _teamNames = const {};
      _errorMessage = 'Teknik işler yüklenemedi.';
      _status = TechnicalWorkLoadStatus.failure;
    }

    notifyListeners();
  }

  Future<bool> startWork({
    required String workId,
    required String actorUserId,
  }) async {
    if (_startingWorkId != null) {
      return false;
    }

    _startingWorkId = workId;
    _startStatus = TechnicalWorkStartStatus.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedWork = await _repository.startWork(
        workId: workId,
        actorUserId: actorUserId,
      );
      _replaceWorkInState(updatedWork);
      await _refreshParticipantNames();
      _startStatus = TechnicalWorkStartStatus.success;
      return true;
    } on TechnicalWorkAlreadyStartedException {
      _startStatus = TechnicalWorkStartStatus.alreadyStarted;
      _errorMessage = 'İş zaten başlatıldı.';
      await _refreshWorkLists(actorUserId);
      return false;
    } catch (_) {
      _startStatus = TechnicalWorkStartStatus.failure;
      _errorMessage = 'Teknik iş başlatılamadı.';
      return false;
    } finally {
      _startingWorkId = null;
      notifyListeners();
    }
  }

  Future<bool> assignWork({
    required String workId,
    required TechnicalWorkPriority priority,
    required AssignmentTarget target,
  }) async {
    if (_isAssigning) {
      return false;
    }

    _isAssigning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedWork = await _repository.assignWork(
        workId: workId,
        priority: priority,
        target: target,
      );
      _allWorks = List.unmodifiable([
        for (final work in _allWorks)
          if (work.id == updatedWork.id) updatedWork else work,
      ]);
      _assignedWorks = List.unmodifiable([
        for (final work in _assignedWorks)
          if (work.id == updatedWork.id) updatedWork else work,
      ]);
      await _refreshParticipantNames();
      return true;
    } catch (_) {
      _errorMessage = 'Teknik iş atanamadı.';
      return false;
    } finally {
      _isAssigning = false;
      notifyListeners();
    }
  }

  void _replaceWorkInState(TechnicalWork updatedWork) {
    _allWorks = List.unmodifiable([
      for (final work in _allWorks)
        if (work.id == updatedWork.id) updatedWork else work,
    ]);
    _assignedWorks = List.unmodifiable([
      for (final work in _assignedWorks)
        if (work.id == updatedWork.id) updatedWork else work,
    ]);
  }

  Future<void> _refreshWorkLists(String actorUserId) async {
    final allWorksFuture = _repository.getAllWorks();
    final assignedWorksFuture = _repository.getAssignedWorks(actorUserId);
    _allWorks = List.unmodifiable(await allWorksFuture);
    _assignedWorks = List.unmodifiable(await assignedWorksFuture);
    await _refreshParticipantNames();
  }

  Future<void> _refreshParticipantNames() async {
    final source = _participantNameSource;
    if (source == null) {
      _userNames = const {};
      _teamNames = const {};
      return;
    }
    final userIds = <String>{};
    final teamIds = <String>{};
    for (final work in _allWorks) {
      if (work.assignedToUserId case final userId?) {
        userIds.add(userId);
      }
      if (work.startedByUserId case final userId?) {
        userIds.add(userId);
      }
      if (work.assignedToTeamId case final teamId?) {
        teamIds.add(teamId);
      }
    }
    try {
      final names = await source.resolveNames(
        userIds: userIds,
        teamIds: teamIds,
      );
      _userNames = names.userNames;
      _teamNames = names.teamNames;
    } catch (_) {
      // İsim çözümleme, operasyon mutasyonunun sonucunu değiştirmemelidir.
    }
  }
}
