import 'package:flutter/foundation.dart';

import '../../domain/enums/technical_work_status.dart';
import '../../domain/models/technical_work.dart';
import '../../domain/models/assignment_target.dart';
import '../../domain/enums/technical_work_priority.dart';
import '../../domain/repositories/technical_work_repository.dart';
import 'technical_work_load_status.dart';

class TechnicalWorkController extends ChangeNotifier {
  final TechnicalWorkRepository _repository;

  TechnicalWorkLoadStatus _status = TechnicalWorkLoadStatus.initial;

  List<TechnicalWork> _allWorks = const [];
  List<TechnicalWork> _assignedWorks = const [];
  List<AssignmentTarget> _assignmentTargets = const [];
  bool _isAssigning = false;
  String? _errorMessage;

  TechnicalWorkController({required TechnicalWorkRepository repository})
    : _repository = repository;

  TechnicalWorkLoadStatus get status => _status;

  List<TechnicalWork> get allWorks => _allWorks;

  List<TechnicalWork> get assignedWorks => _assignedWorks;

  List<AssignmentTarget> get assignmentTargets => _assignmentTargets;

  bool get isAssigning => _isAssigning;

  String? get errorMessage => _errorMessage;

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
      final results = await Future.wait<List<TechnicalWork>>([
        _repository.getAllWorks(),
        _repository.getAssignedWorks(userId),
      ]);

      _allWorks = List.unmodifiable(results[0]);
      _assignedWorks = List.unmodifiable(results[1]);
      _assignmentTargets = List.unmodifiable(
        await _repository.getAssignmentTargets(),
      );
      _status = TechnicalWorkLoadStatus.loaded;
    } catch (_) {
      _allWorks = const [];
      _assignedWorks = const [];
      _assignmentTargets = const [];
      _errorMessage = 'Teknik işler yüklenemedi.';
      _status = TechnicalWorkLoadStatus.failure;
    }

    notifyListeners();
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
      return true;
    } catch (_) {
      _errorMessage = 'Teknik iş atanamadı.';
      return false;
    } finally {
      _isAssigning = false;
      notifyListeners();
    }
  }
}
