import '../../domain/enums/app_permission.dart';
import '../../domain/enums/auth_failure.dart';
import '../../domain/enums/user_role.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/auth_result.dart';
import '../../domain/services/auth_service.dart';

class FakeAuthService implements AuthService {
  AppUser? _currentUser;

  static const List<_FakeAccount> _accounts = [
    _FakeAccount(
      password: '123456',
      user: AppUser(
        id: 'user-driver-001',
        fullName: 'Ahmet Yılmaz',
        username: 'sofor',
        role: UserRole.driver,
        permissions: {
          AppPermission.viewAssignedVehicle,
          AppPermission.receiveVehicle,
          AppPermission.returnVehicle,
          AppPermission.updateMileage,
          AppPermission.createFuelRecord,
          AppPermission.createFaultReport,
        },
      ),
    ),
    _FakeAccount(
      password: '123456',
      user: AppUser(
        id: 'user-chief-001',
        fullName: 'Ahmet Dulkadir',
        username: 'sef',
        role: UserRole.chief,
        permissions: {
          AppPermission.viewAssignedVehicle,
          AppPermission.viewPersonnel,
          AppPermission.managePersonnel,
          AppPermission.viewReports,
          AppPermission.approveOperations,
          AppPermission.assignTechnicalWork,
          AppPermission.manageTeamPermissions,
        },
      ),
    ),
    _FakeAccount(
      password: '123456',
      user: AppUser(
        id: 'user-engineer-001',
        fullName: 'Zeynep Demir',
        username: 'muhendis',
        role: UserRole.engineer,
        permissions: {
          AppPermission.viewAssignedVehicle,
          AppPermission.createFaultReport,
          AppPermission.viewReports,
          AppPermission.approveOperations,
        },
      ),
    ),
    _FakeAccount(
      password: '123456',
      user: AppUser(
        id: 'user-inactive-001',
        fullName: 'Pasif Kullanıcı',
        username: 'pasif',
        role: UserRole.driver,
        permissions: {},
        isActive: false,
      ),
    ),
  ];

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final normalizedUsername = username.trim().toLowerCase();

    _FakeAccount? matchedAccount;

    for (final account in _accounts) {
      final usernameMatches =
          account.user.username.toLowerCase() == normalizedUsername;

      final passwordMatches = account.password == password;

      if (usernameMatches && passwordMatches) {
        matchedAccount = account;
        break;
      }
    }

    if (matchedAccount == null) {
      return const AuthResult.failure(AuthFailure.invalidCredentials);
    }

    if (!matchedAccount.user.isActive) {
      return const AuthResult.failure(AuthFailure.inactiveAccount);
    }

    _currentUser = matchedAccount.user;

    return AuthResult.success(matchedAccount.user);
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    return _currentUser;
  }
}

class _FakeAccount {
  final AppUser user;
  final String password;

  const _FakeAccount({required this.user, required this.password});
}
