import '../models/vehicle.dart';
import '../models/create_vehicle_request.dart';
import '../models/update_vehicle_request.dart';
import '../models/vehicle_assignment.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> getAllVehicles();

  Future<Vehicle?> getVehicleById(String vehicleId);

  Future<Vehicle> createVehicle(CreateVehicleRequest request);

  Future<Vehicle> updateVehicle({
    required String vehicleId,
    required UpdateVehicleRequest request,
  });

  Future<List<VehicleAssignment>> getVehicleAssignments(String vehicleId);

  Future<VehicleAssignment> assignVehicle({
    required String vehicleId,
    required String userId,
    required String userName,
  });

  Future<void> releaseVehicle(String vehicleId);
}
