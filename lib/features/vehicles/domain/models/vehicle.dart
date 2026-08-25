import '../enums/vehicle_operational_status.dart';
import '../enums/vehicle_ownership_type.dart';
import '../enums/vehicle_type.dart';

class Vehicle {
  static const int minimumModelYear = 1900;

  final String id;
  final String licensePlate;
  final String brand;
  final String model;
  final int? modelYear;
  final int currentMileage;
  final VehicleOwnershipType ownershipType;
  final VehicleOperationalStatus operationalStatus;
  final String? contractorName;
  final VehicleType type;

  factory Vehicle({
    required String id,
    required String licensePlate,
    required String brand,
    required String model,
    int? modelYear,
    required int currentMileage,
    required VehicleOwnershipType ownershipType,
    required VehicleOperationalStatus operationalStatus,
    String? contractorName,
    required VehicleType type,
  }) {
    if (currentMileage < 0) {
      throw ArgumentError.value(
        currentMileage,
        'currentMileage',
        'Kilometre negatif olamaz.',
      );
    }
    final maximumModelYear = DateTime.now().year + 1;
    if (modelYear != null &&
        (modelYear < minimumModelYear || modelYear > maximumModelYear)) {
      throw ArgumentError.value(
        modelYear,
        'modelYear',
        'Model yılı $minimumModelYear-$maximumModelYear aralığında olmalıdır.',
      );
    }
    final normalizedContractorName = contractorName?.trim();
    if (ownershipType == VehicleOwnershipType.contracted &&
        (normalizedContractorName == null ||
            normalizedContractorName.isEmpty)) {
      throw ArgumentError.value(
        contractorName,
        'contractorName',
        'Sözleşmeli araç için yüklenici adı zorunludur.',
      );
    }
    return Vehicle._(
      id: id.trim(),
      licensePlate: licensePlate.trim().toUpperCase(),
      brand: brand.trim(),
      model: model.trim(),
      modelYear: modelYear,
      currentMileage: currentMileage,
      ownershipType: ownershipType,
      operationalStatus: operationalStatus,
      contractorName: normalizedContractorName?.isEmpty == true
          ? null
          : normalizedContractorName,
      type: type,
    );
  }

  const Vehicle._({
    required this.id,
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
