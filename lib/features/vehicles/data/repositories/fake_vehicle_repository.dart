import '../../domain/models/vehicle.dart';
import '../../domain/models/create_vehicle_request.dart';
import '../../domain/models/update_vehicle_request.dart';
import '../../domain/models/vehicle_assignment.dart';
import '../../domain/enums/vehicle_operational_status.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/vehicle_repository_exception.dart';
import '../fake_vehicle_data.dart';

class FakeVehicleRepository implements VehicleRepository {
  final List<Vehicle> _vehicles;
  final List<VehicleAssignment> _assignments;
  final Duration delay;

  FakeVehicleRepository({
    List<Vehicle>? vehicles,
    List<VehicleAssignment>? assignments,
    this.delay = const Duration(milliseconds: 300),
  }) : _vehicles = List.of(vehicles ?? FakeVehicleData.vehicles),
       _assignments = List.of(
         assignments ??
             (vehicles == null ? FakeVehicleData.assignments : const []),
       );

  @override
  Future<List<Vehicle>> getAllVehicles() async {
    await _wait();
    return List.unmodifiable(_vehicles);
  }

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async {
    await _wait();
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) {
        return vehicle;
      }
    }
    return null;
  }

  @override
  Future<Vehicle> createVehicle(CreateVehicleRequest request) async {
    await _wait();
    final normalizedPlate = request.licensePlate.trim().toUpperCase();
    final plateExists = _vehicles.any(
      (vehicle) => vehicle.licensePlate == normalizedPlate,
    );
    if (plateExists) {
      throw const VehicleRepositoryException(
        'Bu plakaya ait bir araç zaten kayıtlı.',
      );
    }

    final now = DateTime.now();
    final vehicle = Vehicle(
      id: 'vehicle-${now.microsecondsSinceEpoch}',
      licensePlate: normalizedPlate,
      brand: request.brand,
      model: request.model,
      modelYear: request.modelYear,
      currentMileage: request.currentMileage,
      ownershipType: request.ownershipType,
      operationalStatus: request.operationalStatus,
      contractorName: request.contractorName,
      type: request.type,
    );
    _vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<Vehicle> updateVehicle({
    required String vehicleId,
    required UpdateVehicleRequest request,
  }) async {
    await _wait();
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == vehicleId);
    if (index == -1) {
      throw const VehicleRepositoryException('Araç kaydı bulunamadı.');
    }

    final normalizedPlate = request.licensePlate.trim().toUpperCase();
    final plateExists = _vehicles.any(
      (vehicle) =>
          vehicle.id != vehicleId && vehicle.licensePlate == normalizedPlate,
    );
    if (plateExists) {
      throw const VehicleRepositoryException(
        'Bu plakaya ait bir araç zaten kayıtlı.',
      );
    }

    final updatedVehicle = Vehicle(
      id: vehicleId,
      licensePlate: normalizedPlate,
      brand: request.brand,
      model: request.model,
      modelYear: request.modelYear,
      currentMileage: request.currentMileage,
      ownershipType: request.ownershipType,
      operationalStatus: request.operationalStatus,
      contractorName: request.contractorName,
      type: request.type,
    );
    _vehicles[index] = updatedVehicle;
    return updatedVehicle;
  }

  @override
  Future<List<VehicleAssignment>> getVehicleAssignments(
    String vehicleId,
  ) async {
    await _wait();
    final assignments =
        _assignments
            .where((assignment) => assignment.vehicleId == vehicleId)
            .toList(growable: false)
          ..sort(
            (first, second) => second.assignedAt.compareTo(first.assignedAt),
          );
    return List.unmodifiable(assignments);
  }

  @override
  Future<VehicleAssignment> assignVehicle({
    required String vehicleId,
    required String userId,
    required String userName,
  }) async {
    await _wait();
    final vehicle = _vehicles.where((item) => item.id == vehicleId).firstOrNull;
    if (vehicle == null) {
      throw const VehicleRepositoryException('Araç kaydı bulunamadı.');
    }
    if (vehicle.operationalStatus != VehicleOperationalStatus.active) {
      throw const VehicleRepositoryException(
        'Yalnızca aktif durumdaki araçlar personele atanabilir.',
      );
    }

    final activeIndex = _assignments.indexWhere(
      (assignment) => assignment.vehicleId == vehicleId && assignment.isActive,
    );
    if (activeIndex != -1 &&
        _assignments[activeIndex].assignedToUserId == userId) {
      throw VehicleRepositoryException(
        'Araç zaten ${_assignments[activeIndex].assignedToName} kullanıcısına atanmış.',
      );
    }

    final now = DateTime.now();
    if (activeIndex != -1) {
      _assignments[activeIndex] = _assignments[activeIndex].end(now);
    }
    final assignment = VehicleAssignment(
      id: 'vehicle-assignment-${now.microsecondsSinceEpoch}',
      vehicleId: vehicleId,
      assignedToUserId: userId,
      assignedToName: userName.trim(),
      assignedAt: now,
    );
    _assignments.add(assignment);
    return assignment;
  }

  @override
  Future<void> releaseVehicle(String vehicleId) async {
    await _wait();
    final activeIndex = _assignments.indexWhere(
      (assignment) => assignment.vehicleId == vehicleId && assignment.isActive,
    );
    if (activeIndex == -1) {
      throw const VehicleRepositoryException(
        'Araçta aktif personel ataması yok.',
      );
    }
    _assignments[activeIndex] = _assignments[activeIndex].end(DateTime.now());
  }

  Future<void> _wait() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
}
