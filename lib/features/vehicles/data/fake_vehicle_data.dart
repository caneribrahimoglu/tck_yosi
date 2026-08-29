import '../domain/enums/vehicle_operational_status.dart';
import '../domain/enums/vehicle_ownership_type.dart';
import '../domain/enums/vehicle_type.dart';
import '../domain/models/vehicle.dart';
import '../domain/models/vehicle_assignment.dart';

final class FakeVehicleData {
  FakeVehicleData._();

  static final List<Vehicle> vehicles = List.unmodifiable([
    Vehicle(
      id: 'vehicle-demo-001',
      licensePlate: '81 KGM 101',
      brand: 'Ford',
      model: 'Ranger',
      modelYear: 2022,
      currentMileage: 48320,
      ownershipType: VehicleOwnershipType.institutionOwned,
      operationalStatus: VehicleOperationalStatus.active,
      type: VehicleType.pickup,
    ),
    Vehicle(
      id: 'vehicle-demo-002',
      licensePlate: '81 KGM 202',
      brand: 'Renault',
      model: 'Megane',
      modelYear: 2021,
      currentMileage: 67250,
      ownershipType: VehicleOwnershipType.institutionOwned,
      operationalStatus: VehicleOperationalStatus.maintenance,
      type: VehicleType.passengerCar,
    ),
    Vehicle(
      id: 'vehicle-demo-003',
      licensePlate: '81 DEM 303',
      brand: 'Mercedes-Benz',
      model: 'Arocs',
      modelYear: 2023,
      currentMileage: 35800,
      ownershipType: VehicleOwnershipType.contracted,
      operationalStatus: VehicleOperationalStatus.active,
      contractorName: 'Demo Yol Hizmetleri A.Ş.',
      type: VehicleType.truck,
    ),
    Vehicle(
      id: 'vehicle-demo-004',
      licensePlate: '81 DEM 404',
      brand: 'JCB',
      model: '3CX',
      modelYear: 2020,
      currentMileage: 12450,
      ownershipType: VehicleOwnershipType.contracted,
      operationalStatus: VehicleOperationalStatus.outOfService,
      contractorName: 'Örnek Filo Tedarik Ltd.',
      type: VehicleType.workMachine,
    ),
  ]);

  static final List<VehicleAssignment> assignments = List.unmodifiable([
    VehicleAssignment(
      id: 'vehicle-assignment-demo-001',
      vehicleId: 'vehicle-demo-001',
      assignedToUserId: 'user-driver-001',
      assignedToName: 'Ahmet Yılmaz',
      assignedAt: DateTime(2026, 8, 20, 9, 0),
    ),
  ]);
}
