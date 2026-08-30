import '../models/vehicle.dart';
import '../models/create_vehicle_request.dart';
import '../models/update_vehicle_request.dart';
import '../models/vehicle_assignment.dart';
import '../models/vehicle_inspection.dart';
import '../models/vehicle_usage_session.dart';
import '../models/create_vehicle_record_request.dart';
import '../models/vehicle_record.dart';
import '../models/review_vehicle_fault_request.dart';

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

  Future<VehicleAssignment?> getActiveAssignmentForUser(String userId);

  Future<VehicleUsageSession?> getActiveUsageSessionForUser(String userId);

  Future<List<VehicleUsageSession>> getVehicleUsageSessions(String vehicleId);

  Future<VehicleUsageSession> receiveVehicle({
    required String userId,
    required int mileage,
    required VehicleInspection inspection,
  });

  Future<VehicleUsageSession> returnVehicle({
    required String userId,
    required int mileage,
    required VehicleInspection inspection,
  });

  Future<List<VehicleRecord>> getVehicleRecords(String vehicleId);

  Future<VehicleRecord> createVehicleRecord({
    required String userId,
    required String userName,
    required CreateVehicleRecordRequest request,
  });

  Future<List<VehicleRecord>> getOpenVehicleFaults();

  Future<VehicleRecord> reviewVehicleFault({
    required String recordId,
    required String reviewedByUserId,
    required String reviewedByName,
    required ReviewVehicleFaultRequest request,
  });
}
