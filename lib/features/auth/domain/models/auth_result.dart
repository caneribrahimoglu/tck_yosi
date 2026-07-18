import 'app_user.dart';
import '../enums/auth_failure.dart';

class AuthResult {
  final AppUser? user;
  final AuthFailure? failure;

  const AuthResult._({this.user, this.failure});

  const AuthResult.success(AppUser user) : this._(user: user);

  const AuthResult.failure(AuthFailure failure) : this._(failure: failure);

  bool get isSuccess => user != null;
}
