import '../../../auth/domain/enums/app_permission.dart';
import '../models/team.dart';
import '../models/team_membership.dart';

class EffectivePermissionResolver {
  EffectivePermissionResolver._();

  static Set<AppPermission> resolve({
    required String userId,
    required Set<AppPermission> directPermissions,
    required Iterable<Team> teams,
    required Iterable<TeamMembership> memberships,
  }) {
    final activeTeamsById = {
      for (final team in teams.where(
        (team) => team.isActive && !team.isArchived,
      ))
        team.id: team,
    };
    final effectivePermissions = Set<AppPermission>.of(directPermissions);

    for (final membership in memberships.where(
      (membership) => membership.userId == userId && membership.isActive,
    )) {
      effectivePermissions.addAll(
        activeTeamsById[membership.teamId]?.permissions ?? const {},
      );
    }

    return Set.unmodifiable(effectivePermissions);
  }
}
