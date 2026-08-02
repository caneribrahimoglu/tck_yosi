import 'package:flutter/foundation.dart';
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

  String? get errorMessage => _errorMessage;

  Future<void> submit({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  }) async {
    if (_status == FieldReportSubmissionStatus.submitting) {
      return;
    }

    _errorMessage = null;
    _createdWork = null;
    _status = FieldReportSubmissionStatus.submitting;
    notifyListeners();
    try {
      _createdWork = await _repository.createFieldReport(
        request: request,
        createdByUserId: createdByUserId,
      );
      _status = FieldReportSubmissionStatus.success;
    } catch (_) {
      _errorMessage = 'Rapor gönderilemedi.';
      _status = FieldReportSubmissionStatus.failure;
    }
    notifyListeners();
  }
}
