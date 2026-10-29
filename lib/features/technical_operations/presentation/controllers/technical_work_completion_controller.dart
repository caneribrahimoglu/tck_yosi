import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';

import '../../domain/errors/technical_work_completion_exception.dart';
import '../../domain/models/submit_technical_work_completion_request.dart';
import '../../domain/models/technical_work_completion_request.dart';
import '../../domain/models/technical_work_completion_review_item.dart';
import '../../domain/repositories/technical_work_participant_name_source.dart';
import '../../domain/repositories/technical_work_repository.dart';
import '../../domain/repositories/technical_work_repository_capabilities.dart';
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
  int _generation = 0;
  int _sessionGeneration = 0;
  int _queueGeneration = 0;
  bool _disposed = false;
  SubmitTechnicalWorkCompletionRequest? _retryRequest;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _sessionGeneration++;
    super.dispose();
  }

  void resetSession() {
    _generation++;
    _sessionGeneration++;
    _queueGeneration++;
    _history = const [];
    _pendingReviews = const [];
    _userNames = const {};
    _workId = null;
    _detailUserId = null;
    _reviewerUserId = null;
    _retryRequest = null;
    _canRequestCompletion = false;
    _busyRequestId = null;
    _isSubmittingRequest = false;
    _errorMessage = null;
    _detailStatus = TechnicalWorkCompletionStatus.initial;
    _queueStatus = TechnicalWorkCompletionStatus.initial;
    notifyListeners();
  }

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
  bool get supportsReview =>
      _repository is! TechnicalWorkRepositoryCapabilities ||
      (_repository as TechnicalWorkRepositoryCapabilities).supportsCompletion;
  bool get isSubmittingRequest => _isSubmittingRequest;
  bool isReviewing(String requestId) => _busyRequestId == requestId;
  bool get isReviewingAny => _busyRequestId != null;
  String? get errorMessage => _errorMessage;
  String? userName(String userId) => _userNames[userId];

  Future<void> loadForWork({
    required String workId,
    required String userId,
  }) async {
    final generation = ++_generation;
    if (_workId != workId || _detailUserId != userId) _retryRequest = null;
    _workId = workId;
    _detailUserId = userId;
    _detailStatus = TechnicalWorkCompletionStatus.loading;
    _errorMessage = null;
    _history = const [];
    _userNames = const {};
    _canRequestCompletion = false;
    _isSubmittingRequest = false;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.getCompletionRequests(workId: workId, actorUserId: userId),
        _repository.canUserRequestCompletion(workId: workId, userId: userId),
      ]);
      if (_disposed || generation != _generation) return;
      _history = List.unmodifiable(
        results[0] as List<TechnicalWorkCompletionRequest>,
      );
      _canRequestCompletion = results[1] as bool;
      await _resolveNames();
      if (_disposed || generation != _generation) return;
      _detailStatus = TechnicalWorkCompletionStatus.loaded;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _history = const [];
      _canRequestCompletion = false;
      _errorMessage = 'Tamamlama geçmişi yüklenemedi.';
      _detailStatus = TechnicalWorkCompletionStatus.failure;
    }
    notifyListeners();
  }

  Future<void> loadPending(String reviewerUserId) async {
    if (!supportsReview) return;
    final session = _sessionGeneration;
    final generation = ++_queueGeneration;
    _reviewerUserId = reviewerUserId;
    _queueStatus = TechnicalWorkCompletionStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final pending = List<TechnicalWorkCompletionReviewItem>.unmodifiable(
        await _repository.getPendingCompletionReviews(
          actorUserId: reviewerUserId,
        ),
      );
      if (_disposed ||
          session != _sessionGeneration ||
          generation != _queueGeneration) {
        return;
      }
      _pendingReviews = pending;
      await _resolveNames();
      if (_disposed ||
          session != _sessionGeneration ||
          generation != _queueGeneration) {
        return;
      }
      _queueStatus = TechnicalWorkCompletionStatus.loaded;
    } catch (_) {
      if (_disposed ||
          session != _sessionGeneration ||
          generation != _queueGeneration) {
        return;
      }
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
    final generation = _generation;
    final previous = _retryRequest;
    final request =
        previous != null &&
            previous.workId == workId &&
            previous.summary == summary
        ? previous
        : SubmitTechnicalWorkCompletionRequest(
            workId: workId,
            summary: summary,
          );
    _retryRequest = request;
    _detailStatus = TechnicalWorkCompletionStatus.submitting;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.submitCompletionRequest(
        request: request,
        actorUserId: userId,
      );
      if (_disposed || generation != _generation) return false;
      _retryRequest = null;
      _history = List.unmodifiable(
        [..._history.where((item) => item.id != result.id), result]
          ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt)),
      );
      _canRequestCompletion = false;
      await _resolveNames();
      if (_disposed || generation != _generation) return false;
      _detailStatus = TechnicalWorkCompletionStatus.success;
      return true;
    } on TechnicalWorkCompletionInvalidInputException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Tamamlama özeti boş olamaz.';
    } on TechnicalWorkCompletionSubmissionInFlightException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Tamamlama talebi zaten gönderiliyor.';
    } on TechnicalWorkCompletionNotAllowedException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Bu iş için tamamlama talebi gönderemezsiniz.';
    } on TechnicalWorkCompletionInvalidStateException {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'İşin mevcut durumu tamamlama talebine uygun değil.';
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return false;
      _errorMessage = error.userMessage;
    } catch (_) {
      if (_disposed || generation != _generation) return false;
      _errorMessage = 'Tamamlama talebi gönderilemedi.';
    } finally {
      if (!_disposed && generation == _generation) {
        _isSubmittingRequest = false;
        if (_detailStatus != TechnicalWorkCompletionStatus.success) {
          _detailStatus = TechnicalWorkCompletionStatus.failure;
        }
        notifyListeners();
      }
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
    _queueGeneration++; // An older queue load cannot resurrect this decision.
    final session = _sessionGeneration;
    _queueStatus = TechnicalWorkCompletionStatus.submitting;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = rejectionReason == null
          ? await _repository.approveCompletionRequest(
              requestId: requestId,
              actorUserId: reviewerUserId,
            )
          : await _repository.rejectCompletionRequest(
              requestId: requestId,
              actorUserId: reviewerUserId,
              rejectionReason: rejectionReason,
            );
      if (_disposed || session != _sessionGeneration) return false;
      _pendingReviews = List.unmodifiable(
        _pendingReviews.where((item) => item.request.id != result.id),
      );
      _history = List.unmodifiable(
        _history.map((item) => item.id == result.id ? result : item),
      );
      // The mutation already succeeded. A failed refresh must not report that
      // the decision failed and invite a duplicate decision.
      await _refreshPendingAfterReview(reviewerUserId, session);
      if (_disposed || session != _sessionGeneration) return false;
      _queueStatus = TechnicalWorkCompletionStatus.success;
      return true;
    } on TechnicalWorkCompletionInvalidInputException {
      if (_disposed || session != _sessionGeneration) return false;
      _errorMessage = 'Ret nedeni boş olamaz.';
    } on TechnicalWorkCompletionAlreadyDecidedException {
      if (_disposed || session != _sessionGeneration) return false;
      _errorMessage = 'Bu tamamlama talebi daha önce karara bağlandı.';
      await _refreshPendingAfterReview(reviewerUserId, session);
    } on TechnicalWorkCompletionReviewNotAllowedException {
      if (_disposed || session != _sessionGeneration) return false;
      _errorMessage = 'Tamamlama taleplerini inceleme yetkiniz yok.';
      _pendingReviews = const [];
    } on TechnicalWorkCompletionInvalidStateException {
      if (_disposed || session != _sessionGeneration) return false;
      _errorMessage = 'İşin durumu değişti; onay kuyruğunu yenileyin.';
      await _refreshPendingAfterReview(reviewerUserId, session);
    } on ApiException catch (error) {
      if (_disposed || session != _sessionGeneration) return false;
      _errorMessage = error.userMessage;
    } catch (_) {
      if (_disposed || session != _sessionGeneration) return false;
      _errorMessage = 'Tamamlama talebi sonuçlandırılamadı.';
    } finally {
      if (!_disposed && session == _sessionGeneration) {
        _busyRequestId = null;
        if (_queueStatus != TechnicalWorkCompletionStatus.success) {
          _queueStatus = TechnicalWorkCompletionStatus.failure;
        }
        notifyListeners();
      }
    }
    return false;
  }

  Future<void> _refreshPendingAfterReview(String reviewer, int session) async {
    final generation = _queueGeneration;
    try {
      final pending = await _repository.getPendingCompletionReviews(
        actorUserId: reviewer,
      );
      if (_disposed ||
          session != _sessionGeneration ||
          generation != _queueGeneration) {
        return;
      }
      _pendingReviews = List.unmodifiable(pending);
      await _resolveNames();
    } on TechnicalWorkCompletionReviewNotAllowedException {
      if (_disposed ||
          session != _sessionGeneration ||
          generation != _queueGeneration) {
        return;
      }
      _pendingReviews = const [];
    } catch (_) {
      // Keep the locally applied confirmed decision; normal reload can retry.
    }
  }

  Future<void> _resolveNames() async {
    final generation = _generation;
    final session = _sessionGeneration;
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
      if (_disposed ||
          generation != _generation ||
          session != _sessionGeneration) {
        return;
      }
      _userNames = names.userNames;
    } catch (_) {
      // İsim çözümleme operasyon sonucunu değiştirmemelidir.
    }
  }
}
