import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';

void main() {
  test('demo filo kuruma ait ve sözleşmeli araçlar içerir', () async {
    final repository = FakeVehicleRepository(delay: Duration.zero);

    final vehicles = await repository.getAllVehicles();

    expect(
      vehicles.any(
        (vehicle) =>
            vehicle.ownershipType == VehicleOwnershipType.institutionOwned,
      ),
      isTrue,
    );
    expect(
      vehicles.any(
        (vehicle) => vehicle.ownershipType == VehicleOwnershipType.contracted,
      ),
      isTrue,
    );
  });

  test('dönen araç listesi değiştirilemez', () async {
    final repository = FakeVehicleRepository(delay: Duration.zero);
    final vehicles = await repository.getAllVehicles();

    expect(() => vehicles.add(_vehicle('other')), throwsUnsupportedError);
  });

  test(
    'repository enjekte edilen seed listesinin kendi kopyasını tutar',
    () async {
      final seed = [_vehicle('first')];
      final repository = FakeVehicleRepository(
        vehicles: seed,
        delay: Duration.zero,
      );
      seed.add(_vehicle('second'));

      final vehicles = await repository.getAllVehicles();

      expect(vehicles, hasLength(1));
      expect(vehicles.single.id, 'first');
    },
  );

  test('araç kimlikle bulunabilir, bilinmeyen kimlik null döner', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('first')],
      delay: Duration.zero,
    );

    expect((await repository.getVehicleById('first'))?.id, 'first');
    expect(await repository.getVehicleById('missing'), isNull);
  });
}

Vehicle _vehicle(String id) => Vehicle(
  id: id,
  licensePlate: '81 TST 001',
  brand: 'Demo',
  model: 'Model',
  modelYear: 2022,
  currentMileage: 100,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: VehicleOperationalStatus.active,
  type: VehicleType.pickup,
);
