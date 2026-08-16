import 'package:flutter/foundation.dart';

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
    _loadStatus = TechnicalWorkLoadStatus.loading;
    _submissionStatus = TechnicalWorkProgressSubmissionStatus.initial;
    _currentUserId = userId;
    _errorMessage = null;
    notifyListeners();

    try {
      _work = await _repository.getWorkById(
        workId: workId,
        actorUserId: userId,
      );
      _notes = List.unmodifiable(
        await _repository.getProgressNotes(workId: workId, actorUserId: userId),
      );
      _canAddProgress = await _repository.canUserAddProgress(
        workId: workId,
        userId: userId,
      );
      await _resolveNames();
      _loadStatus = TechnicalWorkLoadStatus.loaded;
    } on TechnicalWorkDetailReadNotAllowedException {
      _setLoadFailure();
    } catch (_) {
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
    _errorMessage = null;
    notifyListeners();
    try {
      final note = await _repository.addProgressNote(
        request: AddTechnicalWorkProgressRequest(
          workId: work.id,
          content: content,
        ),
        actorUserId: currentUserId,
      );
      final updatedNotes = [..._notes, note]
        ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
      _notes = List.unmodifiable(updatedNotes);
      await _resolveNames();
      _submissionStatus = TechnicalWorkProgressSubmissionStatus.success;
      notifyListeners();
      return true;
    } on TechnicalWorkProgressNotAllowedException {
      _errorMessage = 'Bu işe ilerleme kaydı ekleme yetkiniz yok.';
    } on TechnicalWorkProgressInvalidInputException {
      _errorMessage = 'İlerleme notu boş olamaz.';
    } on TechnicalWorkProgressInvalidStateException {
      _errorMessage = 'Yalnız devam eden işe ilerleme kaydı eklenebilir.';
    } on TechnicalWorkProgressSubmissionInFlightException {
      _errorMessage = 'İlerleme kaydı zaten gönderiliyor.';
    } catch (_) {
      _errorMessage = 'İlerleme kaydı eklenemedi.';
    }
    _submissionStatus = TechnicalWorkProgressSubmissionStatus.failure;
    notifyListeners();
    return false;
  }

  Future<void> _resolveNames() async {
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
      _userNames = names.userNames;
      _teamNames = names.teamNames;
    } catch (_) {
      // İsim çözümleme hatası operasyon verisini veya mutasyonu gizlememelidir.
    }
  }
}
