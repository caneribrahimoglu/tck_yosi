import '../models/technical_work_participant_names.dart';

abstract interface class TechnicalWorkParticipantNameSource {
  Future<TechnicalWorkParticipantNames> resolveNames({
    required Set<String> userIds,
    required Set<String> teamIds,
  });
}
