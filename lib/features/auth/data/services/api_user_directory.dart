import '../../domain/models/app_user.dart';
import '../../domain/services/app_user_directory.dart';
import '../api_user_parser.dart';
import 'api_auth_service.dart';

/// Minimal real user directory. Other accounts provide display names only;
/// mutation access still resolves the current session from /me.
class ApiUserDirectory implements AppUserDirectory {
  final ApiAuthService api;
  final AppUserDirectory legacyNames;
  const ApiUserDirectory({required this.api, required this.legacyNames});

  @override
  Future<List<AppUser>> getAllUsers() async {
    final data = await api.requestBusiness('directory') as List<dynamic>;
    return List.unmodifiable(
      data.map((row) => parseApiUser(row as Map<String, dynamic>)),
    );
  }

  @override
  Future<AppUser?> findUserById(String userId) async {
    final current = await api.getCurrentUser();
    if (current == null) return null;
    if (current.id == userId) return current;
    for (final user in await getAllUsers()) {
      if (user.id == userId) return _displayOnly(user);
    }
    // Only old fake operation IDs use this compatibility name fallback. These
    // identities never enter real user pools, memberships, or assignment lists.
    final legacy = await legacyNames.findUserById(userId);
    return legacy == null ? null : _displayOnly(legacy);
  }

  AppUser _displayOnly(AppUser user) => AppUser(
    id: user.id,
    fullName: user.fullName,
    username: user.username,
    role: user.role,
    permissions: const {},
    isActive: false,
  );
}
