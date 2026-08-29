import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_assignment.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/pages/vehicle_handover_page.dart';

void main() {
  testWidgets('teslim alma formunda kilometre zorunlu ve geriye gidemez', (
    tester,
  ) async {
    final setup = _setup();
    addTearDown(setup.controller.dispose);
    await tester.pumpWidget(_app(setup.controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('handover-mileage')),
      '99',
    );
    await tester.ensureVisible(find.text('Kontrolü Kaydet ve Teslim Al'));
    await tester.tap(find.text('Kontrolü Kaydet ve Teslim Al'));
    await tester.pump();

    expect(find.text('100 km değerinden düşük olamaz.'), findsOneWidget);
    expect(
      await setup.repository.getActiveUsageSessionForUser(_driver.id),
      isNull,
    );
  });

  testWidgets('kontrolde sorun işaretlenirse açıklama zorunlu olur', (
    tester,
  ) async {
    final setup = _setup();
    addTearDown(setup.controller.dispose);
    await tester.pumpWidget(_app(setup.controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dış gövde ve kaporta uygun'));
    await tester.pump();
    await tester.ensureVisible(find.text('Kontrolü Kaydet ve Teslim Al'));
    await tester.tap(find.text('Kontrolü Kaydet ve Teslim Al'));
    await tester.pump();

    expect(find.text('Uygun olmayan maddeleri açıklayın.'), findsOneWidget);
  });

  testWidgets('silecek kontrolü sorunluysa açıklama zorunlu olur', (
    tester,
  ) async {
    final setup = _setup();
    addTearDown(setup.controller.dispose);
    await tester.pumpWidget(_app(setup.controller));
    await tester.pumpAndSettle();

    expect(find.text('Silecekler çalışıyor'), findsOneWidget);
    await tester.ensureVisible(find.text('Silecekler çalışıyor'));
    await tester.tap(find.text('Silecekler çalışıyor'));
    await tester.pump();
    await tester.ensureVisible(find.text('Kontrolü Kaydet ve Teslim Al'));
    await tester.tap(find.text('Kontrolü Kaydet ve Teslim Al'));
    await tester.pump();

    expect(find.text('Uygun olmayan maddeleri açıklayın.'), findsOneWidget);
  });

  testWidgets('geçerli kontrol kilometreyi kaydeder ve aracı teslim alır', (
    tester,
  ) async {
    final setup = _setup();
    addTearDown(setup.controller.dispose);
    await tester.pumpWidget(_app(setup.controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('handover-mileage')),
      '150',
    );
    await tester.ensureVisible(find.text('Kontrolü Kaydet ve Teslim Al'));
    await tester.tap(find.text('Kontrolü Kaydet ve Teslim Al'));
    await tester.pumpAndSettle();

    final session = await setup.repository.getActiveUsageSessionForUser(
      _driver.id,
    );
    expect(session?.receivedMileage, 150);
    expect(
      (await setup.repository.getVehicleById(_vehicle.id))?.currentMileage,
      150,
    );
  });
}

({FakeVehicleRepository repository, VehicleController controller}) _setup() {
  final repository = FakeVehicleRepository(
    vehicles: [_vehicle],
    assignments: [
      VehicleAssignment(
        id: 'assignment-handover-test',
        vehicleId: _vehicle.id,
        assignedToUserId: _driver.id,
        assignedToName: _driver.fullName,
        assignedAt: DateTime(2026, 8, 29),
      ),
    ],
    delay: Duration.zero,
  );
  final controller = VehicleController(repository: repository);
  return (repository: repository, controller: controller);
}

Widget _app(VehicleController controller) => MaterialApp(
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
  home: VehicleHandoverPage(
    type: VehicleHandoverType.receive,
    vehicle: _vehicle,
    currentUser: _driver,
    controller: controller,
  ),
);

const _driver = AppUser(
  id: 'driver-handover-test',
  fullName: 'Test Şoför',
  username: 'test.sofor',
  role: UserRole.driver,
  permissions: {
    AppPermission.viewAssignedVehicle,
    AppPermission.receiveVehicle,
    AppPermission.returnVehicle,
  },
);

final _vehicle = Vehicle(
  id: 'vehicle-handover-test',
  licensePlate: '81 TST 006',
  brand: 'Ford',
  model: 'Ranger',
  modelYear: 2024,
  currentMileage: 100,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: VehicleOperationalStatus.active,
  type: VehicleType.pickup,
);
