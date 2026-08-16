import '../../../auth/domain/enums/app_permission.dart';
import '../../domain/models/team.dart';
import '../../domain/models/team_candidate.dart';
import '../../domain/models/team_membership.dart';
import '../../domain/policies/team_permission_policy.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/services/effective_permission_resolver.dart';
import '../../domain/services/team_archive_guard.dart';
import '../../domain/errors/archived_team_name_conflict.dart';

class FakeTeamRepository implements TeamRepository {
  final List<Team> _teams;
  final List<TeamMembership> _memberships;
  final List<TeamCandidate> _candidates;
  final Duration delay;
  final TeamArchiveGuard? _archiveGuard;
  int _nextTeamNumber;
  int _nextMembershipNumber;

  FakeTeamRepository({
    List<Team>? teams,
    List<TeamMembership>? memberships,
    List<TeamCandidate>? candidates,
    this.delay = const Duration(milliseconds: 300),
    TeamArchiveGuard? archiveGuard,
  }) : _teams = List.of(teams ?? _initialTeams),
       _memberships = List.of(memberships ?? _initialMemberships),
       _candidates = List.of(candidates ?? _initialCandidates),
       _nextTeamNumber = (teams ?? _initialTeams).length + 1,
       _nextMembershipNumber = (memberships ?? _initialMemberships).length + 1,
       _archiveGuard = archiveGuard;

  static const _initialTeams = [
    Team(
      id: 'team-technical',
      name: 'Teknik Ekip',
      description: 'Teknik saha operasyonlarını yürüten ekip.',
      isActive: true,
      permissions: {
        AppPermission.createFieldReport,
        AppPermission.viewReports,
        AppPermission.startTechnicalWork,
        AppPermission.addTechnicalWorkProgress,
      },
    ),
  ];

  static const _initialMemberships = [
    TeamMembership(
      id: 'membership-001',
      teamId: 'team-technical',
      userId: 'user-engineer-001',
    ),
  ];

  static const _initialCandidates = [
    TeamCandidate(
      userId: 'user-engineer-001',
      fullName: 'Zeynep Demir',
      roleLabel: 'Mühendis',
      isActive: true,
    ),
    TeamCandidate(
      userId: 'user-driver-001',
      fullName: 'Ahmet Yılmaz',
      roleLabel: 'Şoför',
      isActive: true,
    ),
    TeamCandidate(
      userId: 'user-chief-001',
      fullName: 'Ahmet Dulkadir',
      roleLabel: 'Şef',
      isActive: true,
    ),
  ];

  @override
  Future<List<Team>> getTeams() async {
    await _wait();
    return List.unmodifiable(_teams);
  }

  @override
  Future<List<TeamMembership>> getMemberships() async {
    await _wait();
    return List.unmodifiable(_memberships);
  }

  @override
  Future<List<TeamCandidate>> getCandidates() async {
    await _wait();
    return List.unmodifiable(_candidates);
  }

  @override
  Future<Team> createTeam({
    required String name,
    required String description,
    required Set<AppPermission> actorPermissions,
  }) async {
    await _wait();
    _ensureCanManageTeams(actorPermissions);
    final trimmedName = name.trim();
    _ensureUniqueNameForCreate(trimmedName);
    final team = Team(
      id: 'team-${_nextTeamNumber++}',
      name: trimmedName,
      description: description.trim(),
      isActive: true,
      permissions: const {},
    );
    _teams.add(team);
    return team;
  }

  @override
  Future<Team> updateTeam({
    required String teamId,
    required String name,
    required String description,
    required Set<AppPermission> actorPermissions,
  }) async {
    await _wait();
    _ensureCanManageTeams(actorPermissions);
    _ensureTeamIsMutable(teamId);
    final trimmedName = name.trim();
    _ensureUniqueName(trimmedName, excludingTeamId: teamId);
    return _replaceTeam(
      teamId,
      (team) =>
          team.copyWith(name: trimmedName, description: description.trim()),
    );
  }

  @override
  Future<Team> setTeamActive({
    required String teamId,
    required bool isActive,
    required Set<AppPermission> actorPermissions,
  }) async {
    await _wait();
    _ensureCanManageTeams(actorPermissions);
    _ensureTeamIsMutable(teamId);
    return _replaceTeam(teamId, (team) => team.copyWith(isActive: isActive));
  }

  @override
  Future<Team> archiveTeam({
    required String teamId,
    required Set<AppPermission> actorPermissions,
  }) async {
    await _wait();
    _ensureCanManageTeams(actorPermissions);
    final team = _findTeam(teamId);
    if (team.isArchived) {
      return team;
    }
    if (await _archiveGuard?.hasOpenTechnicalWork(teamId) ?? false) {
      throw StateError('Açık teknik işi bulunan ekip arşivlenemez.');
    }
    return _replaceTeam(
      teamId,
      (current) => current.copyWith(isActive: false, isArchived: true),
    );
  }

  @override
  Future<Team> restoreTeam({
    required String teamId,
    required Set<AppPermission> actorPermissions,
  }) async {
    await _wait();
    _ensureCanManageTeams(actorPermissions);
    final team = _findTeam(teamId);
    if (!team.isArchived) {
      throw StateError('Yalnızca arşivlenmiş ekip geri yüklenebilir.');
    }
    _ensureNoNonArchivedNameConflict(team.name, excludingTeamId: team.id);
    return _replaceTeam(
      teamId,
      (current) => current.copyWith(isArchived: false, isActive: false),
    );
  }

  @override
  Future<TeamMembership> addMember({
    required String teamId,
    required String userId,
    required Set<AppPermission> actorPermissions,
  }) async {
    await _wait();
    _ensureCanManageTeams(actorPermissions);
    _ensureTeamIsMutable(teamId);
    if (!_candidates.any(
      (candidate) => candidate.userId == userId && candidate.isActive,
    )) {
      throw StateError('Aktif kullanıcı bulunamadı.');
    }
    if (_memberships.any(
      (membership) =>
          membership.teamId == teamId && membership.userId == userId,
    )) {
      throw StateError('Kullanıcı zaten bu ekibin üyesi.');
    }
    final membership = TeamMembership(
      id: 'membership-${_nextMembershipNumber++}',
      teamId: teamId,
      userId: userId,
    );
    _memberships.add(membership);
    return membership;
  }

  @override
  Future<void> removeMember({
    required String teamId,
    required String userId,
    required Set<AppPermission> actorPermissions,
  }) async {
    await _wait();
    _ensureCanManageTeams(actorPermissions);
    _ensureTeamIsMutable(teamId);
    _memberships.removeWhere(
      (membership) =>
          membership.teamId == teamId && membership.userId == userId,
    );
  }

  @override
  Future<Team> updatePermissions({
    required String teamId,
    required Set<AppPermission> permissions,
    required Set<AppPermission> actorPermissions,
  }) async {
    await _wait();
    _ensureCanManageTeams(actorPermissions);
    _ensureTeamIsMutable(teamId);
    if (!TeamPermissionPolicy.canGrant(
      requestedPermissions: permissions,
      delegatedPermissions: actorPermissions,
    )) {
      throw StateError('Devredilemeyen bir sistem yetkisi seçildi.');
    }
    return _replaceTeam(
      teamId,
      (team) => team.copyWith(permissions: permissions),
    );
  }

  @override
  Future<Set<AppPermission>> getEffectivePermissions({
    required String userId,
    required Set<AppPermission> directPermissions,
  }) async {
    await _wait();
    return EffectivePermissionResolver.resolve(
      userId: userId,
      directPermissions: directPermissions,
      teams: _teams,
      memberships: _memberships,
    );
  }

  Team _replaceTeam(String teamId, Team Function(Team team) update) {
    final index = _teams.indexWhere((team) => team.id == teamId);
    if (index == -1) {
      throw StateError('Ekip bulunamadı.');
    }
    final updatedTeam = update(_teams[index]);
    _teams[index] = updatedTeam;
    return updatedTeam;
  }

  Team _findTeam(String teamId) {
    return _teams.firstWhere(
      (team) => team.id == teamId,
      orElse: () => throw StateError('Ekip bulunamadı.'),
    );
  }

  Team _ensureTeamIsMutable(String teamId) {
    final team = _findTeam(teamId);
    if (team.isArchived) {
      throw StateError(
        'Arşivlenmiş ekip değiştirilemez. Önce arşivden geri getirin.',
      );
    }
    return team;
  }

  void _ensureCanManageTeams(Set<AppPermission> actorPermissions) {
    if (!TeamPermissionPolicy.canManageTeams(actorPermissions)) {
      throw StateError('Ekip yönetimi yetkiniz bulunmuyor.');
    }
  }

  void _ensureUniqueName(String name, {String? excludingTeamId}) {
    final normalizedName = _normalizeTeamName(name);
    if (_teams.any(
      (team) =>
          team.id != excludingTeamId &&
          _normalizeTeamName(team.name) == normalizedName,
    )) {
      throw StateError('Bu adla bir ekip zaten bulunuyor.');
    }
  }

  void _ensureUniqueNameForCreate(String name) {
    final normalizedName = _normalizeTeamName(name);
    final matchingTeams = _teams
        .where((team) => _normalizeTeamName(team.name) == normalizedName)
        .toList(growable: false);
    if (matchingTeams.any((team) => !team.isArchived)) {
      throw StateError('Bu adla bir ekip zaten bulunuyor.');
    }
    if (matchingTeams.isEmpty) {
      return;
    }
    final archivedMatch = matchingTeams.first;
    throw ArchivedTeamNameConflict(
      teamId: archivedMatch.id,
      teamName: archivedMatch.name,
    );
  }

  void _ensureNoNonArchivedNameConflict(
    String name, {
    required String excludingTeamId,
  }) {
    final normalizedName = _normalizeTeamName(name);
    if (_teams.any(
      (team) =>
          team.id != excludingTeamId &&
          !team.isArchived &&
          _normalizeTeamName(team.name) == normalizedName,
    )) {
      throw StateError('Bu adla aktif veya pasif bir ekip zaten bulunuyor.');
    }
  }

  String _normalizeTeamName(String name) =>
      name.trim().replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  Future<void> _wait() async {
    if (delay != Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
}
