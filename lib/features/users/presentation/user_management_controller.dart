import 'package:flutter/foundation.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/enums/user_role.dart';
import '../../auth/domain/models/app_user.dart';
import '../domain/user_management_repository.dart';

enum UserManagementStatus { initial, loading, loaded, failure }

class UserManagementController extends ChangeNotifier {
  final UserManagementRepository repository;
  AppUser? _actor;
  UserManagementStatus status = UserManagementStatus.initial;
  List<AppUser> users = const [];
  bool isProcessing = false;
  String? errorMessage;
  int _version = 0;
  bool _disposed = false;

  UserManagementController({required this.repository});

  void updateActor(AppUser? actor) {
    if (_actor?.id != actor?.id) {
      ++_version;
      users = const [];
      status = UserManagementStatus.initial;
      errorMessage = null;
      isProcessing = false;
    }
    _actor = actor;
  }

  bool get canManage =>
      _actor?.hasPermission(AppPermission.manageUsers) ?? false;
  Set<AppPermission> get grantablePermissions => Set.unmodifiable(
    (_actor?.permissions ?? const <AppPermission>{}).difference({
      AppPermission.manageUsers,
      AppPermission.manageTeamPermissions,
    }),
  );
  bool canModify(AppUser user) =>
      canManage &&
      user.id != _actor?.id &&
      {
        UserRole.driver,
        UserRole.engineer,
        UserRole.technician,
        UserRole.cleaningStaff,
      }.contains(user.role);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (status == UserManagementStatus.loading || !canManage) return;
    final version = _version;
    status = UserManagementStatus.loading;
    errorMessage = null;
    _notify();
    try {
      final loaded = await repository.getUsers();
      if (_disposed || version != _version) return;
      users = List.unmodifiable(loaded);
      status = UserManagementStatus.loaded;
    } catch (error) {
      if (_disposed || version != _version) return;
      users = const [];
      status = UserManagementStatus.failure;
      errorMessage = error is ApiException
          ? error.userMessage
          : 'Kullanıcılar yüklenemedi.';
    }
    _notify();
  }

  Future<bool> _run(Future<void> Function() operation) async {
    if (!canManage || isProcessing || _disposed) return false;
    final version = _version;
    isProcessing = true;
    errorMessage = null;
    _notify();
    try {
      await operation();
      final loaded = await repository.getUsers();
      if (_disposed || version != _version) return false;
      users = List.unmodifiable(loaded);
      status = UserManagementStatus.loaded;
      return true;
    } catch (error) {
      if (_disposed || version != _version) return false;
      errorMessage = error is ApiException
          ? error.userMessage
          : 'Kullanıcı işlemi tamamlanamadı.';
      return false;
    } finally {
      if (!_disposed && version == _version) {
        isProcessing = false;
        _notify();
      }
    }
  }

  Future<bool> createUser({
    required String fullName,
    required String username,
    required UserRole role,
    required String temporaryPassword,
  }) {
    if (fullName.trim().length < 2 ||
        !RegExp(r'^[a-zA-Z0-9_.-]{3,50}$').hasMatch(username.trim()) ||
        temporaryPassword.length < 12 ||
        !{
          UserRole.driver,
          UserRole.engineer,
          UserRole.technician,
          UserRole.cleaningStaff,
        }.contains(role)) {
      errorMessage =
          'Ad, kullanıcı adı ve en az 12 karakterlik geçici parolayı kontrol edin.';
      _notify();
      return Future.value(false);
    }
    return _run(
      () => repository.createUser(
        fullName: fullName.trim(),
        username: username.trim(),
        role: role,
        temporaryPassword: temporaryPassword,
      ),
    );
  }

  Future<bool> setActive(AppUser user, bool active) => !canModify(user)
      ? Future.value(false)
      : _run(() => repository.setActive(user.id, active));

  Future<bool> updatePermissions(
    AppUser user,
    Set<AppPermission> permissions,
  ) => !canModify(user) || !grantablePermissions.containsAll(permissions)
      ? Future.value(false)
      : _run(() => repository.updatePermissions(user.id, permissions));

  Future<bool> resetPassword(AppUser user, String password) =>
      !canModify(user) || password.length < 12
      ? Future.value(false)
      : _run(() => repository.resetPassword(user.id, password));

  @override
  void dispose() {
    _disposed = true;
    ++_version;
    super.dispose();
  }
}
