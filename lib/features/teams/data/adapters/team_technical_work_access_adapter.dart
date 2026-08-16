import '../../../auth/domain/enums/app_permission.dart';
import '../../../auth/domain/services/app_user_directory.dart';
import '../../../technical_operations/domain/models/technical_work_actor_access.dart';
import '../../../technical_operations/domain/repositories/technical_work_access_source.dart';
import '../../domain/repositories/team_repository.dart';

class TeamTechnicalWorkAccessAdapter implements TechnicalWorkAccessSource {
  final TeamRepository _teamRepository;
  final AppUserDirectory _userDirectory;

  const TeamTechnicalWorkAccessAdapter({
    required TeamRepository teamRepository,
    required AppUserDirectory userDirectory,
  }) : _teamRepository = teamRepository,
       _userDirectory = userDirectory;

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    final user = await _userDirectory.findUserById(userId);
    if (user == null || !user.isActive) {
      return const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
      );
    }

    final teamsFuture = _teamRepository.getTeams();
    final membershipsFuture = _teamRepository.getMemberships();
    final permissionsFuture = _teamRepository.getEffectivePermissions(
      userId: userId,
      directPermissions: user.permissions,
    );
    final teams = await teamsFuture;
    final memberships = await membershipsFuture;
    final effectivePermissions = await permissionsFuture;
    final activeTeamIds = teams
        .where((team) => team.isActive && !team.isArchived)
        .map((team) => team.id)
        .toSet();
    final memberTeamIds = memberships
        .where(
          (membership) => membership.userId == userId && membership.isActive,
        )
        .map((membership) => membership.teamId)
        .toSet();

    return TechnicalWorkActorAccess(
      activeTeamIds: Set.unmodifiable(
        activeTeamIds.intersection(memberTeamIds),
      ),
      canStartTechnicalWork: effectivePermissions.contains(
        AppPermission.startTechnicalWork,
      ),
    );
  }
}
