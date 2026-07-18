import 'package:flutter/foundation.dart';

import '../../domain/enums/auth_failure.dart';
import '../../domain/models/app_user.dart';
import '../../domain/services/auth_service.dart';
import 'auth_status.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  AppUser? _currentUser;
  AuthFailure? _failure;

  AuthController({required AuthService authService})
    : _authService = authService;

  AuthStatus get status => _status;

  AppUser? get currentUser => _currentUser;

  AuthFailure? get failure => _failure;

  bool get isAuthenticated {
    return _status == AuthStatus.authenticated;
  }

  bool get isLoading {
    return _status == AuthStatus.checkingSession ||
        _status == AuthStatus.authenticating;
  }

  Future<void> initialize() async {
    _failure = null;
    _status = AuthStatus.checkingSession;
    notifyListeners();

    final currentUser = await _authService.getCurrentUser();

    if (currentUser == null) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    } else {
      _currentUser = currentUser;
      _status = AuthStatus.authenticated;
    }

    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    if (_status == AuthStatus.authenticating) {
      return false;
    }

    _failure = null;
    _status = AuthStatus.authenticating;
    notifyListeners();

    final result = await _authService.login(
      username: username,
      password: password,
    );

    if (!result.isSuccess) {
      _currentUser = null;
      _failure = result.failure;
      _status = AuthStatus.unauthenticated;
      notifyListeners();

      return false;
    }

    _currentUser = result.user;
    _status = AuthStatus.authenticated;
    notifyListeners();

    return true;
  }

  Future<void> logout() async {
    await _authService.logout();

    _currentUser = null;
    _failure = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearFailure() {
    if (_failure == null) {
      return;
    }

    _failure = null;
    notifyListeners();
  }
}
