import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_record_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_assignment.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_inspection.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/pages/create_vehicle_record_page.dart';

void main() {
  testWidgets('zorunlu alanlar dolunca arıza kaydı oluşturur', (tester) async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle],
      assignments: [
        VehicleAssignment(
          id: 'assignment-record-test',
          vehicleId: _vehicle.id,
          assignedToUserId: _driver.id,
          assignedToName: _driver.fullName,
          assignedAt: DateTime(2026, 8, 29),
        ),
      ],
      delay: Duration.zero,
    );
    await repository.receiveVehicle(
      userId: _driver.id,
      mileage: 100,
      inspection: _inspection,
    );
    final controller = VehicleController(repository: repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: CreateVehicleRecordPage(
          type: VehicleRecordType.fault,
          vehicle: _vehicle,
          currentUser: _driver,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vehicle-record-title')),
      'Silecek arızası',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vehicle-record-mileage')),
      '150',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vehicle-record-description')),
      'Sağ silecek iz bırakıyor.',
    );
    await tester.ensureVisible(find.text('Arıza Kaydını Ekle'));
    await tester.tap(find.text('Arıza Kaydını Ekle'));
    await tester.pumpAndSettle();

    final records = await repository.getVehicleRecords(_vehicle.id);
    expect(records, hasLength(1));
    expect(records.single.title, 'Silecek arızası');
    expect(records.single.createdByName, _driver.fullName);
    expect(records.single.mileage, 150);
  });
}

const _driver = AppUser(
  id: 'driver-record-test',
  fullName: 'Test Şoför',
  username: 'test.sofor',
  role: UserRole.driver,
  permissions: {
    AppPermission.viewAssignedVehicle,
    AppPermission.createVehicleFaultRecord,
    AppPermission.createVehicleMaintenanceRecord,
  },
);

final _vehicle = Vehicle(
  id: 'vehicle-record-test',
  licensePlate: '81 TST 007',
  brand: 'Ford',
  model: 'Ranger',
  modelYear: 2024,
  currentMileage: 100,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: VehicleOperationalStatus.active,
  type: VehicleType.pickup,
);

const _inspection = VehicleInspection(
  bodyworkOkay: true,
  tiresOkay: true,
  lightsOkay: true,
  glassAndMirrorsOkay: true,
  leakFree: true,
  equipmentComplete: true,
  notes: '',
);
