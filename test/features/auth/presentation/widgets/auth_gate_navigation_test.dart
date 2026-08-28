import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tck_yosi/features/auth/presentation/widgets/auth_gate.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_assignment_target_adapter.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_technical_work_access_adapter.dart';
import 'package:tck_yosi/features/teams/data/adapters/technical_work_participant_name_adapter.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_controller.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_hold_controller.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_detail_controller.dart';

void main() {
  testWidgets(
    'şef operasyon child routeundan çıkış yapar ve mühendis olarak yeniden girer',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = _AuthGateFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      await _login(tester, username: 'sef');

      expect(fixture.authController.currentUser?.username, 'sef');
      expect(find.text('Şeflik Ana Sayfası'), findsOneWidget);
      await tester.tap(find.text('Operasyon Merkezi'));
      await tester.pumpAndSettle();
      expect(find.text('Şeflik Operasyon Merkezi'), findsOneWidget);

      await tester.tap(find.byTooltip('Çıkış yap'));
      await tester.pumpAndSettle();

      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text('Şeflik Ana Sayfası'), findsNothing);
      expect(find.text('Şeflik Operasyon Merkezi'), findsNothing);

      await _login(tester, username: 'muhendis');

      expect(find.text('Teknik Operasyonlar'), findsOneWidget);
      expect(find.text('Şeflik Ana Sayfası'), findsNothing);
      expect(find.text('Şeflik Operasyon Merkezi'), findsNothing);
      expect(
        Navigator.of(tester.element(find.text('Teknik Operasyonlar'))).canPop(),
        isFalse,
      );
    },
  );

  for (final module in const [
    ('Araç Yönetimi', 'Filo Listesi (4)'),
    ('Personel Yönetimi', 'Personel modülü hazırlanıyor'),
  ]) {
    testWidgets('${module.$1} child routeundan çıkış login ekranını açar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = _AuthGateFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      await _login(tester, username: 'sef');
      expect(fixture.authController.currentUser?.username, 'sef');
      await tester.tap(find.text(module.$1));
      await tester.pumpAndSettle();
      expect(find.text(module.$2), findsOneWidget);

      await tester.tap(find.byTooltip('Çıkış yap'));
      await tester.pumpAndSettle();

      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text(module.$2), findsNothing);
    });
  }

  testWidgets('şef araç listesinden gerçek araç detayına gider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = _AuthGateFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    await _login(tester, username: 'sef');

    await tester.tap(find.text('Araç Yönetimi'));
    await tester.pumpAndSettle();
    final vehicleCard = find.byKey(const ValueKey('vehicle-vehicle-demo-001'));
    await tester.ensureVisible(vehicleCard);
    await tester.pumpAndSettle();
    await tester.tap(vehicleCard);
    await tester.pumpAndSettle();

    expect(find.text('Araç Detayı'), findsOneWidget);
    expect(find.text('81 KGM 101'), findsNWidgets(2));
    expect(find.text('48.320 km'), findsOneWidget);
    expect(find.text('Araç Bilgileri'), findsOneWidget);
  });

  for (final account in const [
    ('sef', 'Şeflik Ana Sayfası'),
    ('sofor', 'Hoş geldin, Ahmet Yılmaz'),
    ('muhendis', 'Teknik Operasyonlar'),
  ]) {
    testWidgets('${account.$1} kök dashboardundan çıkış davranışı korunur', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = _AuthGateFixture();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      await _login(tester, username: account.$1);
      expect(find.text(account.$2), findsOneWidget);

      await tester.tap(find.byTooltip('Çıkış yap'));
      await tester.pumpAndSettle();

      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text(account.$2), findsNothing);
    });
  }
}

class _AuthGateFixture {
  late final FakeAuthService authService;
  late final AuthController authController;
  late final TechnicalWorkController technicalWorkController;
  late final TechnicalWorkDetailController technicalWorkDetailController;
  late final TechnicalWorkCompletionController completionController;
  late final TechnicalWorkHoldController holdController;
  late final FieldReportController fieldReportController;
  late final TeamController teamController;
  late final VehicleController vehicleController;
  late final VehicleDetailController vehicleDetailController;

  _AuthGateFixture() {
    authService = FakeAuthService();
    authController = AuthController(authService: authService);
    final teamRepository = FakeTeamRepository(delay: Duration.zero);
    final accessSource = TeamTechnicalWorkAccessAdapter(
      teamRepository: teamRepository,
      userDirectory: authService,
    );
    final nameSource = TechnicalWorkParticipantNameAdapter(
      teamRepository: teamRepository,
      userDirectory: authService,
    );
    final technicalWorkRepository = FakeTechnicalWorkRepository(
      delay: Duration.zero,
      teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
        repository: teamRepository,
      ),
      technicalWorkAccessSource: accessSource,
    );
    technicalWorkController = TechnicalWorkController(
      repository: technicalWorkRepository,
      participantNameSource: nameSource,
    );
    technicalWorkDetailController = TechnicalWorkDetailController(
      repository: technicalWorkRepository,
      participantNameSource: nameSource,
    );
    completionController = TechnicalWorkCompletionController(
      repository: technicalWorkRepository,
      participantNameSource: nameSource,
    );
    holdController = TechnicalWorkHoldController(
      repository: technicalWorkRepository,
      participantNameSource: nameSource,
    );
    fieldReportController = FieldReportController(
      repository: technicalWorkRepository,
    );
    teamController = TeamController(
      repository: teamRepository,
      actorPermissions: const {},
    );
    final vehicleRepository = FakeVehicleRepository(delay: Duration.zero);
    vehicleController = VehicleController(repository: vehicleRepository);
    vehicleDetailController = VehicleDetailController(
      repository: vehicleRepository,
    );
  }

  Widget get app => MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: AuthGate(
      authController: authController,
      technicalWorkController: technicalWorkController,
      technicalWorkDetailController: technicalWorkDetailController,
      technicalWorkCompletionController: completionController,
      technicalWorkHoldController: holdController,
      fieldReportController: fieldReportController,
      teamController: teamController,
      vehicleController: vehicleController,
      vehicleDetailController: vehicleDetailController,
    ),
  );

  void dispose() {
    authController.dispose();
    technicalWorkController.dispose();
    technicalWorkDetailController.dispose();
    completionController.dispose();
    holdController.dispose();
    fieldReportController.dispose();
    teamController.dispose();
    vehicleController.dispose();
    vehicleDetailController.dispose();
  }
}

Future<void> _login(WidgetTester tester, {required String username}) async {
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), username);
  await tester.enterText(fields.at(1), '123456');
  expect(tester.widget<TextFormField>(fields.at(0)).controller?.text, username);
  expect(tester.widget<TextFormField>(fields.at(1)).controller?.text, '123456');
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Giriş Yap'));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}
