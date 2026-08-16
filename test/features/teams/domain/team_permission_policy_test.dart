import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/teams/domain/models/team.dart';
import 'package:tck_yosi/features/teams/domain/models/team_membership.dart';
import 'package:tck_yosi/features/teams/domain/policies/team_permission_policy.dart';
import 'package:tck_yosi/features/teams/domain/services/effective_permission_resolver.dart';

void main() {
  test('kritik sistem yetkileri grantable listesine girmez', () {
    final grantable = TeamPermissionPolicy.grantablePermissions({
      AppPermission.viewReports,
      AppPermission.manageUsers,
      AppPermission.manageTeamPermissions,
      AppPermission.viewAllTechnicalWork,
    });

    expect(grantable, {AppPermission.viewReports});
  });

  test('ekip yetkisi yönetme yetkisi olmayan kullanıcı grant yapamaz', () {
    final grantable = TeamPermissionPolicy.grantablePermissions({
      AppPermission.viewReports,
    });

    expect(grantable, isEmpty);
  });

  test('etkin yetki doğrudan ve aktif ekip yetkilerinin birleşimidir', () {
    const activeTeam = Team(
      id: 'team-active',
      name: 'Aktif Ekip',
      description: '',
      isActive: true,
      permissions: {AppPermission.viewReports},
    );
    const inactiveTeam = Team(
      id: 'team-inactive',
      name: 'Pasif Ekip',
      description: '',
      isActive: false,
      permissions: {AppPermission.approveOperations},
    );
    const membershipInactiveTeam = Team(
      id: 'team-membership-inactive',
      name: 'Üyeliği Pasif Ekip',
      description: '',
      isActive: true,
      permissions: {AppPermission.assignTechnicalWork},
    );
    const memberships = [
      TeamMembership(id: 'm-1', teamId: 'team-active', userId: 'user-1'),
      TeamMembership(id: 'm-2', teamId: 'team-inactive', userId: 'user-1'),
      TeamMembership(
        id: 'm-3',
        teamId: 'team-membership-inactive',
        userId: 'user-1',
        isActive: false,
      ),
    ];

    final effective = EffectivePermissionResolver.resolve(
      userId: 'user-1',
      directPermissions: {AppPermission.createFieldReport},
      teams: const [activeTeam, inactiveTeam, membershipInactiveTeam],
      memberships: memberships,
    );

    expect(effective, {
      AppPermission.createFieldReport,
      AppPermission.viewReports,
    });
    expect(effective, isNot(contains(AppPermission.approveOperations)));
    expect(effective, isNot(contains(AppPermission.assignTechnicalWork)));
  });
}
