import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_record_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_fault_review_decision.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/update_vehicle_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_inspection.dart';
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_record_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/review_vehicle_fault_request.dart';
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

  test('aktif araç personele atanır', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );

    final assignment = await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );

    expect(assignment.assignedToUserId, 'driver-001');
    expect(assignment.assignedToName, 'Test Şoför');
    expect(assignment.isActive, isTrue);
    expect(await repository.getVehicleAssignments('vehicle-001'), [assignment]);
  });

  test('araç başka personele devredilince önceki atama kapanır', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'İlk Şoför',
    );

    final current = await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-002',
      userName: 'İkinci Şoför',
    );
    final history = await repository.getVehicleAssignments('vehicle-001');

    expect(history, hasLength(2));
    expect(history.where((assignment) => assignment.isActive).single, current);
    expect(history.where((assignment) => !assignment.isActive), hasLength(1));
  });

  test('bakımdaki araç personele atanamaz', () async {
    final repository = FakeVehicleRepository(
      vehicles: [
        _vehicle('vehicle-001', status: VehicleOperationalStatus.maintenance),
      ],
      delay: Duration.zero,
    );

    expect(
      () => repository.assignVehicle(
        vehicleId: 'vehicle-001',
        userId: 'driver-001',
        userName: 'Test Şoför',
      ),
      throwsA(
        isA<VehicleRepositoryException>().having(
          (error) => error.message,
          'message',
          'Yalnızca aktif durumdaki araçlar personele atanabilir.',
        ),
      ),
    );
  });

  test('aktif atama sonlandırılır ve geçmişte korunur', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );

    await repository.releaseVehicle('vehicle-001');
    final history = await repository.getVehicleAssignments('vehicle-001');

    expect(history.single.isActive, isFalse);
    expect(history.single.endedAt, isNotNull);
  });

  test('teslim alma kilometreyi günceller ve kullanım oturumu açar', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );

    final session = await repository.receiveVehicle(
      userId: 'driver-001',
      mileage: 150,
      inspection: _inspection,
    );

    expect(session.receivedMileage, 150);
    expect(session.isActive, isTrue);
    expect(
      (await repository.getVehicleById('vehicle-001'))?.currentMileage,
      150,
    );
    expect(
      (await repository.getActiveUsageSessionForUser('driver-001'))?.id,
      session.id,
    );
  });

  test('teslim kilometresi güncel kilometreden düşük olamaz', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );

    expect(
      () => repository.receiveVehicle(
        userId: 'driver-001',
        mileage: 99,
        inspection: _inspection,
      ),
      throwsA(isA<VehicleRepositoryException>()),
    );
  });

  test('kontrolde sorun varsa açıklama zorunludur', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );

    expect(
      () => repository.receiveVehicle(
        userId: 'driver-001',
        mileage: 100,
        inspection: const VehicleInspection(
          bodyworkOkay: false,
          tiresOkay: true,
          lightsOkay: true,
          glassAndMirrorsOkay: true,
          leakFree: true,
          equipmentComplete: true,
          notes: '',
        ),
      ),
      throwsA(
        isA<VehicleRepositoryException>().having(
          (error) => error.message,
          'message',
          'Kontrolde sorun işaretlendiyse açıklama zorunludur.',
        ),
      ),
    );
  });

  test('iade kilometreyi günceller, oturumu ve atamayı kapatır', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );
    await repository.receiveVehicle(
      userId: 'driver-001',
      mileage: 150,
      inspection: _inspection,
    );

    final returned = await repository.returnVehicle(
      userId: 'driver-001',
      mileage: 225,
      inspection: _inspection,
    );

    expect(returned.isActive, isFalse);
    expect(returned.returnedMileage, 225);
    expect(
      (await repository.getVehicleById('vehicle-001'))?.currentMileage,
      225,
    );
    expect(await repository.getActiveAssignmentForUser('driver-001'), isNull);
    expect(await repository.getActiveUsageSessionForUser('driver-001'), isNull);
    expect(await repository.getVehicleUsageSessions('vehicle-001'), [returned]);
  });

  test('teslim alınmış aracın ataması yönetimden kapatılamaz', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );
    await repository.receiveVehicle(
      userId: 'driver-001',
      mileage: 100,
      inspection: _inspection,
    );

    expect(
      () => repository.releaseVehicle('vehicle-001'),
      throwsA(isA<VehicleRepositoryException>()),
    );
  });

  test(
    'teslim alınmış araç iade edilmeden başka personele devredilemez',
    () async {
      final repository = FakeVehicleRepository(
        vehicles: [_vehicle('vehicle-001')],
        delay: Duration.zero,
      );
      await repository.assignVehicle(
        vehicleId: 'vehicle-001',
        userId: 'driver-001',
        userName: 'İlk Şoför',
      );
      await repository.receiveVehicle(
        userId: 'driver-001',
        mileage: 100,
        inspection: _inspection,
      );

      expect(
        () => repository.assignVehicle(
          vehicleId: 'vehicle-001',
          userId: 'driver-002',
          userName: 'İkinci Şoför',
        ),
        throwsA(isA<VehicleRepositoryException>()),
      );
    },
  );

  test('personele aynı anda ikinci aktif araç atanamaz', () async {
    final repository = FakeVehicleRepository(
      vehicles: [
        _vehicle('vehicle-001'),
        _vehicle('vehicle-002', plate: '81 TST 002'),
      ],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );

    expect(
      () => repository.assignVehicle(
        vehicleId: 'vehicle-002',
        userId: 'driver-001',
        userName: 'Test Şoför',
      ),
      throwsA(isA<VehicleRepositoryException>()),
    );
  });

  test(
    'teslim alınmış araca arıza kaydı ekler ve kilometreyi günceller',
    () async {
      final repository = FakeVehicleRepository(
        vehicles: [_vehicle('vehicle-001')],
        delay: Duration.zero,
      );
      await repository.assignVehicle(
        vehicleId: 'vehicle-001',
        userId: 'driver-001',
        userName: 'Test Şoför',
      );
      await repository.receiveVehicle(
        userId: 'driver-001',
        mileage: 120,
        inspection: _inspection,
      );

      final record = await repository.createVehicleRecord(
        userId: 'driver-001',
        userName: 'Test Şoför',
        request: const CreateVehicleRecordRequest(
          type: VehicleRecordType.fault,
          title: 'Silecek arızası',
          description: 'Sağ silecek iz bırakıyor.',
          mileage: 150,
        ),
      );

      expect(record.type, VehicleRecordType.fault);
      expect(record.usageSessionId, isNotEmpty);
      expect(
        (await repository.getVehicleRecords('vehicle-001')).single,
        record,
      );
      expect(
        (await repository.getVehicleById('vehicle-001'))?.currentMileage,
        150,
      );
    },
  );

  test('araç teslim alınmadan arıza veya bakım kaydı eklenemez', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );

    expect(
      () => repository.createVehicleRecord(
        userId: 'driver-001',
        userName: 'Test Şoför',
        request: const CreateVehicleRecordRequest(
          type: VehicleRecordType.maintenance,
          title: 'Yağ değişimi',
          description: 'Motor yağı değiştirildi.',
          mileage: 150,
        ),
      ),
      throwsA(isA<VehicleRepositoryException>()),
    );
  });

  test(
    'arıza şef inceleme kuyruğuna düşer ve bakım kararı iz bırakır',
    () async {
      final repository = FakeVehicleRepository(
        vehicles: [_vehicle('vehicle-001')],
        delay: Duration.zero,
      );
      await repository.assignVehicle(
        vehicleId: 'vehicle-001',
        userId: 'driver-001',
        userName: 'Test Şoför',
      );
      await repository.receiveVehicle(
        userId: 'driver-001',
        mileage: 120,
        inspection: _inspection,
      );
      final fault = await repository.createVehicleRecord(
        userId: 'driver-001',
        userName: 'Test Şoför',
        request: const CreateVehicleRecordRequest(
          type: VehicleRecordType.fault,
          title: 'Fren arızası',
          description: 'Fren pedalında boşluk var.',
          mileage: 130,
        ),
      );

      expect(await repository.getOpenVehicleFaults(), [fault]);

      final reviewed = await repository.reviewVehicleFault(
        recordId: fault.id,
        reviewedByUserId: 'chief-001',
        reviewedByName: 'Test Şef',
        request: const ReviewVehicleFaultRequest(
          decision: VehicleFaultReviewDecision.takeToMaintenance,
          note: 'Araç servise yönlendirildi.',
        ),
      );

      expect(
        reviewed.latestFaultReview?.decision,
        VehicleFaultReviewDecision.takeToMaintenance,
      );
      expect(reviewed.latestFaultReview?.reviewedByName, 'Test Şef');
      expect(reviewed.latestFaultReview?.note, 'Araç servise yönlendirildi.');
      expect(
        (await repository.getVehicleById('vehicle-001'))?.operationalStatus,
        VehicleOperationalStatus.maintenance,
      );
    },
  );

  test('çözülen arıza açık kuyruktan çıkar ve araç aktifleşir', () async {
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle('vehicle-001')],
      delay: Duration.zero,
    );
    await repository.assignVehicle(
      vehicleId: 'vehicle-001',
      userId: 'driver-001',
      userName: 'Test Şoför',
    );
    await repository.receiveVehicle(
      userId: 'driver-001',
      mileage: 120,
      inspection: _inspection,
    );
    final fault = await repository.createVehicleRecord(
      userId: 'driver-001',
      userName: 'Test Şoför',
      request: const CreateVehicleRecordRequest(
        type: VehicleRecordType.fault,
        title: 'Silecek arızası',
        description: 'Silecek iz bırakıyor.',
        mileage: 130,
      ),
    );
    await repository.reviewVehicleFault(
      recordId: fault.id,
      reviewedByUserId: 'chief-001',
      reviewedByName: 'Test Şef',
      request: const ReviewVehicleFaultRequest(
        decision: VehicleFaultReviewDecision.takeToMaintenance,
        note: 'Silecek değiştirilecek.',
      ),
    );

    final resolved = await repository.reviewVehicleFault(
      recordId: fault.id,
      reviewedByUserId: 'chief-001',
      reviewedByName: 'Test Şef',
      request: const ReviewVehicleFaultRequest(
        decision: VehicleFaultReviewDecision.resolve,
        note: 'Silecek değiştirildi ve kontrol edildi.',
      ),
    );

    expect(resolved.faultReviews, hasLength(2));
    expect(resolved.isFaultResolved, isTrue);
    expect(await repository.getOpenVehicleFaults(), isEmpty);
    expect(
      (await repository.getVehicleById('vehicle-001'))?.operationalStatus,
      VehicleOperationalStatus.active,
    );
  });
}

const _inspection = VehicleInspection(
  bodyworkOkay: true,
  tiresOkay: true,
  lightsOkay: true,
  glassAndMirrorsOkay: true,
  leakFree: true,
  equipmentComplete: true,
  notes: '',
);

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

Vehicle _vehicle(
  String id, {
  String plate = '81 TST 001',
  VehicleOperationalStatus status = VehicleOperationalStatus.active,
}) => Vehicle(
  id: id,
  licensePlate: plate,
  brand: 'Demo',
  model: 'Model',
  modelYear: 2022,
  currentMileage: 100,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: status,
  type: VehicleType.pickup,
);
