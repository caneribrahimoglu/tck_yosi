import '../../domain/models/app_user.dart';
import '../../domain/services/app_user_directory.dart';
import '../../domain/services/auth_service.dart';

/// Temporary bridge while business repositories are demo-only. Real identities
/// are never aliased to demo IDs. Old/demo users remain display candidates but
/// are not authenticated active actors in the API session.
class SessionUserDirectory implements AppUserDirectory {
  final AuthService authService;
  final AppUserDirectory demoDirectory;
  final Map<String, AppUser> _knownUsers = {};
  SessionUserDirectory({
    required this.authService,
    required this.demoDirectory,
  });

  AppUser _displayOnly(AppUser user) => AppUser(
    id: user.id,
    fullName: user.fullName,
    username: user.username,
    role: user.role,
    permissions: const {},
    isActive: false,
  );

  @override
  Future<List<AppUser>> getAllUsers() async {
    final current = await authService.getCurrentUser();
    if (current != null) _knownUsers[current.id] = current;
    final users = <String, AppUser>{
      for (final user in await demoDirectory.getAllUsers())
        user.id: _displayOnly(user),
      for (final user in _knownUsers.values) user.id: _displayOnly(user),
    };
    if (current != null) {
      users[current.id] = current.mustChangePassword
          ? _displayOnly(current)
          : current;
    }
    return List.unmodifiable(users.values);
  }

  @override
  Future<AppUser?> findUserById(String userId) async {
    final current = await authService.getCurrentUser();
    if (current != null) {
      _knownUsers[current.id] = current;
      if (current.id == userId) {
        return current.mustChangePassword ? _displayOnly(current) : current;
      }
    }
    final known =
        _knownUsers[userId] ?? await demoDirectory.findUserById(userId);
    return known == null ? null : _displayOnly(known);
  }
}
