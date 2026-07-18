import '../models/app_user.dart';
import '../models/auth_result.dart';

abstract interface class AuthService {
  Future<AuthResult> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<AppUser?> getCurrentUser();
}
