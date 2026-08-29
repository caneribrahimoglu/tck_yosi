import '../enums/vehicle_record_type.dart';

class CreateVehicleRecordRequest {
  final VehicleRecordType type;
  final String title;
  final String description;
  final int mileage;

  const CreateVehicleRecordRequest({
    required this.type,
    required this.title,
    required this.description,
    required this.mileage,
  });
}
