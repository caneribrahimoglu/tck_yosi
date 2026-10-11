import '../enums/auth_failure.dart';

class AuthServiceException implements Exception {
  final AuthFailure failure;
  const AuthServiceException(this.failure);
}
