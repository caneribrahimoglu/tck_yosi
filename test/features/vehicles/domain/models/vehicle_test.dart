import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';

void main() {
  test('kuruma ait araç yüklenici olmadan oluşturulabilir', () {
    final vehicle = _vehicle();

    expect(vehicle.ownershipType, VehicleOwnershipType.institutionOwned);
    expect(vehicle.contractorName, isNull);
  });

  test('sözleşmeli araçta yüklenici adı zorunludur', () {
    expect(
      () => _vehicle(
        ownershipType: VehicleOwnershipType.contracted,
        contractorName: '   ',
      ),
      throwsArgumentError,
    );
  });

  test('sözleşmeli araç yüklenici adını normalize eder', () {
    final vehicle = _vehicle(
      ownershipType: VehicleOwnershipType.contracted,
      contractorName: '  Demo Tedarik  ',
    );

    expect(vehicle.contractorName, 'Demo Tedarik');
  });

  test('negatif kilometre reddedilir', () {
    expect(() => _vehicle(currentMileage: -1), throwsArgumentError);
  });

  test('anlamsız model yılları reddedilir', () {
    expect(() => _vehicle(modelYear: 1899), throwsArgumentError);
    expect(
      () => _vehicle(modelYear: DateTime.now().year + 2),
      throwsArgumentError,
    );
  });
}

Vehicle _vehicle({
  int currentMileage = 100,
  int? modelYear = 2022,
  VehicleOwnershipType ownershipType = VehicleOwnershipType.institutionOwned,
  String? contractorName,
}) {
  return Vehicle(
    id: 'vehicle-test',
    licensePlate: '81 tst 001',
    brand: 'Demo',
    model: 'Model',
    modelYear: modelYear,
    currentMileage: currentMileage,
    ownershipType: ownershipType,
    operationalStatus: VehicleOperationalStatus.active,
    contractorName: contractorName,
    type: VehicleType.pickup,
  );
}
