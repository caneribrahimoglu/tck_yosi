import '../enums/vehicle_operational_status.dart';
import '../enums/vehicle_ownership_type.dart';
import '../enums/vehicle_type.dart';

class CreateVehicleRequest {
  final String licensePlate;
  final String brand;
  final String model;
  final int? modelYear;
  final int currentMileage;
  final VehicleOwnershipType ownershipType;
  final VehicleOperationalStatus operationalStatus;
  final String? contractorName;
  final VehicleType type;

  const CreateVehicleRequest({
    required this.licensePlate,
    required this.brand,
    required this.model,
    required this.modelYear,
    required this.currentMileage,
    required this.ownershipType,
    required this.operationalStatus,
    required this.contractorName,
    required this.type,
  });
}
