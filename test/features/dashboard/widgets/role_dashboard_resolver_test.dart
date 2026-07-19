import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/dashboard/widgets/role_dashboard_resolver.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';

void main() {
  TechnicalWorkController createTechnicalWorkController() {
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(delay: Duration.zero),
    );

    addTearDown(controller.dispose);

    return controller;
  }

  testWidgets('şoför rolü şoför dashboardunu gösterir', (
    WidgetTester tester,
  ) async {
    const driver = AppUser(
      id: 'driver-test',
      fullName: 'Test Şoför',
      username: 'test.sofor',
      role: UserRole.driver,
      permissions: {
        AppPermission.viewAssignedVehicle,
        AppPermission.receiveVehicle,
        AppPermission.updateMileage,
        AppPermission.createFuelRecord,
        AppPermission.createFaultReport,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoleDashboardResolver(
          currentUser: driver,
          onLogout: () async {},
          technicalWorkController: createTechnicalWorkController(),
        ),
      ),
    );

    expect(find.text('Hoş geldin, Test Şoför'), findsOneWidget);
    expect(find.text('Bugünkü Aracın'), findsOneWidget);
    expect(find.text('Aracı Teslim Al'), findsOneWidget);
    expect(find.text('Yakıt Kaydı'), findsOneWidget);
    expect(find.text('Yönetim Menüsü'), findsNothing);
  });

  testWidgets('mühendis rolü teknik operasyon dashboardunu gösterir', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const engineer = AppUser(
      id: 'user-engineer-001',
      fullName: 'Test Mühendis',
      username: 'test.muhendis',
      role: UserRole.engineer,
      permissions: {
        AppPermission.createFaultReport,
        AppPermission.viewReports,
        AppPermission.approveOperations,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoleDashboardResolver(
          currentUser: engineer,
          onLogout: () async {},
          technicalWorkController: createTechnicalWorkController(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Teknik Operasyonlar'), findsOneWidget);
    expect(find.text('Açık Teknik İşler'), findsOneWidget);
    expect(find.text('Aydınlatma arızası'), findsOneWidget);
    expect(find.text('Hasarlı yön levhası'), findsOneWidget);
    expect(find.text('Bariyer deformasyonu'), findsOneWidget);
    expect(find.text('Saha Bildirimi Oluştur'), findsOneWidget);
    expect(find.text('Teknik Raporlar'), findsOneWidget);
    expect(find.text('Yönetim Menüsü'), findsNothing);
    expect(find.text('Bugünkü Aracın'), findsNothing);
  });

  testWidgets('şef rolü şeflik operasyon dashboardunu gösterir', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const chief = AppUser(
      id: 'user-chief-001',
      fullName: 'Test Şef',
      username: 'test.sef',
      role: UserRole.chief,
      permissions: {
        AppPermission.viewPersonnel,
        AppPermission.managePersonnel,
        AppPermission.viewReports,
        AppPermission.approveOperations,
        AppPermission.assignTechnicalWork,
        AppPermission.manageTeamPermissions,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoleDashboardResolver(
          currentUser: chief,
          onLogout: () async {},
          technicalWorkController: createTechnicalWorkController(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Şeflik Operasyon Merkezi'), findsOneWidget);
    expect(find.text('Açık Operasyonlar'), findsOneWidget);
    expect(find.text('Kritik Olaylar'), findsOneWidget);
    expect(find.text('Atanmamış İşler'), findsOneWidget);
    expect(find.text('Görev ve İş Ata'), findsOneWidget);
    expect(find.text('Yetki Yönetimi'), findsOneWidget);
    expect(find.text('Yol yüzeyinde çökme'), findsNWidgets(2));
    expect(find.text('Ekip Durumu'), findsOneWidget);
    expect(find.text('Onay Bekleyenler'), findsOneWidget);
    expect(find.text('Yönetim Menüsü'), findsNothing);
    expect(find.text('Bugünkü Aracın'), findsNothing);
  });

  testWidgets('yetkisi olmayan şoför yakıt ve arıza butonlarını göremez', (
    WidgetTester tester,
  ) async {
    const driverWithoutFuelPermission = AppUser(
      id: 'driver-without-fuel',
      fullName: 'Yetkisiz Şoför',
      username: 'yetkisiz.sofor',
      role: UserRole.driver,
      permissions: {
        AppPermission.viewAssignedVehicle,
        AppPermission.receiveVehicle,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoleDashboardResolver(
          currentUser: driverWithoutFuelPermission,
          onLogout: () async {},
          technicalWorkController: createTechnicalWorkController(),
        ),
      ),
    );

    expect(find.text('Hoş geldin, Yetkisiz Şoför'), findsOneWidget);
    expect(find.text('Aracı Teslim Al'), findsOneWidget);
    expect(find.text('Kilometre Gir'), findsNothing);
    expect(find.text('Yakıt Kaydı'), findsNothing);
    expect(find.text('Arıza Bildir'), findsNothing);
  });
}
