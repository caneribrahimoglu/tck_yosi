import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../../../core/network/api_exception.dart';

import '../../domain/enums/app_permission.dart';
import '../../domain/enums/auth_failure.dart';
import '../../domain/enums/user_role.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/auth_result.dart';
import '../../domain/models/auth_service_exception.dart';
import '../../domain/services/session_auth_service.dart';
import '../session/session_store.dart';

class ApiAuthService implements SessionAuthService {
  final http.Client _client;
  final SessionStore _store;
  final Uri _baseUrl;
  final Duration timeout;
  final DateTime Function() _now;
  String? _token;
  DateTime? _expiresAt;
  bool _restored = false;
  int _version = 0;
  Future<void> _storageTail = Future.value();
  @override
  void Function()? onSessionInvalidated;

  ApiAuthService({
    required http.Client client,
    required SessionStore sessionStore,
    required Uri baseUrl,
    this.timeout = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _client = client,
       _store = sessionStore,
       _baseUrl = baseUrl,
       _now = now ?? DateTime.now;

  @override
  DateTime? get expiresAt => _expiresAt;

  /// Shared authenticated transport. Caller grants are never sent as authority.
  /// Late responses from a previous login cannot enter the current session.
  Future<Object?> requestBusiness(
    String path, {
    Map<String, Object?>? body,
  }) async {
    await _restore();
    if (_token == null || _expiresAt == null || !_expiresAt!.isAfter(_now())) {
      await _invalidate();
      throw const ApiException('session_expired');
    }
    final version = _version;
    try {
      final response = await _request(path, authenticated: true, body: body);
      if (version != _version) throw const ApiException('session_expired');
      if (response.statusCode == 401) {
        await _invalidate();
        throw const ApiException('session_expired');
      }
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) return data;
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      if (detail is Map<String, dynamic>) {
        throw ApiException(detail['code'] as String? ?? 'unknown', detail);
      }
      if (response.statusCode == 403) throw const ApiException('not_allowed');
      if (response.statusCode == 422) throw const ApiException('invalid_input');
      throw const ApiException('unknown');
    } on AuthServiceException {
      throw const ApiException('network_error');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('unknown');
    }
  }

  Future<void> _storeOperation(Future<void> Function() action) {
    final operation = _storageTail.then((_) => action());
    _storageTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<http.Response> _request(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (authenticated) 'Authorization': 'Bearer $_token',
      };
      final uri = _baseUrl.resolve(path);
      // Credentials/tokens must not follow an unexpected server redirect.
      final request = http.Request(body == null ? 'GET' : 'POST', uri)
        ..followRedirects = false
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      throw const AuthServiceException(AuthFailure.networkError);
    } on http.ClientException {
      throw const AuthServiceException(AuthFailure.networkError);
    }
  }

  AppUser _parseUser(Object? json) {
    final data = json as Map<String, dynamic>;
    final permissions = (data['permissions'] as List<dynamic>)
        .whereType<String>()
        .where((name) => AppPermission.values.any((p) => p.name == name))
        .map((name) => AppPermission.values.byName(name));
    final user = AppUser(
      id: data['id'] as String,
      fullName: data['full_name'] as String,
      username: data['username'] as String,
      role: UserRole.values.byName(data['role'] as String),
      permissions: Set.unmodifiable(permissions),
      isActive: data['is_active'] as bool,
      mustChangePassword: data['must_change_password'] as bool,
    );
    if (!user.isActive) {
      throw const AuthServiceException(AuthFailure.inactiveAccount);
    }
    return user;
  }

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final version = ++_version;
    _token = null;
    _expiresAt = null;
    _restored = true;
    try {
      await _storeOperation(_store.delete);
      final response = await _request(
        'auth/login',
        body: {'username': username.trim(), 'password': password},
      );
      if (version != _version) {
        return const AuthResult.failure(AuthFailure.sessionExpired);
      }
      if (response.statusCode == 401) {
        return const AuthResult.failure(AuthFailure.invalidCredentials);
      }
      if (response.statusCode != 200) {
        return const AuthResult.failure(AuthFailure.unknown);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = _parseUser(data['user']);
      final token = data['access_token'] as String;
      final seconds = data['expires_in'] as int;
      if (token.isEmpty || seconds <= 0 || data['token_type'] != 'bearer') {
        return const AuthResult.failure(AuthFailure.unknown);
      }
      final expiry = _now().toUtc().add(Duration(seconds: seconds));
      // Persist only the bearer token and expiry; never the password or trusted
      // permission data. A restored session always revalidates with /me.
      await _storeOperation(
        () => _store.write(
          jsonEncode({'token': token, 'expires_at': expiry.toIso8601String()}),
        ),
      );
      if (version != _version) {
        return const AuthResult.failure(AuthFailure.sessionExpired);
      }
      _token = token;
      _expiresAt = expiry;
      return AuthResult.success(user);
    } on AuthServiceException catch (error) {
      return AuthResult.failure(error.failure);
    } catch (_) {
      return const AuthResult.failure(AuthFailure.unknown);
    }
  }

  Future<void> _restore() async {
    if (_restored) return;
    final version = _version;
    final raw = await _store.read();
    if (version != _version) return;
    _restored = true;
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final token = data['token'] as String;
      final expiry = DateTime.parse(data['expires_at'] as String);
      if (token.isEmpty) throw const FormatException();
      _token = token;
      _expiresAt = expiry;
    } catch (_) {
      await logout();
    }
  }

  Future<void> _invalidate() async {
    onSessionInvalidated?.call();
    await logout();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      await _restore();
      if (_token == null) return null;
      if (_expiresAt == null || !_expiresAt!.isAfter(_now())) {
        await _invalidate();
        return null;
      }
      final version = _version;
      final response = await _request('auth/me', authenticated: true);
      if (version != _version) return null;
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _invalidate();
        return null;
      }
      if (response.statusCode != 200) {
        throw const AuthServiceException(AuthFailure.unknown);
      }
      return _parseUser(jsonDecode(response.body));
    } on AuthServiceException catch (error) {
      if (error.failure == AuthFailure.inactiveAccount) {
        await _invalidate();
        return null;
      }
      rethrow;
    } catch (_) {
      throw const AuthServiceException(AuthFailure.unknown);
    }
  }

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null || _expiresAt == null || !_expiresAt!.isAfter(_now())) {
      await _invalidate();
      return const AuthResult.failure(AuthFailure.sessionExpired);
    }
    final version = _version;
    try {
      final response = await _request(
        'auth/change-password',
        authenticated: true,
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      if (version != _version) {
        return const AuthResult.failure(AuthFailure.sessionExpired);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _invalidate();
        return const AuthResult.failure(AuthFailure.sessionExpired);
      }
      if (response.statusCode == 400 || response.statusCode == 422) {
        return const AuthResult.failure(AuthFailure.invalidPassword);
      }
      if (response.statusCode != 200) {
        return const AuthResult.failure(AuthFailure.unknown);
      }
      final user = await getCurrentUser();
      if (user == null) {
        return const AuthResult.failure(AuthFailure.sessionExpired);
      }
      return AuthResult.success(user);
    } on AuthServiceException catch (error) {
      return AuthResult.failure(error.failure);
    } catch (_) {
      return const AuthResult.failure(AuthFailure.unknown);
    }
  }

  @override
  Future<void> logout() async {
    ++_version;
    _token = null;
    _expiresAt = null;
    _restored = true;
    await _storeOperation(_store.delete);
  }

  void dispose() {
    ++_version;
    onSessionInvalidated = null;
    _client.close();
  }
}
