import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/auth_failure.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';

void main() {
  late FakeAuthService authService;

  setUp(() {
    authService = FakeAuthService();
  });

  test('doğru bilgilerle şoför girişi başarılı olur', () async {
    final result = await authService.login(
      username: 'sofor',
      password: '123456',
    );

    expect(result.isSuccess, isTrue);
    expect(result.user, isNotNull);
    expect(result.user!.role, UserRole.driver);
    expect(result.user!.hasPermission(AppPermission.createFuelRecord), isTrue);
  });

  test('kullanıcı adı boşluk ve harf farkından etkilenmez', () async {
    final result = await authService.login(
      username: '  SOFOR  ',
      password: '123456',
    );

    expect(result.isSuccess, isTrue);
    expect(result.user!.username, 'sofor');
  });

  test('yanlış parola geçersiz bilgiler hatası döndürür', () async {
    final result = await authService.login(
      username: 'sofor',
      password: 'yanlis-parola',
    );

    expect(result.isSuccess, isFalse);
    expect(result.user, isNull);
    expect(result.failure, AuthFailure.invalidCredentials);
  });

  test('bilinmeyen kullanıcı geçersiz bilgiler hatası döndürür', () async {
    final result = await authService.login(
      username: 'bilinmeyen',
      password: '123456',
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure, AuthFailure.invalidCredentials);
  });

  test('pasif hesap giriş yapamaz', () async {
    final result = await authService.login(
      username: 'pasif',
      password: '123456',
    );

    expect(result.isSuccess, isFalse);
    expect(result.failure, AuthFailure.inactiveAccount);
  });

  test('başarılı girişten sonra mevcut kullanıcı alınabilir', () async {
    await authService.login(username: 'sef', password: '123456');

    final currentUser = await authService.getCurrentUser();

    expect(currentUser, isNotNull);
    expect(currentUser!.username, 'sef');
    expect(currentUser.role, UserRole.chief);
  });

  test('çıkış yapıldığında mevcut kullanıcı temizlenir', () async {
    await authService.login(username: 'muhendis', password: '123456');

    await authService.logout();

    final currentUser = await authService.getCurrentUser();

    expect(currentUser, isNull);
  });
}
