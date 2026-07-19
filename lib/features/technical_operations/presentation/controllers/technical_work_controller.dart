import 'package:flutter/foundation.dart';

import '../../domain/enums/technical_work_status.dart';
import '../../domain/models/technical_work.dart';
import '../../domain/repositories/technical_work_repository.dart';
import 'technical_work_load_status.dart';

class TechnicalWorkController extends ChangeNotifier {
  final TechnicalWorkRepository _repository;

  TechnicalWorkLoadStatus _status = TechnicalWorkLoadStatus.initial;

  List<TechnicalWork> _allWorks = const [];
  List<TechnicalWork> _assignedWorks = const [];
  String? _errorMessage;

  TechnicalWorkController({required TechnicalWorkRepository repository})
    : _repository = repository;

  TechnicalWorkLoadStatus get status => _status;

  List<TechnicalWork> get allWorks => _allWorks;

  List<TechnicalWork> get assignedWorks => _assignedWorks;

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
      _status = TechnicalWorkLoadStatus.loaded;
    } catch (_) {
      _allWorks = const [];
      _assignedWorks = const [];
      _errorMessage = 'Teknik işler yüklenemedi.';
      _status = TechnicalWorkLoadStatus.failure;
    }

    notifyListeners();
  }
}
