import '../../../teams/domain/services/team_archive_guard.dart';
import '../../domain/repositories/technical_work_repository.dart';

class TechnicalWorkTeamArchiveGuard implements TeamArchiveGuard {
  final TechnicalWorkRepository Function() _repositoryProvider;

  const TechnicalWorkTeamArchiveGuard({
    required TechnicalWorkRepository Function() repositoryProvider,
  }) : _repositoryProvider = repositoryProvider;

  @override
  Future<bool> hasOpenTechnicalWork(String teamId) {
    return _repositoryProvider().hasOpenWorkAssignedToTeam(teamId);
  }
}
