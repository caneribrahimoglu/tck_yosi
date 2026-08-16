import 'package:flutter/foundation.dart';

import '../../domain/errors/technical_work_completion_exception.dart';
import '../../domain/models/submit_technical_work_completion_request.dart';
import '../../domain/models/technical_work_completion_request.dart';
import '../../domain/models/technical_work_completion_review_item.dart';
import '../../domain/repositories/technical_work_participant_name_source.dart';
import '../../domain/repositories/technical_work_repository.dart';
import 'technical_work_completion_status.dart';

class TechnicalWorkCompletionController extends ChangeNotifier {
  final TechnicalWorkRepository _repository;
  final TechnicalWorkParticipantNameSource _participantNameSource;

  TechnicalWorkCompletionStatus _detailStatus =
      TechnicalWorkCompletionStatus.initial;
  TechnicalWorkCompletionStatus _queueStatus =
      TechnicalWorkCompletionStatus.initial;
  List<TechnicalWorkCompletionRequest> _history = const [];
  List<TechnicalWorkCompletionReviewItem> _pendingReviews = const [];
  Map<String, String> _userNames = const {};
  String? _workId;
  String? _detailUserId;
  String? _reviewerUserId;
  bool _canRequestCompletion = false;
  String? _busyRequestId;
  bool _isSubmittingRequest = false;
  String? _errorMessage;

  TechnicalWorkCompletionController({
    required TechnicalWorkRepository repository,
    required TechnicalWorkParticipantNameSource participantNameSource,
  }) : _repository = repository,
       _participantNameSource = participantNameSource;

  TechnicalWorkCompletionStatus get detailStatus => _detailStatus;
  TechnicalWorkCompletionStatus get queueStatus => _queueStatus;
  List<TechnicalWorkCompletionRequest> get history => _history;
  List<TechnicalWorkCompletionReviewItem> get pendingReviews => _pendingReviews;
  int get pendingCount => _pendingReviews.length;
  bool get canRequestCompletion => _canRequestCompletion;
  bool get isSubmittingRequest => _isSubmittingRequest;
  bool isReviewing(String requestId) => _busyRequestId == requestId;
  bool get isReviewingAny => _busyRequestId != null;
  String? get errorMessage => _errorMessage;
  String? userName(String userId) => _userNames[userId];

  Future<void> loadForWork({
    required String workId,
    required String userId,
  }) async {
    _workId = workId;
    _detailUserId = userId;
    _detailStatus = TechnicalWorkCompletionStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final historyFuture = _repository.getCompletionRequests(
        workId: workId,
        actorUserId: userId,
      );
      final canRequestFuture = _repository.canUserRequestCompletion(
        workId: workId,
        userId: userId,
      );
      _history = List.unmodifiable(await historyFuture);
      _canRequestCompletion = await canRequestFuture;
      await _resolveNames();
      _detailStatus = TechnicalWorkCompletionStatus.loaded;
    } catch (_) {
      _history = const [];
      _canRequestCompletion = false;
      _errorMessage = 'Tamamlama geçmişi yüklenemedi.';
      _detailStatus = TechnicalWorkCompletionStatus.failure;
    }
    notifyListeners();
  }

  Future<void> loadPending(String reviewerUserId) async {
    _reviewerUserId = reviewerUserId;
    _queueStatus = TechnicalWorkCompletionStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _pendingReviews = List.unmodifiable(
        await _repository.getPendingCompletionReviews(
          actorUserId: reviewerUserId,
        ),
      );
      await _resolveNames();
      _queueStatus = TechnicalWorkCompletionStatus.loaded;
    } catch (_) {
      _pendingReviews = const [];
      _errorMessage = 'Tamamlama onayları yüklenemedi.';
      _queueStatus = TechnicalWorkCompletionStatus.failure;
    }
    notifyListeners();
  }

  Future<bool> submit(String summary) async {
    final workId = _workId;
    final userId = _detailUserId;
    if (workId == null || userId == null || _isSubmittingRequest) {
      return false;
    }
    _isSubmittingRequest = true;
    _detailStatus = TechnicalWorkCompletionStatus.submitting;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.submitCompletionRequest(
        request: SubmitTechnicalWorkCompletionRequest(
          workId: workId,
          summary: summary,
        ),
        actorUserId: userId,
      );
      _history = List.unmodifiable(
        await _repository.getCompletionRequests(
          workId: workId,
          actorUserId: userId,
        ),
      );
      _canRequestCompletion = false;
      await _resolveNames();
      _detailStatus = TechnicalWorkCompletionStatus.success;
      return true;
    } on TechnicalWorkCompletionInvalidInputException {
      _errorMessage = 'Tamamlama özeti boş olamaz.';
    } on TechnicalWorkCompletionSubmissionInFlightException {
      _errorMessage = 'Tamamlama talebi zaten gönderiliyor.';
    } on TechnicalWorkCompletionNotAllowedException {
      _errorMessage = 'Bu iş için tamamlama talebi gönderemezsiniz.';
    } on TechnicalWorkCompletionInvalidStateException {
      _errorMessage = 'İşin mevcut durumu tamamlama talebine uygun değil.';
    } catch (_) {
      _errorMessage = 'Tamamlama talebi gönderilemedi.';
    } finally {
      _isSubmittingRequest = false;
      if (_detailStatus != TechnicalWorkCompletionStatus.success) {
        _detailStatus = TechnicalWorkCompletionStatus.failure;
      }
      notifyListeners();
    }
    return false;
  }

  Future<bool> approve(String requestId) {
    return _review(requestId: requestId);
  }

  Future<bool> reject({required String requestId, required String reason}) {
    return _review(requestId: requestId, rejectionReason: reason);
  }

  Future<bool> _review({
    required String requestId,
    String? rejectionReason,
  }) async {
    final reviewerUserId = _reviewerUserId;
    if (reviewerUserId == null || _busyRequestId != null) {
      return false;
    }
    _busyRequestId = requestId;
    _queueStatus = TechnicalWorkCompletionStatus.submitting;
    _errorMessage = null;
    notifyListeners();
    try {
      if (rejectionReason == null) {
        await _repository.approveCompletionRequest(
          requestId: requestId,
          actorUserId: reviewerUserId,
        );
      } else {
        await _repository.rejectCompletionRequest(
          requestId: requestId,
          actorUserId: reviewerUserId,
          rejectionReason: rejectionReason,
        );
      }
      _pendingReviews = List.unmodifiable(
        await _repository.getPendingCompletionReviews(
          actorUserId: reviewerUserId,
        ),
      );
      _queueStatus = TechnicalWorkCompletionStatus.success;
      return true;
    } on TechnicalWorkCompletionInvalidInputException {
      _errorMessage = 'Ret nedeni boş olamaz.';
    } on TechnicalWorkCompletionAlreadyDecidedException {
      _errorMessage = 'Bu tamamlama talebi daha önce karara bağlandı.';
    } on TechnicalWorkCompletionReviewNotAllowedException {
      _errorMessage = 'Tamamlama taleplerini inceleme yetkiniz yok.';
    } catch (_) {
      _errorMessage = 'Tamamlama talebi sonuçlandırılamadı.';
    } finally {
      _busyRequestId = null;
      if (_queueStatus != TechnicalWorkCompletionStatus.success) {
        _queueStatus = TechnicalWorkCompletionStatus.failure;
      }
      notifyListeners();
    }
    return false;
  }

  Future<void> _resolveNames() async {
    final userIds = <String>{
      for (final request in _history) request.requestedByUserId,
      for (final request in _history) ?request.reviewedByUserId,
      for (final item in _pendingReviews) item.request.requestedByUserId,
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
