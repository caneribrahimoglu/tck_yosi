import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/dashboard/widgets/role_dashboard_resolver.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_controller.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';

void main() {
  testWidgets('izinli şef ana sayfadan gerçek modüllere gider ve geri döner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    var logoutCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: fixture.resolver(onLogout: () async => logoutCalled = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Şeflik Ana Sayfası'), findsOneWidget);
    expect(find.text('Şeflik Operasyon Merkezi'), findsNothing);
    expect(find.text('Operasyon Merkezi'), findsOneWidget);
    expect(find.text('Araç Yönetimi'), findsOneWidget);
    expect(find.text('Personel Yönetimi'), findsOneWidget);
    expect(find.textContaining('Test Şef'), findsWidgets);

    final operationsCard = find.byKey(
      const ValueKey('chief-operations-module'),
    );
    expect(
      find.descendant(of: operationsCard, matching: find.text('1')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: operationsCard,
        matching: find.text('Açık operasyon'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Operasyon Merkezi'));
    await tester.pumpAndSettle();
    expect(find.text('Şeflik Operasyon Merkezi'), findsOneWidget);
    expect(find.text('Sayaç kaynağı iş'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Şeflik Ana Sayfası'), findsOneWidget);

    await tester.tap(find.text('Araç Yönetimi'));
    await tester.pumpAndSettle();
    expect(find.text('Araç modülü hazırlanıyor'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Personel Yönetimi'));
    await tester.pumpAndSettle();
    expect(find.text('Personel modülü hazırlanıyor'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Şeflik Ana Sayfası'), findsOneWidget);

    await tester.tap(find.byTooltip('Çıkış yap'));
    await tester.pump();
    expect(logoutCalled, isTrue);
  });

  testWidgets('modül kartları yalnız semantik izinlerle gösterilir', (
    tester,
  ) async {
    final fixture = _Fixture(
      currentUser: const AppUser(
        id: 'restricted-chief',
        fullName: 'Kısıtlı Şef',
        username: 'kisitli.sef',
        role: UserRole.chief,
        permissions: {
          AppPermission.approveOperations,
          AppPermission.viewAssignedVehicle,
          AppPermission.managePersonnel,
        },
      ),
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      MaterialApp(home: fixture.resolver(onLogout: () async {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Şeflik Ana Sayfası'), findsOneWidget);
    expect(find.text('Operasyon Merkezi'), findsNothing);
    expect(find.text('Araç Yönetimi'), findsNothing);
    expect(find.text('Personel Yönetimi'), findsNothing);
    expect(
      find.text('Erişebileceğiniz bir yönetim modülü bulunmuyor.'),
      findsOneWidget,
    );
  });

  testWidgets('modül ızgarası mobilde tek, geniş ekranda üç sütundur', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(390, 1100);
    await tester.pumpWidget(
      MaterialApp(home: fixture.resolver(onLogout: () async {})),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final mobileOperations = tester.getTopLeft(
      find.byKey(const ValueKey('chief-operations-module')),
    );
    final mobileVehicles = tester.getTopLeft(
      find.byKey(const ValueKey('chief-vehicles-module')),
    );
    expect(mobileVehicles.dx, mobileOperations.dx);
    expect(mobileVehicles.dy, greaterThan(mobileOperations.dy));

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final wideOperations = tester.getTopLeft(
      find.byKey(const ValueKey('chief-operations-module')),
    );
    final wideVehicles = tester.getTopLeft(
      find.byKey(const ValueKey('chief-vehicles-module')),
    );
    final widePersonnel = tester.getTopLeft(
      find.byKey(const ValueKey('chief-personnel-module')),
    );
    expect(wideVehicles.dy, wideOperations.dy);
    expect(widePersonnel.dy, wideOperations.dy);
    expect(wideVehicles.dx, greaterThan(wideOperations.dx));
    expect(widePersonnel.dx, greaterThan(wideVehicles.dx));
  });
}

class _Fixture {
  final AppUser currentUser;
  late final FakeTechnicalWorkRepository repository;
  late final TechnicalWorkController technicalWorkController;
  late final FieldReportController fieldReportController;
  late final TeamController teamController;

  _Fixture({this.currentUser = _chief}) {
    repository = FakeTechnicalWorkRepository(
      works: [_countedWork],
      delay: Duration.zero,
    );
    technicalWorkController = TechnicalWorkController(repository: repository);
    fieldReportController = FieldReportController(repository: repository);
    teamController = TeamController(
      repository: FakeTeamRepository(delay: Duration.zero),
      actorPermissions: currentUser.permissions,
    );
  }

  RoleDashboardResolver resolver({required Future<void> Function() onLogout}) {
    return RoleDashboardResolver(
      currentUser: currentUser,
      onLogout: onLogout,
      technicalWorkController: technicalWorkController,
      fieldReportController: fieldReportController,
      teamController: teamController,
    );
  }

  void dispose() {
    technicalWorkController.dispose();
    fieldReportController.dispose();
    teamController.dispose();
  }
}

const _chief = AppUser(
  id: 'chief-navigation',
  fullName: 'Test Şef',
  username: 'test.sef',
  role: UserRole.chief,
  permissions: {
    AppPermission.viewAllTechnicalWork,
    AppPermission.viewVehicleFleet,
    AppPermission.viewPersonnel,
  },
);

final _countedWork = TechnicalWork(
  id: 'counted-work',
  title: 'Sayaç kaynağı iş',
  description: 'Ana sayfa sayacını besler.',
  location: 'D-100 / Km 1+000',
  category: TechnicalWorkCategory.roadSurface,
  priority: TechnicalWorkPriority.critical,
  status: TechnicalWorkStatus.assigned,
  createdByUserId: 'chief-navigation',
  assignedToUserId: 'user-engineer-001',
  createdAt: DateTime(2026, 8, 25, 9),
);
