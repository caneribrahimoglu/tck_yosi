import '../../domain/models/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
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

  Future<void> _wait() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
}
