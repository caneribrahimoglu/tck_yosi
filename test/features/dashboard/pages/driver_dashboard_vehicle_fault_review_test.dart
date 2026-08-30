import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/dashboard/pages/driver_dashboard_page.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_fault_review_decision.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_record_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_record_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/review_vehicle_fault_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_assignment.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_inspection.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';

void main() {
  testWidgets('şoför arıza kararında şef açıklamasını görür', (tester) async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle],
      assignments: [
        VehicleAssignment(
          id: 'assignment-driver-review',
          vehicleId: _vehicle.id,
          assignedToUserId: _driver.id,
          assignedToName: _driver.fullName,
          assignedAt: DateTime(2026, 8, 30),
        ),
      ],
      delay: Duration.zero,
    );
    await repository.receiveVehicle(
      userId: _driver.id,
      mileage: 100,
      inspection: _inspection,
    );
    final fault = await repository.createVehicleRecord(
      userId: _driver.id,
      userName: _driver.fullName,
      request: const CreateVehicleRecordRequest(
        type: VehicleRecordType.fault,
        title: 'Sinyal',
        description: 'Sol sinyal çalışmıyor.',
        mileage: 110,
      ),
    );
    await repository.reviewVehicleFault(
      recordId: fault.id,
      reviewedByUserId: 'chief-test',
      reviewedByName: 'Test Şef',
      request: const ReviewVehicleFaultRequest(
        decision: VehicleFaultReviewDecision.continueInService,
        note: 'Servis randevusuna kadar dikkatli kullanın.',
      ),
    );
    final controller = VehicleController(repository: repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DriverDashboardPage(
          currentUser: _driver,
          vehicleController: controller,
          onLogout: _noop,
          onCreateFieldReport: _noop,
          onReceiveVehicle: _noop,
          onReturnVehicle: _noop,
          onCreateFaultRecord: _noop,
          onCreateMaintenanceRecord: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kullanıma Devam'), findsOneWidget);
    expect(find.text('Şef değerlendirmesi'), findsOneWidget);
    expect(
      find.text('Servis randevusuna kadar dikkatli kullanın.'),
      findsOneWidget,
    );
    expect(find.textContaining('Test Şef ·'), findsOneWidget);
  });
}

Future<void> _noop() async {}

const _driver = AppUser(
  id: 'driver-review-test',
  fullName: 'Test Şoför',
  username: 'test.sofor',
  role: UserRole.driver,
  permissions: {
    AppPermission.viewAssignedVehicle,
    AppPermission.returnVehicle,
    AppPermission.createVehicleFaultRecord,
  },
);

final _vehicle = Vehicle(
  id: 'vehicle-driver-review',
  licensePlate: '81 TST 108',
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
