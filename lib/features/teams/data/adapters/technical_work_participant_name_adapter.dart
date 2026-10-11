import '../../../auth/domain/services/app_user_directory.dart';
import '../../../technical_operations/domain/models/technical_work_participant_names.dart';
import '../../../technical_operations/domain/repositories/technical_work_participant_name_source.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/models/team.dart';
import '../../../auth/domain/models/app_user.dart';

class TechnicalWorkParticipantNameAdapter
    implements TechnicalWorkParticipantNameSource {
  final TeamRepository _teamRepository;
  final AppUserDirectory _userDirectory;

  const TechnicalWorkParticipantNameAdapter({
    required TeamRepository teamRepository,
    required AppUserDirectory userDirectory,
  }) : _teamRepository = teamRepository,
       _userDirectory = userDirectory;

  @override
  Future<TechnicalWorkParticipantNames> resolveNames({
    required Set<String> userIds,
    required Set<String> teamIds,
  }) async {
    final results = await Future.wait<Object>([
      _teamRepository.getTeams(),
      Future.wait(userIds.map(_userDirectory.findUserById)),
    ]);
    final teams = results[0] as List<Team>;
    final users = results[1] as List<AppUser?>;

    return TechnicalWorkParticipantNames(
      userNames: Map.unmodifiable({
        for (final user in users)
          if (user != null) user.id: user.fullName,
      }),
      teamNames: Map.unmodifiable({
        for (final team in teams)
          if (teamIds.contains(team.id)) team.id: team.name,
      }),
    );
  }
}
