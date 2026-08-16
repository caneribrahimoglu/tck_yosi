import '../../../auth/domain/services/app_user_directory.dart';
import '../../../technical_operations/domain/models/technical_work_participant_names.dart';
import '../../../technical_operations/domain/repositories/technical_work_participant_name_source.dart';
import '../../domain/repositories/team_repository.dart';

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
    final teamsFuture = _teamRepository.getTeams();
    final usersFuture = Future.wait(userIds.map(_userDirectory.findUserById));
    final teams = await teamsFuture;
    final users = await usersFuture;

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
