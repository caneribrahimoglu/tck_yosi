import 'package:flutter/foundation.dart';

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
    _workId = workId;
    _userId = userId;
    _status = TechnicalWorkHoldStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final historyFuture = _repository.getHoldHistory(
        workId: workId,
        actorUserId: userId,
      );
      final pauseFuture = _repository.canUserPauseWork(
        workId: workId,
        userId: userId,
      );
      final resumeFuture = _repository.canUserResumeWork(
        workId: workId,
        userId: userId,
      );
      _history = List.unmodifiable(await historyFuture);
      _canPause = await pauseFuture;
      _canResume = await resumeFuture;
      await _resolveNames();
      _status = TechnicalWorkHoldStatus.loaded;
    } catch (_) {
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
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.putWorkOnHold(
        request: PutTechnicalWorkOnHoldRequest(workId: workId, reason: reason),
        actorUserId: userId,
      );
      await _refreshHistory();
      _status = TechnicalWorkHoldStatus.success;
      notifyListeners();
      return true;
    } on TechnicalWorkHoldInvalidInputException {
      _errorMessage = 'Bekleme nedeni boş olamaz.';
    } on TechnicalWorkHoldNotAllowedException {
      _errorMessage = 'Bu işi beklemeye alma yetkiniz yok.';
    } on TechnicalWorkHoldInvalidStateException {
      _errorMessage = 'İşin mevcut durumu beklemeye almaya uygun değil.';
    } on TechnicalWorkHoldTransitionInFlightException {
      _errorMessage = 'İş durumu zaten güncelleniyor.';
    } catch (_) {
      _errorMessage = 'İş beklemeye alınamadı.';
    }
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
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.resumeWork(workId: workId, actorUserId: userId);
      await _refreshHistory();
      _status = TechnicalWorkHoldStatus.success;
      notifyListeners();
      return true;
    } on TechnicalWorkHoldNotAllowedException {
      _errorMessage = 'Bu işe devam etme yetkiniz yok.';
    } on TechnicalWorkHoldInvalidStateException {
      _errorMessage = 'İşin mevcut durumu devam etmeye uygun değil.';
    } on TechnicalWorkHoldTransitionInFlightException {
      _errorMessage = 'İş durumu zaten güncelleniyor.';
    } catch (_) {
      _errorMessage = 'İşe devam edilemedi.';
    }
    _status = TechnicalWorkHoldStatus.failure;
    notifyListeners();
    return false;
  }

  Future<void> _refreshHistory() async {
    final historyFuture = _repository.getHoldHistory(
      workId: _workId!,
      actorUserId: _userId!,
    );
    final pauseFuture = _repository.canUserPauseWork(
      workId: _workId!,
      userId: _userId!,
    );
    final resumeFuture = _repository.canUserResumeWork(
      workId: _workId!,
      userId: _userId!,
    );
    _history = List.unmodifiable(await historyFuture);
    _canPause = await pauseFuture;
    _canResume = await resumeFuture;
    await _resolveNames();
  }

  Future<void> _resolveNames() async {
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
      _userNames = names.userNames;
    } catch (_) {
      // İsim çözümleme operasyon sonucunu değiştirmemelidir.
    }
  }
}
