import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_record_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_fault_review_decision.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/update_vehicle_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_assignment.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_inspection.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_usage_session.dart';
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_record_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_record.dart';
import 'package:tck_yosi/features/vehicles/domain/models/review_vehicle_fault_request.dart';
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

  test('atama adayları aktif operasyon personeliyle sınırlandırılır', () async {
    final controller = VehicleController(
      repository: FakeVehicleRepository(vehicles: [], delay: Duration.zero),
      userDirectory: FakeAuthService(),
    );
    addTearDown(controller.dispose);

    await controller.loadAssignmentCandidates();

    expect(
      controller.assignmentCandidates.map((user) => user.username),
      containsAll(['sofor', 'muhendis']),
    );
    expect(
      controller.assignmentCandidates.map((user) => user.username),
      isNot(contains('sef')),
    );
    expect(controller.assignmentErrorMessage, isNull);
  });

  test('controller aracı personele atar ve atamayı sonlandırır', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicles.first],
      delay: Duration.zero,
    );
    final directory = FakeAuthService();
    final controller = VehicleController(
      repository: repository,
      userDirectory: directory,
    );
    addTearDown(controller.dispose);
    await controller.loadAssignmentCandidates();
    final driver = controller.assignmentCandidates.firstWhere(
      (user) => user.username == 'sofor',
    );

    final assignment = await controller.assignVehicle(
      vehicleId: _vehicles.first.id,
      user: driver,
    );
    final released = await controller.releaseVehicle(_vehicles.first.id);

    expect(assignment?.assignedToUserId, driver.id);
    expect(released, isTrue);
    expect(controller.assignmentErrorMessage, isNull);
    expect(controller.isAssigning, isFalse);
  });

  test('şoför atanmış aracını yükler, teslim alır ve iade eder', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicles.first],
      assignments: [
        VehicleAssignment(
          id: 'assignment-driver',
          vehicleId: _vehicles.first.id,
          assignedToUserId: 'driver-001',
          assignedToName: 'Test Şoför',
          assignedAt: DateTime(2026, 8, 29),
        ),
      ],
      delay: Duration.zero,
    );
    final controller = VehicleController(repository: repository);
    addTearDown(controller.dispose);

    await controller.loadAssignedVehicle('driver-001');
    expect(controller.assignedVehicle?.id, _vehicles.first.id);
    expect(controller.currentUsageSession, isNull);

    final received = await controller.receiveAssignedVehicle(
      userId: 'driver-001',
      mileage: 250,
      inspection: _inspection,
    );
    expect(received, isTrue);
    expect(controller.currentUsageSession?.receivedMileage, 250);
    expect(controller.assignedVehicle?.currentMileage, 250);

    final record = await controller.createVehicleRecord(
      currentUser: _recordDriver,
      request: const CreateVehicleRecordRequest(
        type: VehicleRecordType.maintenance,
        title: 'Periyodik bakım',
        description: 'Motor yağı ve filtre değiştirildi.',
        mileage: 275,
      ),
    );
    expect(record?.type, VehicleRecordType.maintenance);
    expect(controller.assignedVehicleRecords, hasLength(1));
    expect(controller.assignedVehicle?.currentMileage, 275);

    final faultRecord = await controller.createVehicleRecord(
      currentUser: _recordDriver,
      request: const CreateVehicleRecordRequest(
        type: VehicleRecordType.fault,
        title: 'Fren arızası',
        description: 'Fren pedalında boşluk var.',
        mileage: 280,
      ),
    );
    final reviewed = await controller.reviewVehicleFault(
      record: faultRecord!,
      currentUser: _reviewChief,
      decision: VehicleFaultReviewDecision.takeToMaintenance,
      note: 'Araç servise yönlendirildi.',
    );
    expect(reviewed, isTrue);
    expect(
      controller.assignedVehicle?.operationalStatus,
      VehicleOperationalStatus.maintenance,
    );

    final returned = await controller.returnAssignedVehicle(
      userId: 'driver-001',
      mileage: 300,
      inspection: _inspection,
    );
    expect(returned, isTrue);
    expect(controller.currentUsageSession, isNull);
    expect(controller.assignedVehicle, isNull);
    expect(controller.currentUserAssignment, isNull);
  });

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

  test(
    'güncelleme araç kaydını yerinde değiştirip sayaçları yeniler',
    () async {
      final controller = VehicleController(
        repository: FakeVehicleRepository(
          vehicles: [_vehicles.first],
          delay: Duration.zero,
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final updated = await controller.updateVehicle(
        vehicleId: _vehicles.first.id,
        request: _updateRequest(status: VehicleOperationalStatus.maintenance),
      );

      expect(updated?.id, _vehicles.first.id);
      expect(controller.totalCount, 1);
      expect(controller.activeCount, 0);
      expect(controller.maintenanceCount, 1);
      expect(
        controller.allVehicles.single.operationalStatus,
        VehicleOperationalStatus.maintenance,
      );
    },
  );
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

UpdateVehicleRequest _updateRequest({
  VehicleOperationalStatus status = VehicleOperationalStatus.active,
}) => UpdateVehicleRequest(
  licensePlate: '81 KGM 001',
  brand: 'Ford',
  model: 'Ranger',
  modelYear: 2024,
  currentMileage: 2000,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: status,
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

  @override
  Future<Vehicle> updateVehicle({
    required String vehicleId,
    required UpdateVehicleRequest request,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<VehicleAssignment>> getVehicleAssignments(String vehicleId) {
    throw UnimplementedError();
  }

  @override
  Future<VehicleAssignment> assignVehicle({
    required String vehicleId,
    required String userId,
    required String userName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> releaseVehicle(String vehicleId) {
    throw UnimplementedError();
  }

  @override
  Future<VehicleAssignment?> getActiveAssignmentForUser(String userId) {
    throw UnimplementedError();
  }

  @override
  Future<VehicleUsageSession?> getActiveUsageSessionForUser(String userId) {
    throw UnimplementedError();
  }

  @override
  Future<List<VehicleUsageSession>> getVehicleUsageSessions(String vehicleId) {
    throw UnimplementedError();
  }

  @override
  Future<VehicleUsageSession> receiveVehicle({
    required String userId,
    required int mileage,
    required VehicleInspection inspection,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<VehicleUsageSession> returnVehicle({
    required String userId,
    required int mileage,
    required VehicleInspection inspection,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<VehicleRecord>> getVehicleRecords(String vehicleId) async =>
      const [];

  @override
  Future<VehicleRecord> createVehicleRecord({
    required String userId,
    required String userName,
    required CreateVehicleRecordRequest request,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<VehicleRecord>> getOpenVehicleFaults() async => const [];

  @override
  Future<VehicleRecord> reviewVehicleFault({
    required String recordId,
    required String reviewedByUserId,
    required String reviewedByName,
    required ReviewVehicleFaultRequest request,
  }) {
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

const _inspection = VehicleInspection(
  bodyworkOkay: true,
  tiresOkay: true,
  lightsOkay: true,
  glassAndMirrorsOkay: true,
  leakFree: true,
  equipmentComplete: true,
  notes: '',
);

const _recordDriver = AppUser(
  id: 'driver-001',
  fullName: 'Test Şoför',
  username: 'test.sofor',
  role: UserRole.driver,
  permissions: {},
);

const _reviewChief = AppUser(
  id: 'chief-001',
  fullName: 'Test Şef',
  username: 'test.sef',
  role: UserRole.chief,
  permissions: {},
);

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
