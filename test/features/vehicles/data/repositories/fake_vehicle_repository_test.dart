import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/update_vehicle_request.dart';
import 'package:tck_yosi/features/vehicles/domain/repositories/vehicle_repository_exception.dart';

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

  test('kuruma ait yeni araç oluşturulur ve filoya eklenir', () async {
    final repository = FakeVehicleRepository(
      vehicles: [],
      delay: Duration.zero,
    );

    final created = await repository.createVehicle(_request());
    final vehicles = await repository.getAllVehicles();

    expect(created.licensePlate, '81 YEN 001');
    expect(created.ownershipType, VehicleOwnershipType.institutionOwned);
    expect(vehicles.single.id, created.id);
  });

  test('aynı plaka ikinci kez kaydedilemez', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('existing')],
      delay: Duration.zero,
    );

    expect(
      () => repository.createVehicle(_request(licensePlate: '81 tst 001')),
      throwsA(
        isA<VehicleRepositoryException>().having(
          (error) => error.message,
          'message',
          'Bu plakaya ait bir araç zaten kayıtlı.',
        ),
      ),
    );
  });

  test('araç bilgileri ve operasyon durumu güncellenir', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('existing')],
      delay: Duration.zero,
    );

    final updated = await repository.updateVehicle(
      vehicleId: 'existing',
      request: _updateRequest(
        licensePlate: '81 GNC 001',
        status: VehicleOperationalStatus.maintenance,
      ),
    );

    expect(updated.id, 'existing');
    expect(updated.licensePlate, '81 GNC 001');
    expect(updated.operationalStatus, VehicleOperationalStatus.maintenance);
    expect((await repository.getAllVehicles()).single, same(updated));
  });

  test('güncellemede başka araca ait plaka kullanılamaz', () async {
    final repository = FakeVehicleRepository(
      vehicles: [
        _vehicle('first'),
        _vehicle('second', plate: '81 TST 002'),
      ],
      delay: Duration.zero,
    );

    expect(
      () => repository.updateVehicle(
        vehicleId: 'second',
        request: _updateRequest(licensePlate: '81 tst 001'),
      ),
      throwsA(isA<VehicleRepositoryException>()),
    );
  });
}

CreateVehicleRequest _request({String licensePlate = '81 YEN 001'}) =>
    CreateVehicleRequest(
      licensePlate: licensePlate,
      brand: 'Ford',
      model: 'Ranger',
      modelYear: 2024,
      currentMileage: 1000,
      ownershipType: VehicleOwnershipType.institutionOwned,
      operationalStatus: VehicleOperationalStatus.active,
      contractorName: null,
      type: VehicleType.pickup,
    );

UpdateVehicleRequest _updateRequest({
  String licensePlate = '81 TST 001',
  VehicleOperationalStatus status = VehicleOperationalStatus.active,
}) => UpdateVehicleRequest(
  licensePlate: licensePlate,
  brand: 'Ford',
  model: 'Ranger',
  modelYear: 2024,
  currentMileage: 2000,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: status,
  contractorName: null,
  type: VehicleType.pickup,
);

Vehicle _vehicle(String id, {String plate = '81 TST 001'}) => Vehicle(
  id: id,
  licensePlate: plate,
  brand: 'Demo',
  model: 'Model',
  modelYear: 2022,
  currentMileage: 100,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: VehicleOperationalStatus.active,
  type: VehicleType.pickup,
);
