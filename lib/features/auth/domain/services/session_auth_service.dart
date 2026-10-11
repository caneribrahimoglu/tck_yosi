import '../models/auth_result.dart';
import 'auth_service.dart';

/// Additional capabilities of the API-backed session; old demo services remain
/// valid AuthService implementations.
abstract interface class SessionAuthService implements AuthService {
  DateTime? get expiresAt;
  set onSessionInvalidated(void Function()? callback);
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
