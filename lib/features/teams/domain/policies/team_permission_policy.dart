import '../../../auth/domain/enums/app_permission.dart';

class TeamPermissionPolicy {
  TeamPermissionPolicy._();

  static const Set<AppPermission> protectedPermissions = {
    AppPermission.manageUsers,
    AppPermission.manageTeamPermissions,
    AppPermission.viewAllTechnicalWork,
  };

  static bool canManageTeams(Set<AppPermission> actorPermissions) {
    return actorPermissions.contains(AppPermission.manageTeamPermissions);
  }

  static Set<AppPermission> grantablePermissions(
    Set<AppPermission> delegatedPermissions,
  ) {
    if (!canManageTeams(delegatedPermissions)) {
      return const {};
    }
    return Set.unmodifiable(
      delegatedPermissions.difference(protectedPermissions),
    );
  }

  static bool canGrant({
    required Set<AppPermission> requestedPermissions,
    required Set<AppPermission> delegatedPermissions,
  }) {
    return grantablePermissions(
      delegatedPermissions,
    ).containsAll(requestedPermissions);
  }
}
