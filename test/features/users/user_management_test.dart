import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/core/network/api_exception.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/users/domain/user_management_repository.dart';
import 'package:tck_yosi/features/users/presentation/user_management_controller.dart';
import 'package:tck_yosi/features/users/presentation/user_management_page.dart';

const chief = AppUser(
  id: 'chief-id',
  fullName: 'Test Şef',
  username: 'sef',
  role: UserRole.chief,
  permissions: {
    AppPermission.manageUsers,
    AppPermission.startTechnicalWork,
    AppPermission.manageTeamPermissions,
  },
);
const engineer = AppUser(
  id: 'engineer-id',
  fullName: 'Test Mühendis',
  username: 'muhendis',
  role: UserRole.engineer,
  permissions: {},
  mustChangePassword: true,
);

class UsersFake implements UserManagementRepository {
  List<AppUser> users = [chief, engineer];
  int calls = 0;
  Completer<void>? pending;
  bool fail = false;
  String? createdUsername;
  @override
  Future<List<AppUser>> getUsers() async {
    if (fail) throw const ApiException('network_error');
    return List.unmodifiable(users);
  }

  Future<void> mutation() async {
    calls++;
    await pending?.future;
  }

  @override
  Future<void> createUser({
    required String fullName,
    required String username,
    required UserRole role,
    required String temporaryPassword,
  }) async {
    await mutation();
    createdUsername = username;
    users.add(
      AppUser(
        id: 'new-user',
        fullName: fullName,
        username: username,
        role: role,
        permissions: {},
        mustChangePassword: true,
      ),
    );
  }

  @override
  Future<void> setActive(String userId, bool active) => mutation();
  @override
  Future<void> updatePermissions(
    String userId,
    Set<AppPermission> permissions,
  ) => mutation();
  @override
  Future<void> resetPassword(String userId, String temporaryPassword) =>
      mutation();
}

void main() {
  test(
    'load state and immutable users; protected account and grants',
    () async {
      final repository = UsersFake();
      final c = UserManagementController(repository: repository)
        ..updateActor(chief);
      final states = <UserManagementStatus>[];
      c.addListener(() => states.add(c.status));
      await c.load();
      expect(states, [
        UserManagementStatus.loading,
        UserManagementStatus.loaded,
      ]);
      expect(() => c.users.clear(), throwsUnsupportedError);
      expect(c.canModify(chief), isFalse);
      expect(c.grantablePermissions, {AppPermission.startTechnicalWork});
      expect(
        await c.updatePermissions(engineer, {AppPermission.manageUsers}),
        isFalse,
      );
      expect(await c.setActive(chief, false), isFalse);
      expect(repository.calls, 0);
      c.dispose();
    },
  );

  test('create loading success and duplicate submission guard', () async {
    final repository = UsersFake()..pending = Completer<void>();
    final c = UserManagementController(repository: repository)
      ..updateActor(chief);
    final first = c.createUser(
      fullName: ' Yeni Kullanıcı ',
      username: ' yeni ',
      role: UserRole.engineer,
      temporaryPassword: 'Gecici-Parola-2026',
    );
    expect(c.isProcessing, isTrue);
    expect(
      await c.createUser(
        fullName: 'Yeni Kullanıcı',
        username: 'yeni',
        role: UserRole.engineer,
        temporaryPassword: 'Gecici-Parola-2026',
      ),
      isFalse,
    );
    expect(repository.calls, 1);
    repository.pending!.complete();
    expect(await first, isTrue);
    expect(c.isProcessing, isFalse);
    expect(repository.createdUsername, 'yeni');
    expect(c.users.last.mustChangePassword, isTrue);
    c.dispose();
  });

  test(
    'failure and invalid input do not leak exceptions or call mutation',
    () async {
      final repository = UsersFake()..fail = true;
      final c = UserManagementController(repository: repository)
        ..updateActor(chief);
      await c.load();
      expect(c.status, UserManagementStatus.failure);
      expect(c.errorMessage, contains('Sunucuya ulaşılamadı'));
      expect(
        await c.createUser(
          fullName: 'A',
          username: 'x',
          role: UserRole.chief,
          temporaryPassword: '123456',
        ),
        isFalse,
      );
      expect(repository.calls, 0);
      c.updateActor(engineer);
      expect(await c.setActive(engineer, false), isFalse);
      expect(c.users, isEmpty);
      c.dispose();
    },
  );

  test('late mutation cannot repopulate next actor session', () async {
    final repository = UsersFake()..pending = Completer<void>();
    final c = UserManagementController(repository: repository)
      ..updateActor(chief);
    final result = c.resetPassword(engineer, 'Gecici-Parola-2026');
    c.updateActor(null);
    repository.pending!.complete();
    expect(await result, isFalse);
    expect(c.users, isEmpty);
    c.dispose();
  });

  for (final width in [360.0, 1400.0]) {
    testWidgets('real user management form is responsive at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = UsersFake();
      final c = UserManagementController(repository: repository)
        ..updateActor(chief);
      await tester.pumpWidget(
        MaterialApp(
          home: UserManagementPage(
            currentUser: chief,
            onLogout: () async {},
            controller: c,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Mühendis'), findsOneWidget);
      expect(find.text('engineer-id'), findsNothing);
      await tester.tap(find.text('Kullanıcı Oluştur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Ad soyad gerekli.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'Yeni Kullanıcı',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kullanıcı adı'),
        'yeni',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Geçici parola'),
        'Gecici-Parola-2026',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Kullanıcı'), findsOneWidget);
      expect(repository.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets('permissions and reset password actions use controller', (
    tester,
  ) async {
    final repository = UsersFake();
    final c = UserManagementController(repository: repository)
      ..updateActor(chief);
    await tester.pumpWidget(
      MaterialApp(
        home: UserManagementPage(
          currentUser: chief,
          onLogout: () async {},
          controller: c,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yetkileri Düzenle'));
    await tester.pumpAndSettle();
    expect(find.text('Kullanıcı yönetimi'), findsNothing);
    expect(find.text('Ekip yetkisi yönetimi'), findsNothing);
    await tester.tap(find.text('Teknik işi başlatma'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    await tester.tap(find.text('Geçici Parola'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Geçici parola'),
      'Yeni-Gecici-2026',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
