import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_request.dart';
import 'package:tck_yosi/features/vehicles/domain/repositories/vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_load_status.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';

void main() {
  test('load listeyi ve gerçek sayaçları doldurur', () async {
    final controller = VehicleController(
      repository: _VehicleRepository(vehicles: _vehicles),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.status, VehicleLoadStatus.loaded);
    expect(controller.totalCount, 4);
    expect(controller.activeCount, 2);
    expect(controller.maintenanceCount, 1);
    expect(controller.contractedCount, 2);
  });

  test('arama plaka marka ve modelde büyük küçük harfe duyarsızdır', () async {
    final controller = VehicleController(
      repository: _VehicleRepository(vehicles: _vehicles),
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.setSearchQuery('ford');
    expect(controller.vehicles.single.id, 'institution-active');
    controller.setSearchQuery('81 DEM 003');
    expect(controller.vehicles.single.id, 'contracted-active');
    controller.setSearchQuery('3cx');
    expect(controller.vehicles.single.id, 'contracted-out');
  });

  test(
    'mülkiyet ve durum filtreleri birlikte uygulanır ve temizlenir',
    () async {
      final controller = VehicleController(
        repository: _VehicleRepository(vehicles: _vehicles),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setOwnershipFilter(VehicleOwnershipType.contracted);
      controller.setStatusFilter(VehicleOperationalStatus.active);

      expect(controller.vehicles.map((vehicle) => vehicle.id), [
        'contracted-active',
      ]);
      expect(controller.hasActiveFilters, isTrue);

      controller.clearFilters();

      expect(controller.vehicles, hasLength(4));
      expect(controller.ownershipFilter, isNull);
      expect(controller.statusFilter, isNull);
      expect(controller.searchQuery, isEmpty);
    },
  );

  test('eşzamanlı iki load repositoryyi bir kez çağırır', () async {
    final completer = Completer<List<Vehicle>>();
    final repository = _VehicleRepository(completer: completer);
    final controller = VehicleController(repository: repository);
    addTearDown(controller.dispose);

    final first = controller.load();
    final second = controller.load();
    expect(controller.status, VehicleLoadStatus.loading);
    expect(repository.getAllCallCount, 1);

    completer.complete(_vehicles);
    await Future.wait([first, second]);

    expect(controller.status, VehicleLoadStatus.loaded);
    expect(repository.getAllCallCount, 1);
  });

  test('repository hatası failure ve güvenli mesaj üretir', () async {
    final controller = VehicleController(
      repository: _VehicleRepository(error: StateError('test failure')),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.status, VehicleLoadStatus.failure);
    expect(controller.errorMessage, 'Araç bilgileri yüklenemedi.');
    expect(controller.vehicles, isEmpty);
  });

  test('oluşturulan araç listeye ve sayaçlara anında eklenir', () async {
    final controller = VehicleController(
      repository: FakeVehicleRepository(vehicles: [], delay: Duration.zero),
    );
    addTearDown(controller.dispose);
    await controller.load();

    final created = await controller.createVehicle(_createRequest());

    expect(created, isNotNull);
    expect(controller.totalCount, 1);
    expect(controller.activeCount, 1);
    expect(controller.vehicles.single.licensePlate, '81 YEN 001');
    expect(controller.creationErrorMessage, isNull);
  });

  test('mükerrer plaka güvenli oluşturma hatası üretir', () async {
    final controller = VehicleController(
      repository: FakeVehicleRepository(
        vehicles: [_vehicles.first],
        delay: Duration.zero,
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();

    final created = await controller.createVehicle(
      _createRequest(licensePlate: '81 kgm 001'),
    );

    expect(created, isNull);
    expect(controller.totalCount, 1);
    expect(
      controller.creationErrorMessage,
      'Bu plakaya ait bir araç zaten kayıtlı.',
    );
  });
}

CreateVehicleRequest _createRequest({String licensePlate = '81 YEN 001'}) =>
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

class _VehicleRepository implements VehicleRepository {
  final List<Vehicle>? vehicles;
  final Completer<List<Vehicle>>? completer;
  final Object? error;
  int getAllCallCount = 0;

  _VehicleRepository({this.vehicles, this.completer, this.error});

  @override
  Future<List<Vehicle>> getAllVehicles() async {
    getAllCallCount++;
    if (error != null) {
      throw error!;
    }
    return completer?.future ?? vehicles ?? const [];
  }

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async => null;

  @override
  Future<Vehicle> createVehicle(CreateVehicleRequest request) {
    throw UnimplementedError();
  }
}

final _vehicles = [
  _vehicle(
    id: 'institution-active',
    plate: '81 KGM 001',
    brand: 'Ford',
    model: 'Ranger',
  ),
  _vehicle(
    id: 'institution-maintenance',
    plate: '81 KGM 002',
    brand: 'Renault',
    model: 'Megane',
    status: VehicleOperationalStatus.maintenance,
  ),
  _vehicle(
    id: 'contracted-active',
    plate: '81 DEM 003',
    brand: 'Mercedes-Benz',
    model: 'Arocs',
    ownership: VehicleOwnershipType.contracted,
  ),
  _vehicle(
    id: 'contracted-out',
    plate: '81 DEM 004',
    brand: 'JCB',
    model: '3CX',
    ownership: VehicleOwnershipType.contracted,
    status: VehicleOperationalStatus.outOfService,
  ),
];

Vehicle _vehicle({
  required String id,
  required String plate,
  required String brand,
  required String model,
  VehicleOwnershipType ownership = VehicleOwnershipType.institutionOwned,
  VehicleOperationalStatus status = VehicleOperationalStatus.active,
}) => Vehicle(
  id: id,
  licensePlate: plate,
  brand: brand,
  model: model,
  modelYear: 2022,
  currentMileage: 100,
  ownershipType: ownership,
  operationalStatus: status,
  contractorName: ownership == VehicleOwnershipType.contracted
      ? 'Demo Tedarik'
      : null,
  type: VehicleType.pickup,
);
