import '../../domain/models/vehicle.dart';
import '../../domain/models/create_vehicle_request.dart';
import '../../domain/models/update_vehicle_request.dart';
import '../../domain/models/vehicle_assignment.dart';
import '../../domain/models/vehicle_inspection.dart';
import '../../domain/models/vehicle_usage_session.dart';
import '../../domain/models/create_vehicle_record_request.dart';
import '../../domain/models/vehicle_record.dart';
import '../../domain/models/review_vehicle_fault_request.dart';
import '../../domain/models/vehicle_fault_review.dart';
import '../../domain/enums/vehicle_fault_review_decision.dart';
import '../../domain/enums/vehicle_record_type.dart';
import '../../domain/enums/vehicle_operational_status.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/vehicle_repository_exception.dart';
import '../fake_vehicle_data.dart';

class FakeVehicleRepository implements VehicleRepository {
  final List<Vehicle> _vehicles;
  final List<VehicleAssignment> _assignments;
  final List<VehicleUsageSession> _usageSessions;
  final List<VehicleRecord> _records;
  final Duration delay;

  FakeVehicleRepository({
    List<Vehicle>? vehicles,
    List<VehicleAssignment>? assignments,
    List<VehicleUsageSession>? usageSessions,
    List<VehicleRecord>? records,
    this.delay = const Duration(milliseconds: 300),
  }) : _vehicles = List.of(vehicles ?? FakeVehicleData.vehicles),
       _assignments = List.of(
         assignments ??
             (vehicles == null ? FakeVehicleData.assignments : const []),
       ),
       _usageSessions = List.of(usageSessions ?? const []),
       _records = List.of(records ?? const []);

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
    if (_usageSessions.any(
      (session) => session.vehicleId == vehicleId && session.isActive,
    )) {
      throw const VehicleRepositoryException(
        'Teslim alınmış araç iade edilmeden başka personele atanamaz.',
      );
    }
    if (_assignments.any(
      (assignment) =>
          assignment.vehicleId != vehicleId &&
          assignment.assignedToUserId == userId &&
          assignment.isActive,
    )) {
      throw const VehicleRepositoryException(
        'Seçilen personelin zaten aktif bir araç ataması bulunuyor.',
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
    if (_usageSessions.any(
      (session) => session.vehicleId == vehicleId && session.isActive,
    )) {
      throw const VehicleRepositoryException(
        'Teslim alınmış araç önce kullanıcı tarafından iade edilmelidir.',
      );
    }
    _assignments[activeIndex] = _assignments[activeIndex].end(DateTime.now());
  }

  @override
  Future<VehicleAssignment?> getActiveAssignmentForUser(String userId) async {
    await _wait();
    for (final assignment in _assignments.reversed) {
      if (assignment.assignedToUserId == userId && assignment.isActive) {
        return assignment;
      }
    }
    return null;
  }

  @override
  Future<VehicleUsageSession?> getActiveUsageSessionForUser(
    String userId,
  ) async {
    await _wait();
    for (final session in _usageSessions.reversed) {
      if (session.userId == userId && session.isActive) {
        return session;
      }
    }
    return null;
  }

  @override
  Future<List<VehicleUsageSession>> getVehicleUsageSessions(
    String vehicleId,
  ) async {
    await _wait();
    final sessions =
        _usageSessions
            .where((session) => session.vehicleId == vehicleId)
            .toList(growable: false)
          ..sort(
            (first, second) => second.receivedAt.compareTo(first.receivedAt),
          );
    return List.unmodifiable(sessions);
  }

  @override
  Future<VehicleUsageSession> receiveVehicle({
    required String userId,
    required int mileage,
    required VehicleInspection inspection,
  }) async {
    await _wait();
    final assignmentIndex = _assignments.lastIndexWhere(
      (assignment) =>
          assignment.assignedToUserId == userId && assignment.isActive,
    );
    if (assignmentIndex == -1) {
      throw const VehicleRepositoryException(
        'Kullanıcıya atanmış aktif bir araç bulunamadı.',
      );
    }
    final assignment = _assignments[assignmentIndex];
    final vehicleIndex = _vehicles.indexWhere(
      (vehicle) => vehicle.id == assignment.vehicleId,
    );
    if (vehicleIndex == -1) {
      throw const VehicleRepositoryException('Araç kaydı bulunamadı.');
    }
    if (_usageSessions.any(
      (session) =>
          session.isActive &&
          (session.vehicleId == assignment.vehicleId ||
              session.userId == userId),
    )) {
      throw const VehicleRepositoryException('Araç zaten teslim alınmış.');
    }
    final vehicle = _vehicles[vehicleIndex];
    if (vehicle.operationalStatus != VehicleOperationalStatus.active) {
      throw const VehicleRepositoryException(
        'Yalnızca aktif durumdaki araçlar teslim alınabilir.',
      );
    }
    if (mileage < vehicle.currentMileage) {
      throw VehicleRepositoryException(
        'Teslim kilometresi ${vehicle.currentMileage} km değerinden düşük olamaz.',
      );
    }
    _ensureInspectionNotes(inspection);

    final now = DateTime.now();
    final session = VehicleUsageSession(
      id: 'vehicle-usage-${now.microsecondsSinceEpoch}',
      assignmentId: assignment.id,
      vehicleId: vehicle.id,
      userId: userId,
      userName: assignment.assignedToName,
      receivedAt: now,
      receivedMileage: mileage,
      receiveInspection: inspection,
    );
    _vehicles[vehicleIndex] = _copyVehicleWithMileage(vehicle, mileage);
    _usageSessions.add(session);
    return session;
  }

  @override
  Future<VehicleUsageSession> returnVehicle({
    required String userId,
    required int mileage,
    required VehicleInspection inspection,
  }) async {
    await _wait();
    final sessionIndex = _usageSessions.lastIndexWhere(
      (session) => session.userId == userId && session.isActive,
    );
    if (sessionIndex == -1) {
      throw const VehicleRepositoryException(
        'İade edilecek aktif araç kullanımı bulunamadı.',
      );
    }
    final session = _usageSessions[sessionIndex];
    final vehicleIndex = _vehicles.indexWhere(
      (vehicle) => vehicle.id == session.vehicleId,
    );
    if (vehicleIndex == -1) {
      throw const VehicleRepositoryException('Araç kaydı bulunamadı.');
    }
    final vehicle = _vehicles[vehicleIndex];
    if (mileage < vehicle.currentMileage || mileage < session.receivedMileage) {
      throw VehicleRepositoryException(
        'İade kilometresi ${vehicle.currentMileage} km değerinden düşük olamaz.',
      );
    }
    _ensureInspectionNotes(inspection);

    final now = DateTime.now();
    final closedSession = session.close(
      returnedAt: now,
      returnedMileage: mileage,
      returnInspection: inspection,
    );
    _usageSessions[sessionIndex] = closedSession;
    _vehicles[vehicleIndex] = _copyVehicleWithMileage(vehicle, mileage);

    final assignmentIndex = _assignments.indexWhere(
      (assignment) => assignment.id == session.assignmentId,
    );
    if (assignmentIndex != -1 && _assignments[assignmentIndex].isActive) {
      _assignments[assignmentIndex] = _assignments[assignmentIndex].end(now);
    }
    return closedSession;
  }

  @override
  Future<List<VehicleRecord>> getVehicleRecords(String vehicleId) async {
    await _wait();
    final records =
        _records
            .where((record) => record.vehicleId == vehicleId)
            .toList(growable: false)
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return List.unmodifiable(records);
  }

  @override
  Future<VehicleRecord> createVehicleRecord({
    required String userId,
    required String userName,
    required CreateVehicleRecordRequest request,
  }) async {
    await _wait();
    final session = _usageSessions
        .where((item) => item.userId == userId && item.isActive)
        .lastOrNull;
    if (session == null) {
      throw const VehicleRepositoryException(
        'Kayıt eklemek için araç teslim alınmış olmalıdır.',
      );
    }
    final vehicleIndex = _vehicles.indexWhere(
      (vehicle) => vehicle.id == session.vehicleId,
    );
    if (vehicleIndex == -1) {
      throw const VehicleRepositoryException('Araç kaydı bulunamadı.');
    }
    final vehicle = _vehicles[vehicleIndex];
    if (request.mileage < vehicle.currentMileage) {
      throw VehicleRepositoryException(
        'Kayıt kilometresi ${vehicle.currentMileage} km değerinden düşük olamaz.',
      );
    }
    if (request.title.trim().isEmpty || request.description.trim().isEmpty) {
      throw const VehicleRepositoryException(
        'Kayıt başlığı ve açıklaması zorunludur.',
      );
    }

    final now = DateTime.now();
    final record = VehicleRecord(
      id: 'vehicle-record-${now.microsecondsSinceEpoch}',
      vehicleId: vehicle.id,
      usageSessionId: session.id,
      type: request.type,
      title: request.title.trim(),
      description: request.description.trim(),
      mileage: request.mileage,
      createdByUserId: userId,
      createdByName: userName.trim(),
      createdAt: now,
    );
    _records.add(record);
    _vehicles[vehicleIndex] = _copyVehicleWithMileage(vehicle, request.mileage);
    return record;
  }

  @override
  Future<List<VehicleRecord>> getOpenVehicleFaults() async {
    await _wait();
    final records =
        _records
            .where(
              (record) =>
                  record.type == VehicleRecordType.fault &&
                  !record.isFaultResolved,
            )
            .toList(growable: false)
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return List.unmodifiable(records);
  }

  @override
  Future<VehicleRecord> reviewVehicleFault({
    required String recordId,
    required String reviewedByUserId,
    required String reviewedByName,
    required ReviewVehicleFaultRequest request,
  }) async {
    await _wait();
    final recordIndex = _records.indexWhere((record) => record.id == recordId);
    if (recordIndex == -1 ||
        _records[recordIndex].type != VehicleRecordType.fault) {
      throw const VehicleRepositoryException('Araç arıza kaydı bulunamadı.');
    }
    if (_records[recordIndex].isFaultResolved) {
      throw const VehicleRepositoryException('Bu arıza daha önce çözüldü.');
    }
    if (request.note.trim().isEmpty) {
      throw const VehicleRepositoryException(
        'Şef değerlendirme açıklaması zorunludur.',
      );
    }

    final now = DateTime.now();
    final review = VehicleFaultReview(
      id: 'vehicle-fault-review-${now.microsecondsSinceEpoch}',
      decision: request.decision,
      note: request.note.trim(),
      reviewedByUserId: reviewedByUserId,
      reviewedByName: reviewedByName.trim(),
      reviewedAt: now,
    );
    final vehicleIndex = _vehicles.indexWhere(
      (vehicle) => vehicle.id == _records[recordIndex].vehicleId,
    );
    if (vehicleIndex == -1) {
      throw const VehicleRepositoryException('Araç kaydı bulunamadı.');
    }

    final updatedRecord = _records[recordIndex].addFaultReview(review);
    _records[recordIndex] = updatedRecord;
    _vehicles[vehicleIndex] = _copyVehicleWithStatus(
      _vehicles[vehicleIndex],
      _operationalStatusForVehicle(updatedRecord.vehicleId),
    );
    return updatedRecord;
  }

  VehicleOperationalStatus _operationalStatusForVehicle(String vehicleId) {
    final openFaults = _records.where(
      (record) =>
          record.vehicleId == vehicleId &&
          record.type == VehicleRecordType.fault &&
          !record.isFaultResolved,
    );
    if (openFaults.any(
      (record) =>
          record.latestFaultReview?.decision ==
          VehicleFaultReviewDecision.takeOutOfService,
    )) {
      return VehicleOperationalStatus.outOfService;
    }
    if (openFaults.any(
      (record) =>
          record.latestFaultReview?.decision ==
          VehicleFaultReviewDecision.takeToMaintenance,
    )) {
      return VehicleOperationalStatus.maintenance;
    }
    return VehicleOperationalStatus.active;
  }

  void _ensureInspectionNotes(VehicleInspection inspection) {
    if (inspection.hasIssue && inspection.notes.trim().isEmpty) {
      throw const VehicleRepositoryException(
        'Kontrolde sorun işaretlendiyse açıklama zorunludur.',
      );
    }
  }

  Vehicle _copyVehicleWithMileage(Vehicle vehicle, int mileage) => Vehicle(
    id: vehicle.id,
    licensePlate: vehicle.licensePlate,
    brand: vehicle.brand,
    model: vehicle.model,
    modelYear: vehicle.modelYear,
    currentMileage: mileage,
    ownershipType: vehicle.ownershipType,
    operationalStatus: vehicle.operationalStatus,
    contractorName: vehicle.contractorName,
    type: vehicle.type,
  );

  Vehicle _copyVehicleWithStatus(
    Vehicle vehicle,
    VehicleOperationalStatus status,
  ) => Vehicle(
    id: vehicle.id,
    licensePlate: vehicle.licensePlate,
    brand: vehicle.brand,
    model: vehicle.model,
    modelYear: vehicle.modelYear,
    currentMileage: vehicle.currentMileage,
    ownershipType: vehicle.ownershipType,
    operationalStatus: status,
    contractorName: vehicle.contractorName,
    type: vehicle.type,
  );

  Future<void> _wait() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }
}
