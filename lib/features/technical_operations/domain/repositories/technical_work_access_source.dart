import '../models/technical_work_actor_access.dart';

abstract interface class TechnicalWorkAccessSource {
  Future<TechnicalWorkActorAccess> getActorAccess(String userId);
}
