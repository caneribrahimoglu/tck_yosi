import '../../auth/domain/models/app_user.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/enums/user_role.dart';

abstract interface class UserManagementRepository {
  Future<List<AppUser>> getUsers();
  Future<void> createUser({
    required String fullName,
    required String username,
    required UserRole role,
    required String temporaryPassword,
  });
  Future<void> setActive(String userId, bool active);
  Future<void> updatePermissions(String userId, Set<AppPermission> permissions);
  Future<void> resetPassword(String userId, String temporaryPassword);
}
