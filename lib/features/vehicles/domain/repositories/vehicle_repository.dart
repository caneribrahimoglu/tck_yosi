import '../models/vehicle.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> getAllVehicles();

  Future<Vehicle?> getVehicleById(String vehicleId);
}
