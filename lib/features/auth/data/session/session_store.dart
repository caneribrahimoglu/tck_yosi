abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Browser sessions stay in memory, avoiding persistent bearer tokens in web
/// storage. A future web deployment can introduce an HttpOnly-cookie backend.
class MemorySessionStore implements SessionStore {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String value) async => _value = value;
  @override
  Future<void> delete() async => _value = null;
}
