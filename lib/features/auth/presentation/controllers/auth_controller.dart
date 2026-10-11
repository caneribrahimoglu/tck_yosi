import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/enums/auth_failure.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/auth_service_exception.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/session_auth_service.dart';
import 'auth_status.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;
  AuthStatus _status = AuthStatus.initial;
  AppUser? _currentUser;
  AuthFailure? _failure;
  bool _changingPassword = false;
  int _version = 0;
  Timer? _expiryTimer;

  AuthController({required AuthService authService})
    : _authService = authService {
    if (authService is SessionAuthService) {
      authService.onSessionInvalidated = _invalidateSession;
    }
  }

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  AuthFailure? get failure => _failure;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isChangingPassword => _changingPassword;
  bool get isLoading =>
      _status == AuthStatus.checkingSession ||
      _status == AuthStatus.authenticating ||
      _changingPassword;

  void _invalidateSession() {
    ++_version;
    _expiryTimer?.cancel();
    _currentUser = null;
    _changingPassword = false;
    _failure = AuthFailure.sessionExpired;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _acceptUser(AppUser user) {
    _currentUser = user;
    _status = user.mustChangePassword
        ? AuthStatus.passwordChangeRequired
        : AuthStatus.authenticated;
    _expiryTimer?.cancel();
    final service = _authService;
    if (service is SessionAuthService && service.expiresAt != null) {
      final remaining = service.expiresAt!.difference(DateTime.now());
      _expiryTimer = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        () => unawaited(logout(expired: true)),
      );
    }
  }

  Future<void> initialize() async {
    if (isLoading) return;
    final version = ++_version;
    _failure = null;
    _status = AuthStatus.checkingSession;
    notifyListeners();
    try {
      final user = await _authService.getCurrentUser();
      if (version != _version) return;
      if (user == null || !user.isActive) {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      } else {
        _acceptUser(user);
      }
    } on AuthServiceException catch (error) {
      if (version != _version) return;
      _currentUser = null;
      _failure = error.failure;
      _status = AuthStatus.unauthenticated;
    } catch (_) {
      if (version != _version) return;
      _currentUser = null;
      _failure = AuthFailure.unknown;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    if (isLoading) return false;
    final version = ++_version;
    _expiryTimer?.cancel();
    _currentUser = null;
    _failure = null;
    _status = AuthStatus.authenticating;
    notifyListeners();
    try {
      final result = await _authService.login(
        username: username,
        password: password,
      );
      if (version != _version) return false;
      if (!result.isSuccess) {
        _failure = result.failure;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
      _acceptUser(result.user!);
      notifyListeners();
      return true;
    } catch (_) {
      if (version != _version) return false;
      _failure = AuthFailure.unknown;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final service = _authService;
    if (_changingPassword ||
        _status != AuthStatus.passwordChangeRequired ||
        service is! SessionAuthService) {
      return false;
    }
    final version = _version;
    _changingPassword = true;
    _failure = null;
    notifyListeners();
    try {
      final result = await service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (version != _version) return false;
      _changingPassword = false;
      if (!result.isSuccess) {
        _failure = result.failure;
        notifyListeners();
        return false;
      }
      _acceptUser(result.user!);
      notifyListeners();
      return _status == AuthStatus.authenticated;
    } catch (_) {
      if (version != _version) return false;
      _changingPassword = false;
      _failure = AuthFailure.unknown;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout({bool expired = false}) async {
    ++_version;
    _expiryTimer?.cancel();
    _currentUser = null;
    _changingPassword = false;
    _failure = expired ? AuthFailure.sessionExpired : null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    try {
      await _authService.logout();
    } catch (_) {
      _failure = AuthFailure.unknown;
      notifyListeners();
    }
  }

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    ++_version;
    _expiryTimer?.cancel();
    final service = _authService;
    if (service is SessionAuthService) service.onSessionInvalidated = null;
    super.dispose();
  }
}
