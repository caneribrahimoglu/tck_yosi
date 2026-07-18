import '../enums/app_permission.dart';
import '../enums/user_role.dart';

class AppUser {
  final String id;
  final String fullName;
  final String username;
  final UserRole role;
  final Set<AppPermission> permissions;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    required this.permissions,
    this.isActive = true,
  });

  bool hasPermission(AppPermission permission) {
    return permissions.contains(permission);
  }
}
