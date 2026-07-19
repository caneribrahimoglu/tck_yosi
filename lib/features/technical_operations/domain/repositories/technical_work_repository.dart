import '../models/technical_work.dart';

abstract interface class TechnicalWorkRepository {
  Future<List<TechnicalWork>> getAllWorks();

  Future<List<TechnicalWork>> getAssignedWorks(String userId);
}
