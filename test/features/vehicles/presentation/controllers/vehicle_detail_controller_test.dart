import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/repositories/vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_detail_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_detail_load_status.dart';

void main() {
  test(
    'yükleme sırasında loading, araç gelince loaded durumuna geçer',
    () async {
      final completer = Completer<Vehicle?>();
      final controller = VehicleDetailController(
        repository: _VehicleDetailRepository(completer: completer),
      );
      addTearDown(controller.dispose);

      final loadFuture = controller.load('vehicle-001');

      expect(controller.status, VehicleDetailLoadStatus.loading);
      expect(controller.vehicle, isNull);

      completer.complete(_vehicle);
      await loadFuture;

      expect(controller.status, VehicleDetailLoadStatus.loaded);
      expect(controller.vehicle?.id, 'vehicle-001');
      expect(controller.errorMessage, isNull);
    },
  );

  test('bilinmeyen araç kimliği notFound durumuna geçer', () async {
    final controller = VehicleDetailController(
      repository: _VehicleDetailRepository(result: null),
    );
    addTearDown(controller.dispose);

    await controller.load('missing');

    expect(controller.status, VehicleDetailLoadStatus.notFound);
    expect(controller.vehicle, isNull);
  });

  test('repository hata verirse güvenli failure durumuna geçer', () async {
    final controller = VehicleDetailController(
      repository: _VehicleDetailRepository(error: StateError('test')),
    );
    addTearDown(controller.dispose);

    await controller.load('vehicle-001');

    expect(controller.status, VehicleDetailLoadStatus.failure);
    expect(controller.vehicle, isNull);
    expect(controller.errorMessage, 'Araç detayı yüklenemedi.');
  });
}

class _VehicleDetailRepository implements VehicleRepository {
  final Completer<Vehicle?>? completer;
  final Vehicle? result;
  final Object? error;

  _VehicleDetailRepository({this.completer, this.result, this.error});

  @override
  Future<List<Vehicle>> getAllVehicles() async => const [];

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async {
    if (error != null) {
      throw error!;
    }
    return completer?.future ?? result;
  }
}

final _vehicle = Vehicle(
  id: 'vehicle-001',
  licensePlate: '81 TST 001',
  brand: 'Ford',
  model: 'Ranger',
  modelYear: 2022,
  currentMileage: 48320,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: VehicleOperationalStatus.active,
  type: VehicleType.pickup,
);
