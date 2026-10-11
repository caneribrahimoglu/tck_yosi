import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session_store.dart';

class SecureSessionStore implements SessionStore {
  static const _key = 'tck_yosi.auth.session.v1';
  final FlutterSecureStorage _storage;
  const SecureSessionStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}
