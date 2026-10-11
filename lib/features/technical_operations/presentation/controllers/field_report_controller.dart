import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/models/technical_work.dart';
import '../../domain/repositories/technical_work_repository.dart';
import 'field_report_submission_status.dart';
import '../../domain/models/create_field_report_request.dart';

class FieldReportController extends ChangeNotifier {
  final TechnicalWorkRepository _repository;

  FieldReportController({required TechnicalWorkRepository repository})
    : _repository = repository;

  FieldReportSubmissionStatus _status = FieldReportSubmissionStatus.initial;

  FieldReportSubmissionStatus get status => _status;

  TechnicalWork? _createdWork;

  TechnicalWork? get createdWork => _createdWork;

  String? _errorMessage;
  int _generation = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  void resetSession() {
    _generation++;
    _status = FieldReportSubmissionStatus.initial;
    _createdWork = null;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
  }

  String? get errorMessage => _errorMessage;

  Future<void> submit({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  }) async {
    if (_status == FieldReportSubmissionStatus.submitting) {
      return;
    }
    final generation = _generation;

    _errorMessage = null;
    _createdWork = null;
    _status = FieldReportSubmissionStatus.submitting;
    notifyListeners();
    try {
      final work = await _repository.createFieldReport(
        request: request,
        createdByUserId: createdByUserId,
      );
      if (_disposed || generation != _generation) return;
      _createdWork = work;
      _status = FieldReportSubmissionStatus.success;
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return;
      _errorMessage = error.userMessage;
      _status = FieldReportSubmissionStatus.failure;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _errorMessage = 'Rapor gönderilemedi.';
      _status = FieldReportSubmissionStatus.failure;
    }
    notifyListeners();
  }
}
