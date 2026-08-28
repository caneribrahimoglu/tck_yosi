import '../models/vehicle.dart';
import '../models/create_vehicle_request.dart';
import '../models/update_vehicle_request.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> getAllVehicles();

  Future<Vehicle?> getVehicleById(String vehicleId);

  Future<Vehicle> createVehicle(CreateVehicleRequest request);

  Future<Vehicle> updateVehicle({
    required String vehicleId,
    required UpdateVehicleRequest request,
  });
}
