import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/technical_work_repository_capabilities.dart';

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
  String? _currentUserId;
  int _loadGeneration = 0;
  int _sessionGeneration = 0;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _sessionGeneration++;
    super.dispose();
  }

  void resetSession() {
    _loadGeneration++;
    _sessionGeneration++;
    _currentUserId = null;
    _allWorks = const [];
    _assignedWorks = const [];
    _assignmentTargets = const [];
    _userNames = const {};
    _teamNames = const {};
    _canCurrentUserStartTechnicalWork = false;
    _isAssigning = false;
    _startingWorkId = null;
    _startStatus = TechnicalWorkStartStatus.initial;
    _status = TechnicalWorkLoadStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  bool get supportsExecution =>
      _repository is! TechnicalWorkRepositoryCapabilities ||
      (_repository as TechnicalWorkRepositoryCapabilities).supportsExecution;
  bool get supportsCompletion =>
      _repository is! TechnicalWorkRepositoryCapabilities ||
      (_repository as TechnicalWorkRepositoryCapabilities).supportsCompletion;
  bool get supportsCompletionRequests =>
      _repository is! TechnicalWorkRepositoryCapabilities ||
      (_repository as TechnicalWorkRepositoryCapabilities)
          .supportsCompletionRequests;

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
    if (_status == TechnicalWorkLoadStatus.loading &&
        _currentUserId == userId) {
      return;
    }
    final generation = ++_loadGeneration;
    _currentUserId = userId;
    _status = TechnicalWorkLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        _repository.getAllWorks(),
        _repository.getAssignedWorks(userId),
        _repository.canUserStartTechnicalWork(userId),
      ]);
      if (_disposed || generation != _loadGeneration) return;
      _allWorks = List.unmodifiable(results[0] as List<TechnicalWork>);
      _assignedWorks = List.unmodifiable(results[1] as List<TechnicalWork>);
      _canCurrentUserStartTechnicalWork = results[2] as bool;
      await _refreshParticipantNames();
      final targets = await _repository.getAssignmentTargets();
      if (_disposed || generation != _loadGeneration) return;
      _assignmentTargets = List.unmodifiable(targets);
      _status = TechnicalWorkLoadStatus.loaded;
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
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
    final generation = _sessionGeneration;
    _startStatus = TechnicalWorkStartStatus.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedWork = await _repository.startWork(
        workId: workId,
        actorUserId: actorUserId,
      );
      if (_disposed || generation != _sessionGeneration) return false;
      _replaceWorkInState(updatedWork);
      await _refreshParticipantNames();
      _startStatus = TechnicalWorkStartStatus.success;
      return true;
    } on TechnicalWorkAlreadyStartedException {
      if (_disposed || generation != _sessionGeneration) return false;
      _startStatus = TechnicalWorkStartStatus.alreadyStarted;
      _errorMessage = 'İş zaten başlatıldı.';
      await _refreshWorkLists(actorUserId);
      return false;
    } on TechnicalWorkStartNotAllowedException {
      if (_disposed || generation != _sessionGeneration) return false;
      _startStatus = TechnicalWorkStartStatus.failure;
      _errorMessage = 'Bu işi başlatma yetkiniz yok.';
      return false;
    } on ApiException catch (error) {
      if (_disposed || generation != _sessionGeneration) return false;
      _startStatus = TechnicalWorkStartStatus.failure;
      _errorMessage = error.userMessage;
      return false;
    } catch (_) {
      if (_disposed || generation != _sessionGeneration) return false;
      _startStatus = TechnicalWorkStartStatus.failure;
      _errorMessage = 'Teknik iş başlatılamadı.';
      return false;
    } finally {
      if (!_disposed && generation == _sessionGeneration) {
        _startingWorkId = null;
        notifyListeners();
      }
    }
  }

  Future<bool> assignWork({
    required String workId,
    int? expectedRevision,
    required TechnicalWorkPriority priority,
    required AssignmentTarget target,
  }) async {
    if (_isAssigning) {
      return false;
    }

    _isAssigning = true;
    final generation = _sessionGeneration;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedWork = await _repository.assignWork(
        workId: workId,
        expectedRevision: expectedRevision,
        priority: priority,
        target: target,
      );
      if (_disposed || generation != _sessionGeneration) return false;
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
    } on ApiException catch (error) {
      if (_disposed || generation != _sessionGeneration) return false;
      if (error.code == 'work_revision_conflict' && _currentUserId != null) {
        await load(_currentUserId!);
      }
      _errorMessage = error.userMessage;
      return false;
    } catch (_) {
      if (_disposed || generation != _sessionGeneration) return false;
      _errorMessage = 'Teknik iş atanamadı.';
      return false;
    } finally {
      if (!_disposed && generation == _sessionGeneration) {
        _isAssigning = false;
        notifyListeners();
      }
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
    final results = await Future.wait<List<TechnicalWork>>([
      _repository.getAllWorks(),
      _repository.getAssignedWorks(actorUserId),
    ]);
    _allWorks = List.unmodifiable(results[0]);
    _assignedWorks = List.unmodifiable(results[1]);
    await _refreshParticipantNames();
  }

  Future<void> _refreshParticipantNames() async {
    final generation = _loadGeneration;
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
      if (_disposed || generation != _loadGeneration) return;
      _userNames = names.userNames;
      _teamNames = names.teamNames;
    } catch (_) {
      // İsim çözümleme, operasyon mutasyonunun sonucunu değiştirmemelidir.
    }
  }
}
