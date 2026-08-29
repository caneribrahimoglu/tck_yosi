import '../models/app_user.dart';

abstract interface class AppUserDirectory {
  Future<AppUser?> findUserById(String userId);

  Future<List<AppUser>> getAllUsers();
}
