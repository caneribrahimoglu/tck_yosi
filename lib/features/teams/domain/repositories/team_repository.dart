import '../../../auth/domain/enums/app_permission.dart';
import '../models/team.dart';
import '../models/team_candidate.dart';
import '../models/team_membership.dart';

abstract interface class TeamRepository {
  Future<List<Team>> getTeams();

  Future<List<TeamMembership>> getMemberships();

  Future<List<TeamCandidate>> getCandidates();

  Future<Team> createTeam({
    required String name,
    required String description,
    required Set<AppPermission> actorPermissions,
  });

  Future<Team> updateTeam({
    required String teamId,
    required String name,
    required String description,
    required Set<AppPermission> actorPermissions,
  });

  Future<Team> setTeamActive({
    required String teamId,
    required bool isActive,
    required Set<AppPermission> actorPermissions,
  });

  Future<Team> archiveTeam({
    required String teamId,
    required Set<AppPermission> actorPermissions,
  });

  Future<Team> restoreTeam({
    required String teamId,
    required Set<AppPermission> actorPermissions,
  });

  Future<TeamMembership> addMember({
    required String teamId,
    required String userId,
    required Set<AppPermission> actorPermissions,
  });

  Future<void> removeMember({
    required String teamId,
    required String userId,
    required Set<AppPermission> actorPermissions,
  });

  Future<Team> updatePermissions({
    required String teamId,
    required Set<AppPermission> permissions,
    required Set<AppPermission> actorPermissions,
  });

  Future<Set<AppPermission>> getEffectivePermissions({
    required String userId,
    required Set<AppPermission> directPermissions,
  });
}
