import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/auth_failure.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tck_yosi/features/auth/presentation/controllers/auth_status.dart';

void main() {
  late FakeAuthService authService;
  late AuthController authController;

  setUp(() {
    authService = FakeAuthService();

    authController = AuthController(authService: authService);
  });

  test('controller başlangıçta initial durumundadır', () {
    expect(authController.status, AuthStatus.initial);
    expect(authController.currentUser, isNull);
    expect(authController.failure, isNull);
    expect(authController.isAuthenticated, isFalse);
    expect(authController.isLoading, isFalse);
  });

  test('oturum yoksa initialize unauthenticated durumuna geçer', () async {
    final initializeFuture = authController.initialize();

    expect(authController.status, AuthStatus.checkingSession);
    expect(authController.isLoading, isTrue);

    await initializeFuture;

    expect(authController.status, AuthStatus.unauthenticated);
    expect(authController.currentUser, isNull);
    expect(authController.isLoading, isFalse);
  });

  test('doğru bilgilerle giriş authenticated durumuna geçer', () async {
    await authController.initialize();

    final loginFuture = authController.login(
      username: 'sofor',
      password: '123456',
    );

    expect(authController.status, AuthStatus.authenticating);
    expect(authController.isLoading, isTrue);

    final success = await loginFuture;

    expect(success, isTrue);
    expect(authController.status, AuthStatus.authenticated);
    expect(authController.isAuthenticated, isTrue);
    expect(authController.currentUser, isNotNull);
    expect(authController.currentUser!.role, UserRole.driver);
    expect(authController.failure, isNull);
    expect(authController.isLoading, isFalse);
  });

  test('yanlış bilgiler unauthenticated durumuna döner', () async {
    final success = await authController.login(
      username: 'sofor',
      password: 'yanlis',
    );

    expect(success, isFalse);
    expect(authController.status, AuthStatus.unauthenticated);
    expect(authController.currentUser, isNull);
    expect(authController.failure, AuthFailure.invalidCredentials);
  });

  test('pasif hesap inactiveAccount hatası oluşturur', () async {
    final success = await authController.login(
      username: 'pasif',
      password: '123456',
    );

    expect(success, isFalse);
    expect(authController.status, AuthStatus.unauthenticated);
    expect(authController.failure, AuthFailure.inactiveAccount);
  });

  test('clearFailure mevcut hatayı temizler', () async {
    await authController.login(username: 'sofor', password: 'yanlis');

    expect(authController.failure, isNotNull);

    authController.clearFailure();

    expect(authController.failure, isNull);
  });

  test('çıkış yapıldığında kullanıcı ve hata temizlenir', () async {
    await authController.login(username: 'sef', password: '123456');

    expect(authController.isAuthenticated, isTrue);

    await authController.logout();

    expect(authController.status, AuthStatus.unauthenticated);
    expect(authController.currentUser, isNull);
    expect(authController.failure, isNull);
    expect(authController.isAuthenticated, isFalse);
  });

  test('mevcut oturum varsa initialize kullanıcıyı geri yükler', () async {
    await authService.login(username: 'muhendis', password: '123456');

    await authController.initialize();

    expect(authController.status, AuthStatus.authenticated);
    expect(authController.currentUser, isNotNull);
    expect(authController.currentUser!.role, UserRole.engineer);
  });
}
