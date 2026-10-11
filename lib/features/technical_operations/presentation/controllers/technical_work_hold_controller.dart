import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';

import '../../domain/errors/technical_work_hold_exception.dart';
import '../../domain/models/put_technical_work_on_hold_request.dart';
import '../../domain/models/technical_work_hold_record.dart';
import '../../domain/repositories/technical_work_participant_name_source.dart';
import '../../domain/repositories/technical_work_repository.dart';
import 'technical_work_hold_status.dart';

class TechnicalWorkHoldController extends ChangeNotifier {
  final TechnicalWorkRepository _repository;
  final TechnicalWorkParticipantNameSource _participantNameSource;

  TechnicalWorkHoldStatus _status = TechnicalWorkHoldStatus.initial;
  List<TechnicalWorkHoldRecord> _history = const [];
  Map<String, String> _userNames = const {};
  String? _workId;
  String? _userId;
  bool _canPause = false;
  bool _canResume = false;
  String? _errorMessage;
  int _generation = 0;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  void resetSession() {
    _generation++;
    _workId = null;
    _userId = null;
    _history = const [];
    _userNames = const {};
    _canPause = false;
    _canResume = false;
    _errorMessage = null;
    _status = TechnicalWorkHoldStatus.initial;
    notifyListeners();
  }

  TechnicalWorkHoldController({
    required TechnicalWorkRepository repository,
    required TechnicalWorkParticipantNameSource participantNameSource,
  }) : _repository = repository,
       _participantNameSource = participantNameSource;

  TechnicalWorkHoldStatus get status => _status;
  List<TechnicalWorkHoldRecord> get history => _history;
  bool get canPause => _canPause;
  bool get canResume => _canResume;
  bool get isSubmitting => _status == TechnicalWorkHoldStatus.submitting;
  String? get errorMessage => _errorMessage;
  String? userName(String userId) => _userNames[userId];

  Future<void> load({required String workId, required String userId}) async {
    final generation = ++_generation;
    _workId = workId;
    _userId = userId;
    _status = TechnicalWorkHoldStatus.loading;
    _errorMessage = null;
    _history = const [];
    _userNames = const {};
    _canPause = false;
    _canResume = false;
    notifyListeners();
    try {
      await _refreshHistory();
      if (_disposed || generation != _generation) return;
      _status = TechnicalWorkHoldStatus.loaded;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _history = const [];
      _canPause = false;
      _canResume = false;
      _errorMessage = 'Bekleme geçmişi yüklenemedi.';
      _status = TechnicalWorkHoldStatus.failure;
    }
    notifyListeners();
  }

  Future<bool> putOnHold(String reason) async {
    final workId = _workId;
    final userId = _userId;
    if (workId == null || userId == null || isSubmitting) {
      return false;
    }
    _status = TechnicalWorkHoldStatus.submitting;
    final generation = _generation;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.putWorkOnHold(
        request: PutTechnicalWorkOnHoldRequest(workId: workId, reason: reason),
        actorUserId: userId,
      );
      if (_disposed || generation != _generation) return false;
      await _refreshHistory();
      if (_disposed || generation != _generation) return false;
      _status = TechnicalWorkHoldStatus.success;
      notifyListeners();
      return true;
    } on TechnicalWorkHoldInvalidInputException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Bekleme nedeni boş olamaz.';
    } on TechnicalWorkHoldNotAllowedException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Bu işi beklemeye alma yetkiniz yok.';
    } on TechnicalWorkHoldInvalidStateException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İşin mevcut durumu beklemeye almaya uygun değil.';
    } on TechnicalWorkHoldTransitionInFlightException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İş durumu zaten güncelleniyor.';
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return false;
      _errorMessage = error.userMessage;
    } catch (_) {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İş beklemeye alınamadı.';
    }
    if (_disposed || generation != _generation) return false;
    _status = TechnicalWorkHoldStatus.failure;
    notifyListeners();
    return false;
  }

  Future<bool> resume() async {
    final workId = _workId;
    final userId = _userId;
    if (workId == null || userId == null || isSubmitting) {
      return false;
    }
    _status = TechnicalWorkHoldStatus.submitting;
    final generation = _generation;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.resumeWork(workId: workId, actorUserId: userId);
      if (_disposed || generation != _generation) return false;
      await _refreshHistory();
      if (_disposed || generation != _generation) return false;
      _status = TechnicalWorkHoldStatus.success;
      notifyListeners();
      return true;
    } on TechnicalWorkHoldNotAllowedException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Bu işe devam etme yetkiniz yok.';
    } on TechnicalWorkHoldInvalidStateException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İşin mevcut durumu devam etmeye uygun değil.';
    } on TechnicalWorkHoldTransitionInFlightException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İş durumu zaten güncelleniyor.';
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return false;
      _errorMessage = error.userMessage;
    } catch (_) {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İşe devam edilemedi.';
    }
    if (_disposed || generation != _generation) return false;
    _status = TechnicalWorkHoldStatus.failure;
    notifyListeners();
    return false;
  }

  Future<void> _refreshHistory() async {
    final generation = _generation;
    final results = await Future.wait<Object>([
      _repository.getHoldHistory(workId: _workId!, actorUserId: _userId!),
      _repository.canUserPauseWork(workId: _workId!, userId: _userId!),
      _repository.canUserResumeWork(workId: _workId!, userId: _userId!),
    ]);
    if (_disposed || generation != _generation) return;
    _history = List.unmodifiable(results[0] as List<TechnicalWorkHoldRecord>);
    _canPause = results[1] as bool;
    _canResume = results[2] as bool;
    await _resolveNames();
  }

  Future<void> _resolveNames() async {
    final generation = _generation;
    final userIds = <String>{
      for (final record in _history) record.heldByUserId,
      for (final record in _history) ?record.resumedByUserId,
    };
    if (userIds.isEmpty) {
      return;
    }
    try {
      final names = await _participantNameSource.resolveNames(
        userIds: userIds,
        teamIds: const {},
      );
      if (_disposed || generation != _generation) return;
      _userNames = names.userNames;
    } catch (_) {
      // İsim çözümleme operasyon sonucunu değiştirmemelidir.
    }
  }
}
