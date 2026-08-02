import 'package:flutter/foundation.dart';

import '../../../auth/domain/enums/app_permission.dart';
import '../../domain/models/team.dart';
import '../../domain/models/team_candidate.dart';
import '../../domain/models/team_membership.dart';
import '../../domain/policies/team_permission_policy.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/errors/archived_team_name_conflict.dart';
import 'team_load_status.dart';
import 'team_list_filter.dart';

class TeamController extends ChangeNotifier {
  final TeamRepository _repository;
  Set<AppPermission> _actorPermissions;

  TeamLoadStatus _status = TeamLoadStatus.initial;
  List<Team> _allTeams = const [];
  List<TeamMembership> _memberships = const [];
  List<TeamCandidate> _candidates = const [];
  String? _selectedTeamId;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;
  ArchivedTeamNameConflict? _archivedNameConflict;
  TeamListFilter _listFilter = TeamListFilter.active;

  TeamController({
    required TeamRepository repository,
    required Set<AppPermission> actorPermissions,
  }) : _repository = repository,
       _actorPermissions = Set.unmodifiable(actorPermissions);

  void updateActorPermissions(Set<AppPermission> actorPermissions) {
    _actorPermissions = Set.unmodifiable(actorPermissions);
  }

  TeamLoadStatus get status => _status;
  List<Team> get teams => List.unmodifiable(
    _allTeams.where(
      (team) => _listFilter == TeamListFilter.archived
          ? team.isArchived
          : !team.isArchived,
    ),
  );
  List<TeamMembership> get memberships => _memberships;
  List<TeamCandidate> get candidates => _candidates;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  ArchivedTeamNameConflict? get archivedNameConflict => _archivedNameConflict;
  TeamListFilter get listFilter => _listFilter;

  Set<AppPermission> get grantablePermissions =>
      TeamPermissionPolicy.grantablePermissions(_actorPermissions);

  Team? get selectedTeam {
    for (final team in _allTeams) {
      if (team.id == _selectedTeamId) {
        return team;
      }
    }
    return null;
  }

  List<TeamMembership> membershipsFor(String teamId) => _memberships
      .where((membership) => membership.teamId == teamId)
      .toList(growable: false);

  bool isMember({required String teamId, required String userId}) {
    return _memberships.any(
      (membership) =>
          membership.teamId == teamId && membership.userId == userId,
    );
  }

  Future<void> load() async {
    if (_status == TeamLoadStatus.loading) {
      return;
    }
    _status = TeamLoadStatus.loading;
    _clearMessages();
    notifyListeners();

    try {
      await _refreshData();
      _status = TeamLoadStatus.loaded;
    } catch (_) {
      _allTeams = const [];
      _memberships = const [];
      _candidates = const [];
      _errorMessage = 'Ekip bilgileri yüklenemedi.';
      _status = TeamLoadStatus.failure;
    }
    notifyListeners();
  }

  void selectTeam(String teamId) {
    if (_selectedTeamId == teamId || !teams.any((team) => team.id == teamId)) {
      return;
    }
    _selectedTeamId = teamId;
    _clearMessages();
    notifyListeners();
  }

  void setListFilter(TeamListFilter filter) {
    if (_listFilter == filter) {
      return;
    }
    _listFilter = filter;
    _selectedTeamId = teams.isEmpty ? null : teams.first.id;
    _clearMessages();
    notifyListeners();
  }

  Future<bool> createTeam({
    required String name,
    required String description,
  }) async {
    if (!_ensureCanManageTeams()) {
      return false;
    }
    final normalizedName = name.trim();
    if (normalizedName.length < 3) {
      return _validationFailure('Ekip adı en az 3 karakter olmalıdır.');
    }
    return _runOperation(
      operation: () async {
        final created = await _repository.createTeam(
          name: normalizedName,
          description: description.trim(),
          actorPermissions: _actorPermissions,
        );
        _listFilter = TeamListFilter.active;
        _selectedTeamId = created.id;
        return created;
      },
      successMessage: 'Ekip başarıyla oluşturuldu.',
    );
  }

  Future<bool> updateTeam({
    required String teamId,
    required String name,
    required String description,
  }) async {
    if (!_ensureCanManageTeams()) {
      return false;
    }
    final normalizedName = name.trim();
    if (normalizedName.length < 3) {
      return _validationFailure('Ekip adı en az 3 karakter olmalıdır.');
    }
    return _runOperation(
      operation: () => _repository.updateTeam(
        teamId: teamId,
        name: normalizedName,
        description: description.trim(),
        actorPermissions: _actorPermissions,
      ),
      successMessage: 'Ekip bilgileri güncellendi.',
    );
  }

  Future<bool> setTeamActive({required String teamId, required bool isActive}) {
    if (!_ensureCanManageTeams()) {
      return Future.value(false);
    }
    return _runOperation(
      operation: () => _repository.setTeamActive(
        teamId: teamId,
        isActive: isActive,
        actorPermissions: _actorPermissions,
      ),
      successMessage: isActive
          ? 'Ekip aktifleştirildi.'
          : 'Ekip pasifleştirildi.',
    );
  }

  Future<bool> archiveTeam(String teamId) {
    if (!_ensureCanManageTeams()) {
      return Future.value(false);
    }
    return _runOperation(
      operation: () => _repository.archiveTeam(
        teamId: teamId,
        actorPermissions: _actorPermissions,
      ),
      successMessage: 'Ekip arşivlendi.',
    );
  }

  Future<bool> restoreTeam(String teamId) {
    if (!_ensureCanManageTeams()) {
      return Future.value(false);
    }
    return _runOperation(
      operation: () async {
        final restored = await _repository.restoreTeam(
          teamId: teamId,
          actorPermissions: _actorPermissions,
        );
        _listFilter = TeamListFilter.active;
        _selectedTeamId = restored.id;
        return restored;
      },
      successMessage:
          'Ekip pasif olarak geri yüklendi. Üyeleri ve yetkileri kontrol edip '
          'ekibi ayrıca aktifleştirin.',
    );
  }

  Future<bool> addMember({required String teamId, required String userId}) {
    if (!_ensureCanManageTeams()) {
      return Future.value(false);
    }
    return _runOperation(
      operation: () => _repository.addMember(
        teamId: teamId,
        userId: userId,
        actorPermissions: _actorPermissions,
      ),
      successMessage: 'Kullanıcı ekibe eklendi.',
    );
  }

  Future<bool> removeMember({required String teamId, required String userId}) {
    if (!_ensureCanManageTeams()) {
      return Future.value(false);
    }
    return _runOperation(
      operation: () => _repository.removeMember(
        teamId: teamId,
        userId: userId,
        actorPermissions: _actorPermissions,
      ),
      successMessage: 'Kullanıcı ekipten çıkarıldı.',
    );
  }

  Future<bool> updatePermissions({
    required String teamId,
    required Set<AppPermission> permissions,
  }) {
    if (!TeamPermissionPolicy.canGrant(
      requestedPermissions: permissions,
      delegatedPermissions: _actorPermissions,
    )) {
      return Future.value(
        _validationFailure('Devredilemeyen bir sistem yetkisi seçildi.'),
      );
    }
    return _runOperation(
      operation: () => _repository.updatePermissions(
        teamId: teamId,
        permissions: permissions,
        actorPermissions: _actorPermissions,
      ),
      successMessage: 'Ekip yetkileri güncellendi.',
    );
  }

  void clearMessages() {
    _clearMessages();
    notifyListeners();
  }

  bool _validationFailure(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
    return false;
  }

  bool _ensureCanManageTeams() {
    if (TeamPermissionPolicy.canManageTeams(_actorPermissions)) {
      return true;
    }
    return _validationFailure('Ekip yönetimi yetkiniz bulunmuyor.');
  }

  Future<bool> _runOperation({
    required Future<Object?> Function() operation,
    required String successMessage,
  }) async {
    if (_isProcessing) {
      return false;
    }
    _isProcessing = true;
    _clearMessages();
    notifyListeners();

    try {
      await operation();
      await _refreshData();
      _successMessage = successMessage;
      return true;
    } catch (error) {
      if (error is ArchivedTeamNameConflict) {
        _archivedNameConflict = error;
        _errorMessage = 'Bu isimde arşivlenmiş bir ekip bulunuyor.';
      } else {
        _errorMessage = error is StateError
            ? error.message
            : 'Ekip işlemi tamamlanamadı.';
      }
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshData() async {
    final results = await Future.wait<Object>([
      _repository.getTeams(),
      _repository.getMemberships(),
      _repository.getCandidates(),
    ]);
    _allTeams = List.unmodifiable(results[0] as List<Team>);
    _memberships = List.unmodifiable(results[1] as List<TeamMembership>);
    _candidates = List.unmodifiable(results[2] as List<TeamCandidate>);
    if (_selectedTeamId == null ||
        !teams.any((team) => team.id == _selectedTeamId)) {
      _selectedTeamId = teams.isEmpty ? null : teams.first.id;
    }
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    _archivedNameConflict = null;
  }
}
