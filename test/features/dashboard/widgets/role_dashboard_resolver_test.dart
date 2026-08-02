import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/dashboard/widgets/role_dashboard_resolver.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/shared/widgets/app_button.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_controller.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_assignment_target_adapter.dart';

void main() {
  TechnicalWorkController createTechnicalWorkController() {
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(delay: Duration.zero),
    );

    addTearDown(controller.dispose);

    return controller;
  }

  FieldReportController createFieldReportController() {
    final controller = FieldReportController(
      repository: FakeTechnicalWorkRepository(works: [], delay: Duration.zero),
    );

    addTearDown(controller.dispose);

    return controller;
  }

  TeamController createTeamController() {
    final controller = TeamController(
      repository: FakeTeamRepository(delay: Duration.zero),
      actorPermissions: const {
        AppPermission.managePersonnel,
        AppPermission.viewReports,
        AppPermission.createFieldReport,
        AppPermission.manageTeamPermissions,
      },
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
        AppPermission.createFieldReport,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoleDashboardResolver(
          currentUser: driver,
          onLogout: () async {},
          technicalWorkController: createTechnicalWorkController(),
          fieldReportController: createFieldReportController(),
          teamController: createTeamController(),
        ),
      ),
    );

    expect(find.text('Hoş geldin, Test Şoför'), findsOneWidget);
    expect(find.text('Bugünkü Aracın'), findsOneWidget);
    expect(find.text('Aracı Teslim Al'), findsOneWidget);
    expect(find.text('Yakıt Kaydı'), findsOneWidget);
    expect(find.text('Saha Bildirimi Oluştur'), findsOneWidget);
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
        AppPermission.createFieldReport,
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
          fieldReportController: createFieldReportController(),
          teamController: createTeamController(),
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
        AppPermission.createFieldReport,
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
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: RoleDashboardResolver(
          currentUser: chief,
          onLogout: () async {},
          technicalWorkController: createTechnicalWorkController(),
          fieldReportController: createFieldReportController(),
          teamController: createTeamController(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Şeflik Operasyon Merkezi'), findsOneWidget);
    expect(find.text('Açık Operasyonlar'), findsOneWidget);
    expect(find.text('Kritik Olaylar'), findsOneWidget);
    expect(find.text('Atanmamış İşler'), findsOneWidget);
    expect(find.text('Saha Bildirimi Oluştur'), findsOneWidget);
    expect(find.text('Görev ve İş Ata'), findsOneWidget);
    expect(find.text('Yetki Yönetimi'), findsOneWidget);
    expect(find.text('Yol yüzeyinde çökme'), findsNWidgets(2));
    expect(find.text('Ekip Durumu'), findsOneWidget);
    expect(find.text('Onay Bekleyenler'), findsOneWidget);
    expect(find.text('Yönetim Menüsü'), findsNothing);
    expect(find.text('Bugünkü Aracın'), findsNothing);

    await tester.ensureVisible(find.text('Ekip Yönetimi'));
    await tester.tap(find.text('Ekip Yönetimi'));
    await tester.pumpAndSettle();
    expect(find.text('Ekipler ve Üyelikler'), findsOneWidget);
    expect(find.text('Teknik Ekip'), findsWidgets);
  });

  testWidgets(
    'ekip yönetiminde oluşturulan ekip dönüşte atama dialogunda görünür',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
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
          AppPermission.managePersonnel,
          AppPermission.manageTeamPermissions,
          AppPermission.assignTechnicalWork,
        },
      );
      final teamRepository = FakeTeamRepository(delay: Duration.zero);
      final teamController = TeamController(
        repository: teamRepository,
        actorPermissions: chief.permissions,
      );
      final technicalController = TechnicalWorkController(
        repository: FakeTechnicalWorkRepository(
          delay: Duration.zero,
          teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
            repository: teamRepository,
          ),
        ),
      );
      addTearDown(teamController.dispose);
      addTearDown(technicalController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: RoleDashboardResolver(
            currentUser: chief,
            onLogout: () async {},
            technicalWorkController: technicalController,
            fieldReportController: createFieldReportController(),
            teamController: teamController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ekip Yönetimi'));
      await tester.tap(find.text('Ekip Yönetimi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni Ekip'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Dinamik Saha Ekibi',
      );
      await tester.tap(find.text('Ekibi Oluştur'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('İncele ve Ata'));
      await tester.tap(find.text('İncele ve Ata'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mühendis / Ekip'));
      await tester.pumpAndSettle();

      expect(find.text('Dinamik Saha Ekibi (Ekip)'), findsOneWidget);
    },
  );

  testWidgets('şef atanmamış bildirimi inceleyip ekibe atayabilir', (
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
      permissions: {AppPermission.assignTechnicalWork},
    );
    final teamRepository = FakeTeamRepository(delay: Duration.zero);
    final controller = TechnicalWorkController(
      repository: FakeTechnicalWorkRepository(
        delay: const Duration(milliseconds: 100),
        teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
          repository: teamRepository,
        ),
      ),
    );
    addTearDown(controller.dispose);
    final teamController = TeamController(
      repository: teamRepository,
      actorPermissions: const {},
    );
    addTearDown(teamController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: RoleDashboardResolver(
          currentUser: chief,
          onLogout: () async {},
          technicalWorkController: controller,
          fieldReportController: createFieldReportController(),
          teamController: teamController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('İncele ve Ata'));
    await tester.pumpAndSettle();

    expect(find.text('Saha Bildirimini İncele'), findsOneWidget);
    expect(find.text('Yol yüzeyinde çökme'), findsWidgets);
    expect(find.text('D-100 / Km 38+100'), findsWidgets);

    await tester.tap(find.text('Mühendis / Ekip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teknik Ekip (Ekip)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Görevi Ata'));
    await tester.pump();

    expect(find.text('Atanıyor...'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Atanıyor...'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Vazgeç'))
          .onPressed,
      isNull,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Saha Bildirimini İncele'), findsOneWidget);

    await tester.pumpAndSettle();

    final assignedWork = controller.allWorks.singleWhere(
      (work) => work.id == 'work-004',
    );
    expect(assignedWork.status, TechnicalWorkStatus.assigned);
    expect(assignedWork.assignedToTeamId, 'team-technical');
    expect(find.text('İncele ve Ata'), findsNothing);
    expect(
      find.text('Bildirim önceliklendirildi ve başarıyla atandı.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'yetkisi olmayan şoför yakıt ve saha bildirimi butonlarını göremez',
    (WidgetTester tester) async {
      const driverWithoutPermissions = AppUser(
        id: 'driver-without-permissions',
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
            currentUser: driverWithoutPermissions,
            onLogout: () async {},
            technicalWorkController: createTechnicalWorkController(),
            fieldReportController: createFieldReportController(),
            teamController: createTeamController(),
          ),
        ),
      );

      expect(find.text('Hoş geldin, Yetkisiz Şoför'), findsOneWidget);
      expect(find.text('Aracı Teslim Al'), findsOneWidget);
      expect(find.text('Kilometre Gir'), findsNothing);
      expect(find.text('Yakıt Kaydı'), findsNothing);
      expect(find.text('Saha Bildirimi Oluştur'), findsNothing);
    },
  );
}
