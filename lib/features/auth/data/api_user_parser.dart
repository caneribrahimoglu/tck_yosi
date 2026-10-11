import '../domain/enums/app_permission.dart';
import '../domain/enums/user_role.dart';
import '../domain/models/app_user.dart';

AppUser parseApiUser(Map<String, dynamic> data) => AppUser(
  id: data['id'] as String,
  fullName: data['full_name'] as String,
  username: data['username'] as String,
  role: UserRole.values.byName(data['role'] as String),
  permissions: parseApiPermissions(data['permissions']),
  isActive: data['is_active'] as bool,
  mustChangePassword: data['must_change_password'] as bool,
);

Set<AppPermission> parseApiPermissions(Object? data) => Set.unmodifiable(
  (data as List<dynamic>? ?? const [])
      .whereType<String>()
      .where((name) => AppPermission.values.any((p) => p.name == name))
      .map(AppPermission.values.byName),
);
