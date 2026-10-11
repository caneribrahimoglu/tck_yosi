import '../../../../core/network/api_exception.dart';
import '../../../auth/data/api_user_parser.dart';
import '../../../auth/data/services/api_auth_service.dart';
import '../../../auth/domain/enums/app_permission.dart';
import '../../../auth/domain/enums/user_role.dart';
import '../../domain/errors/archived_team_name_conflict.dart';
import '../../domain/models/team.dart';
import '../../domain/models/team_candidate.dart';
import '../../domain/models/team_membership.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/services/team_archive_guard.dart';

class ApiTeamRepository implements TeamRepository {
  final ApiAuthService api;
  final TeamArchiveGuard archiveGuard;
  const ApiTeamRepository({required this.api, required this.archiveGuard});

  Team _team(Object? row) {
    final data = row as Map<String, dynamic>;
    return Team(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String,
      isActive: data['is_active'] as bool,
      isArchived: data['is_archived'] as bool,
      permissions: parseApiPermissions(data['permissions']),
    );
  }

  TeamMembership _membership(Object? row) {
    final data = row as Map<String, dynamic>;
    return TeamMembership(
      id: data['id'] as String,
      teamId: data['team_id'] as String,
      userId: data['user_id'] as String,
      isActive: data['is_active'] as bool,
    );
  }

  @override
  Future<List<Team>> getTeams() async => List.unmodifiable(
    (await api.requestBusiness('teams') as List<dynamic>).map(_team),
  );

  @override
  Future<List<TeamMembership>> getMemberships() async => List.unmodifiable(
    (await api.requestBusiness('teams/memberships') as List<dynamic>).map(
      _membership,
    ),
  );

  @override
  Future<List<TeamCandidate>> getCandidates() async {
    final rows = await api.requestBusiness('directory') as List<dynamic>;
    return List.unmodifiable(
      rows.map((row) {
        final user = parseApiUser(row as Map<String, dynamic>);
        return TeamCandidate(
          userId: user.id,
          fullName: user.fullName,
          isActive: user.isActive,
          roleLabel: switch (user.role) {
            UserRole.engineer => 'Mühendis',
            UserRole.driver => 'Şoför',
            UserRole.chief => 'Şef',
            UserRole.technician => 'Teknisyen',
            UserRole.cleaningStaff => 'Temizlik Personeli',
            UserRole.director => 'Müdür',
            UserRole.admin => 'Yönetici',
          },
        );
      }),
    );
  }

  Future<Team> _change(String path, Map<String, Object?> body) async {
    try {
      return _team(await api.requestBusiness(path, body: body));
    } on ApiException catch (error) {
      if (error.code == 'archived_team_name') {
        throw ArchivedTeamNameConflict(
          teamId: error.context['team_id'] as String,
          teamName: error.context['team_name'] as String,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Team> createTeam({
    required String name,
    required String description,
    required Set<AppPermission> actorPermissions,
  }) => _change('teams', {'name': name, 'description': description});

  @override
  Future<Team> updateTeam({
    required String teamId,
    required String name,
    required String description,
    required Set<AppPermission> actorPermissions,
  }) => _change('teams/$teamId/details', {
    'name': name,
    'description': description,
  });

  @override
  Future<Team> setTeamActive({
    required String teamId,
    required bool isActive,
    required Set<AppPermission> actorPermissions,
  }) => _change('teams/$teamId/active', {'is_active': isActive});

  @override
  Future<Team> archiveTeam({
    required String teamId,
    required Set<AppPermission> actorPermissions,
  }) async {
    if (await archiveGuard.hasOpenTechnicalWork(teamId)) {
      throw StateError('Açık teknik işi bulunan ekip arşivlenemez.');
    }
    return _change('teams/$teamId/archive', {});
  }

  @override
  Future<Team> restoreTeam({
    required String teamId,
    required Set<AppPermission> actorPermissions,
  }) => _change('teams/$teamId/restore', {});

  @override
  Future<TeamMembership> addMember({
    required String teamId,
    required String userId,
    required Set<AppPermission> actorPermissions,
  }) async => _membership(
    await api.requestBusiness(
      'teams/$teamId/members',
      body: {'user_id': userId},
    ),
  );

  @override
  Future<void> removeMember({
    required String teamId,
    required String userId,
    required Set<AppPermission> actorPermissions,
  }) async {
    await api.requestBusiness('teams/$teamId/members/$userId/remove', body: {});
  }

  @override
  Future<Team> updatePermissions({
    required String teamId,
    required Set<AppPermission> permissions,
    required Set<AppPermission> actorPermissions,
  }) => _change('teams/$teamId/permissions', {
    'permissions': permissions.map((p) => p.name).toList(),
  });

  @override
  Future<Set<AppPermission>> getEffectivePermissions({
    required String userId,
    required Set<AppPermission> directPermissions,
  }) async {
    final current = await api.getCurrentUser();
    if (current == null || current.id != userId) return const {};
    // Current actor and grants are resolved by the server, not the parameters.
    return parseApiPermissions(
      await api.requestBusiness('teams/effective-permissions'),
    );
  }
}
