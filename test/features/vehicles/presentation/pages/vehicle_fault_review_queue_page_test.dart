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
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_record_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_assignment.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_inspection.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/pages/vehicle_fault_review_queue_page.dart';

void main() {
  testWidgets('şef bekleyen arızayı inceleyip aracı bakıma alır', (
    tester,
  ) async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle],
      assignments: [
        VehicleAssignment(
          id: 'assignment-fault-review',
          vehicleId: _vehicle.id,
          assignedToUserId: 'driver-review-test',
          assignedToName: 'Test Şoför',
          assignedAt: DateTime(2026, 8, 30),
        ),
      ],
      delay: Duration.zero,
    );
    await repository.receiveVehicle(
      userId: 'driver-review-test',
      mileage: 100,
      inspection: _inspection,
    );
    await repository.createVehicleRecord(
      userId: 'driver-review-test',
      userName: 'Test Şoför',
      request: const CreateVehicleRecordRequest(
        type: VehicleRecordType.fault,
        title: 'Fren arızası',
        description: 'Fren pedalında boşluk var.',
        mileage: 110,
      ),
    );
    final controller = VehicleController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: VehicleFaultReviewQueuePage(
          currentUser: _chief,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('İnceleme Bekliyor'), findsOneWidget);
    expect(find.text('Fren arızası'), findsOneWidget);
    await tester.tap(find.text('Bakıma Al'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vehicle-fault-review-note')),
      'Araç servise yönlendirildi.',
    );
    await tester.tap(find.text('Kararı Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Bakıma Alındı'), findsOneWidget);
    expect(find.text('Araç servise yönlendirildi.'), findsOneWidget);
    expect(
      (await repository.getVehicleById(_vehicle.id))?.operationalStatus,
      VehicleOperationalStatus.maintenance,
    );
  });
}

const _chief = AppUser(
  id: 'chief-review-test',
  fullName: 'Test Şef',
  username: 'test.sef',
  role: UserRole.chief,
  permissions: {AppPermission.reviewVehicleFaults},
);

final _vehicle = Vehicle(
  id: 'vehicle-fault-review',
  licensePlate: '81 TST 008',
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
