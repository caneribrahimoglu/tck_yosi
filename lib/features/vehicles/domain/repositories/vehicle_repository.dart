import '../models/vehicle.dart';
import '../models/create_vehicle_request.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> getAllVehicles();

  Future<Vehicle?> getVehicleById(String vehicleId);

  Future<Vehicle> createVehicle(CreateVehicleRequest request);
}
