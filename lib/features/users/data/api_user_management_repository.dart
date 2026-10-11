import '../../auth/data/api_user_parser.dart';
import '../../auth/data/services/api_auth_service.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/enums/user_role.dart';
import '../../auth/domain/models/app_user.dart';
import '../domain/user_management_repository.dart';

class ApiUserManagementRepository implements UserManagementRepository {
  final ApiAuthService api;
  const ApiUserManagementRepository(this.api);

  @override
  Future<List<AppUser>> getUsers() async => List.unmodifiable(
    (await api.requestBusiness('users') as List<dynamic>).map(
      (row) => parseApiUser(row as Map<String, dynamic>),
    ),
  );

  @override
  Future<void> createUser({
    required String fullName,
    required String username,
    required UserRole role,
    required String temporaryPassword,
  }) async {
    await api.requestBusiness(
      'users',
      body: {
        'full_name': fullName,
        'username': username,
        'role': role.name,
        'temporary_password': temporaryPassword,
      },
    );
  }

  @override
  Future<void> setActive(String userId, bool active) async {
    await api.requestBusiness(
      'users/$userId/active',
      body: {'is_active': active},
    );
  }

  @override
  Future<void> updatePermissions(
    String userId,
    Set<AppPermission> permissions,
  ) async {
    await api.requestBusiness(
      'users/$userId/permissions',
      body: {'permissions': permissions.map((p) => p.name).toList()},
    );
  }

  @override
  Future<void> resetPassword(String userId, String temporaryPassword) async {
    await api.requestBusiness(
      'users/$userId/reset-password',
      body: {'temporary_password': temporaryPassword},
    );
  }
}
