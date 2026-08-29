import '../enums/vehicle_record_type.dart';

class VehicleRecord {
  final String id;
  final String vehicleId;
  final String usageSessionId;
  final VehicleRecordType type;
  final String title;
  final String description;
  final int mileage;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;

  const VehicleRecord({
    required this.id,
    required this.vehicleId,
    required this.usageSessionId,
    required this.type,
    required this.title,
    required this.description,
    required this.mileage,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
  });
}
