import '../../domain/models/vehicle.dart';
import '../../domain/models/create_vehicle_request.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/vehicle_repository_exception.dart';
import '../fake_vehicle_data.dart';

class FakeVehicleRepository implements VehicleRepository {
  final List<Vehicle> _vehicles;
  final Duration delay;

  FakeVehicleRepository({
    List<Vehicle>? vehicles,
    this.delay = const Duration(milliseconds: 300),
  }) : _vehicles = List.of(vehicles ?? FakeVehicleData.vehicles);

  @override
  Future<List<Vehicle>> getAllVehicles() async {
    await _wait();
    return List.unmodifiable(_vehicles);
  }

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async {
    await _wait();
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) {
        return vehicle;
      }
    }
    return null;
  }

  @override
  Future<Vehicle> createVehicle(CreateVehicleRequest request) async {
    await _wait();
    final normalizedPlate = request.licensePlate.trim().toUpperCase();
    final plateExists = _vehicles.any(
      (vehicle) => vehicle.licensePlate == normalizedPlate,
    );
    if (plateExists) {
      throw const VehicleRepositoryException(
        'Bu plakaya ait bir araç zaten kayıtlı.',
      );
    }

    final now = DateTime.now();
    final vehicle = Vehicle(
      id: 'vehicle-${now.microsecondsSinceEpoch}',
      licensePlate: normalizedPlate,
      brand: request.brand,
      model: request.model,
      modelYear: request.modelYear,
      currentMileage: request.currentMileage,
      ownershipType: request.ownershipType,
      operationalStatus: request.operationalStatus,
      contractorName: request.contractorName,
      type: request.type,
    );
    _vehicles.add(vehicle);
    return vehicle;
  }

  Future<void> _wait() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
}
