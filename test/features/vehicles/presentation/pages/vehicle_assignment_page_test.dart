import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/pages/vehicle_assignment_page.dart';

void main() {
  testWidgets('şef personel seçip aracı atayabilir', (tester) async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle],
      delay: Duration.zero,
    );
    final controller = VehicleController(
      repository: repository,
      userDirectory: FakeAuthService(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: VehicleAssignmentPage(
          vehicle: _vehicle,
          currentAssignment: null,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Araç Personel Ataması'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vehicle-assignee-dropdown')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ahmet Yılmaz'), findsOneWidget);
    await tester.tap(find.textContaining('Ahmet Yılmaz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personeli Ata'));
    await tester.pumpAndSettle();

    final assignments = await repository.getVehicleAssignments(_vehicle.id);
    expect(assignments.single.assignedToName, 'Ahmet Yılmaz');
  });
}

final _vehicle = Vehicle(
  id: 'vehicle-assignment-test',
  licensePlate: '81 TST 005',
  brand: 'Ford',
  model: 'Ranger',
  modelYear: 2024,
  currentMileage: 100,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: VehicleOperationalStatus.active,
  type: VehicleType.pickup,
);
