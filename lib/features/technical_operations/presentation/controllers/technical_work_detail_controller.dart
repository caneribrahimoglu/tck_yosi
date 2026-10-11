import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/technical_work_repository_capabilities.dart';

import '../../domain/errors/technical_work_progress_exception.dart';
import '../../domain/errors/technical_work_detail_read_exception.dart';
import '../../domain/models/add_technical_work_progress_request.dart';
import '../../domain/models/technical_work.dart';
import '../../domain/models/technical_work_progress_note.dart';
import '../../domain/repositories/technical_work_participant_name_source.dart';
import '../../domain/repositories/technical_work_repository.dart';
import 'technical_work_load_status.dart';
import 'technical_work_progress_submission_status.dart';

class TechnicalWorkDetailController extends ChangeNotifier {
  final TechnicalWorkRepository _repository;
  final TechnicalWorkParticipantNameSource _participantNameSource;

  TechnicalWorkLoadStatus _loadStatus = TechnicalWorkLoadStatus.initial;
  TechnicalWorkProgressSubmissionStatus _submissionStatus =
      TechnicalWorkProgressSubmissionStatus.initial;
  TechnicalWork? _work;
  List<TechnicalWorkProgressNote> _notes = const [];
  Map<String, String> _userNames = const {};
  Map<String, String> _teamNames = const {};
  String? _currentUserId;
  bool _canAddProgress = false;
  String? _errorMessage;
  int _generation = 0;
  bool _disposed = false;
  AddTechnicalWorkProgressRequest? _retryProgressRequest;

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
    _work = null;
    _notes = const [];
    _userNames = const {};
    _teamNames = const {};
    _currentUserId = null;
    _canAddProgress = false;
    _errorMessage = null;
    _retryProgressRequest = null;
    _submissionStatus = TechnicalWorkProgressSubmissionStatus.initial;
    _loadStatus = TechnicalWorkLoadStatus.initial;
    notifyListeners();
  }

  TechnicalWorkDetailController({
    required TechnicalWorkRepository repository,
    required TechnicalWorkParticipantNameSource participantNameSource,
  }) : _repository = repository,
       _participantNameSource = participantNameSource;

  TechnicalWorkLoadStatus get loadStatus => _loadStatus;

  TechnicalWorkProgressSubmissionStatus get submissionStatus =>
      _submissionStatus;

  TechnicalWork? get work => _work;

  List<TechnicalWorkProgressNote> get notes => _notes;

  bool get canAddProgress => _canAddProgress;
  bool get supportsExecution =>
      _repository is! TechnicalWorkRepositoryCapabilities ||
      (_repository as TechnicalWorkRepositoryCapabilities).supportsExecution;

  bool get isSubmitting =>
      _submissionStatus == TechnicalWorkProgressSubmissionStatus.submitting;

  String? get errorMessage => _errorMessage;

  String? get assignedToName {
    final work = _work;
    if (work == null) {
      return null;
    }
    final teamId = work.assignedToTeamId;
    if (teamId != null) {
      return _teamNames[teamId];
    }
    final userId = work.assignedToUserId;
    return userId == null ? null : _userNames[userId];
  }

  String? get creatorName {
    final userId = _work?.createdByUserId;
    return userId == null ? null : _userNames[userId];
  }

  String? get starterName {
    final userId = _work?.startedByUserId;
    return userId == null ? null : _userNames[userId];
  }

  String? authorName(TechnicalWorkProgressNote note) {
    return _userNames[note.authorUserId];
  }

  Future<void> load({required String workId, required String userId}) async {
    if (_currentUserId != userId || _work?.id != workId) {
      _retryProgressRequest = null;
    }
    final generation = ++_generation;
    _work = null;
    _notes = const [];
    _userNames = const {};
    _teamNames = const {};
    _canAddProgress = false;
    _loadStatus = TechnicalWorkLoadStatus.loading;
    _submissionStatus = TechnicalWorkProgressSubmissionStatus.initial;
    _currentUserId = userId;
    _errorMessage = null;
    notifyListeners();

    try {
      final work = await _repository.getWorkById(
        workId: workId,
        actorUserId: userId,
      );
      if (_disposed || generation != _generation) return;
      _work = work;
      final List<TechnicalWorkProgressNote> notes = !supportsExecution
          ? const []
          : List.unmodifiable(
              await _repository.getProgressNotes(
                workId: workId,
                actorUserId: userId,
              ),
            );
      if (_disposed || generation != _generation) return;
      _notes = notes;
      final canAdd =
          supportsExecution &&
          await _repository.canUserAddProgress(workId: workId, userId: userId);
      if (_disposed || generation != _generation) return;
      _canAddProgress = canAdd;
      await _resolveNames();
      if (_disposed || generation != _generation) return;
      _loadStatus = TechnicalWorkLoadStatus.loaded;
    } on TechnicalWorkDetailReadNotAllowedException {
      if (_disposed || generation != _generation) return;
      _setLoadFailure();
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _setLoadFailure();
    }
    notifyListeners();
  }

  void _setLoadFailure() {
    _work = null;
    _notes = const [];
    _canAddProgress = false;
    _errorMessage = 'Teknik iş detayı yüklenemedi.';
    _loadStatus = TechnicalWorkLoadStatus.failure;
  }

  Future<bool> addProgress(String content) async {
    final work = _work;
    final currentUserId = _currentUserId;
    if (work == null || currentUserId == null || isSubmitting) {
      return false;
    }

    _submissionStatus = TechnicalWorkProgressSubmissionStatus.submitting;
    final generation = _generation;
    final previous = _retryProgressRequest;
    final request =
        previous != null &&
            previous.workId == work.id &&
            previous.content == content
        ? previous
        : AddTechnicalWorkProgressRequest(workId: work.id, content: content);
    _retryProgressRequest = request;
    _errorMessage = null;
    notifyListeners();
    try {
      final note = await _repository.addProgressNote(
        request: request,
        actorUserId: currentUserId,
      );
      if (_disposed || generation != _generation) return false;
      _retryProgressRequest = null;
      final updatedNotes = [..._notes.where((old) => old.id != note.id), note]
        ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
      _notes = List.unmodifiable(updatedNotes);
      await _resolveNames();
      if (_disposed || generation != _generation) return false;
      _submissionStatus = TechnicalWorkProgressSubmissionStatus.success;
      notifyListeners();
      return true;
    } on TechnicalWorkProgressNotAllowedException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Bu işe ilerleme kaydı ekleme yetkiniz yok.';
    } on TechnicalWorkProgressInvalidInputException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İlerleme notu boş olamaz.';
    } on TechnicalWorkProgressInvalidStateException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Yalnız devam eden işe ilerleme kaydı eklenebilir.';
    } on TechnicalWorkProgressSubmissionInFlightException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İlerleme kaydı zaten gönderiliyor.';
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return false;
      _errorMessage = error.userMessage;
    } catch (_) {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İlerleme kaydı eklenemedi.';
    }
    if (_disposed || generation != _generation) return false;
    _submissionStatus = TechnicalWorkProgressSubmissionStatus.failure;
    notifyListeners();
    return false;
  }

  Future<void> _resolveNames() async {
    final generation = _generation;
    final work = _work;
    if (work == null) {
      return;
    }
    final userIds = <String>{
      work.createdByUserId,
      ?work.assignedToUserId,
      ?work.startedByUserId,
      for (final note in _notes) note.authorUserId,
    };
    final teamIds = <String>{?work.assignedToTeamId};
    try {
      final names = await _participantNameSource.resolveNames(
        userIds: userIds,
        teamIds: teamIds,
      );
      if (_disposed || generation != _generation) return;
      _userNames = names.userNames;
      _teamNames = names.teamNames;
    } catch (_) {
      // İsim çözümleme hatası operasyon verisini veya mutasyonu gizlememelidir.
    }
  }
}
