import '../models/technical_work.dart';
import '../models/create_field_report_request.dart';

abstract interface class TechnicalWorkRepository {
  Future<List<TechnicalWork>> getAllWorks();

  Future<List<TechnicalWork>> getAssignedWorks(String userId);

  Future<TechnicalWork> createFieldReport({
    required CreateFieldReportRequest request,
    required String createdByUserId,
  });
}
