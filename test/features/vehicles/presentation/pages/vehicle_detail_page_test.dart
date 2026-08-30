import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle_inspection.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_record_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_fault_review_decision.dart';
import 'package:tck_yosi/features/vehicles/domain/models/create_vehicle_record_request.dart';
import 'package:tck_yosi/features/vehicles/domain/models/review_vehicle_fault_request.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_detail_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/pages/vehicle_detail_page.dart';

void main() {
  testWidgets('araç detayında gerçek model bilgilerini gösterir', (
    tester,
  ) async {
    final controller = VehicleDetailController(
      repository: FakeVehicleRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, 'vehicle-demo-003'));
    await tester.pumpAndSettle();

    expect(find.text('81 DEM 303'), findsNWidgets(2));
    expect(find.text('Mercedes-Benz Arocs'), findsNWidgets(2));
    expect(find.text('Sözleşmeli'), findsNWidgets(2));
    expect(find.text('Demo Yol Hizmetleri A.Ş.'), findsOneWidget);
    expect(find.text('35.800 km'), findsOneWidget);
    expect(find.text('Muayene'), findsNothing);
  });

  testWidgets('bilinmeyen kimlik güvenli bulunamadı durumu gösterir', (
    tester,
  ) async {
    final controller = VehicleDetailController(
      repository: FakeVehicleRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, 'missing'));
    await tester.pumpAndSettle();

    expect(find.text('Araç kaydı bulunamadı.'), findsOneWidget);
  });

  testWidgets('mobil yerleşim yatay taşma oluşturmadan gösterilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = VehicleDetailController(
      repository: FakeVehicleRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, 'vehicle-demo-001'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Araç Bilgileri'), findsOneWidget);
    expect(find.text('Mülkiyet Bilgileri'), findsOneWidget);
  });

  testWidgets('düzenleme callbacki varsa düzenle aksiyonu aracı iletir', (
    tester,
  ) async {
    final controller = VehicleDetailController(
      repository: FakeVehicleRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);
    Vehicle? selectedVehicle;

    await tester.pumpWidget(
      _app(
        controller,
        'vehicle-demo-001',
        onEditVehicle: (vehicle) async => selectedVehicle = vehicle,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pump();

    expect(selectedVehicle?.id, 'vehicle-demo-001');
  });

  testWidgets('mevcut personel atamasını ve yönetme aksiyonunu gösterir', (
    tester,
  ) async {
    final controller = VehicleDetailController(
      repository: FakeVehicleRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);
    Vehicle? selectedVehicle;

    await tester.pumpWidget(
      _app(
        controller,
        'vehicle-demo-001',
        onManageAssignment: (vehicle) async => selectedVehicle = vehicle,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personel Ataması ve Kullanım Geçmişi'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('Atamayı Yönet'), findsOneWidget);
    await tester.tap(find.text('Atamayı Yönet'));
    await tester.pump();
    expect(selectedVehicle?.id, 'vehicle-demo-001');
  });

  testWidgets(
    'teslim alınan aracın kullanım kilometresi şef detayında görünür',
    (tester) async {
      final repository = FakeVehicleRepository(delay: Duration.zero);
      await repository.receiveVehicle(
        userId: 'user-driver-001',
        mileage: 48500,
        inspection: const VehicleInspection(
          bodyworkOkay: true,
          tiresOkay: true,
          lightsOkay: true,
          glassAndMirrorsOkay: true,
          leakFree: true,
          equipmentComplete: true,
          notes: 'Silecekler sesli çalışıyor.',
        ),
      );
      final controller = VehicleDetailController(repository: repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller, 'vehicle-demo-001'));
      await tester.pumpAndSettle();

      expect(find.text('Teslim ve iade kayıtları'), findsOneWidget);
      expect(find.textContaining('Teslim:'), findsOneWidget);
      expect(find.textContaining('48.500'), findsNWidgets(2));
      expect(find.text('Araç halen kullanıcıda'), findsOneWidget);
      expect(
        find.text('Teslim notu: Silecekler sesli çalışıyor.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('uygun olmayan kontroller başlık ve açıklamayla gösterilir', (
    tester,
  ) async {
    final repository = FakeVehicleRepository(delay: Duration.zero);
    await repository.receiveVehicle(
      userId: 'user-driver-001',
      mileage: 48320,
      inspection: const VehicleInspection(
        bodyworkOkay: true,
        tiresOkay: true,
        lightsOkay: true,
        wipersOkay: false,
        glassAndMirrorsOkay: true,
        leakFree: true,
        equipmentComplete: true,
        notes: 'Sağ taraftaki kötü siliyor, iz bırakıyor.',
      ),
    );
    final controller = VehicleDetailController(repository: repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, 'vehicle-demo-001'));
    await tester.pumpAndSettle();

    expect(
      find.text('Teslim sırasında tespit edilen sorunlar'),
      findsOneWidget,
    );
    expect(find.text('Silecek arızası'), findsOneWidget);
    expect(
      find.text('Açıklama: Sağ taraftaki kötü siliyor, iz bırakıyor.'),
      findsOneWidget,
    );
  });

  testWidgets('arıza ve bakım kayıtları şef araç detayında görünür', (
    tester,
  ) async {
    final repository = FakeVehicleRepository(delay: Duration.zero);
    await repository.receiveVehicle(
      userId: 'user-driver-001',
      mileage: 48320,
      inspection: _allOkayInspection,
    );
    final fault = await repository.createVehicleRecord(
      userId: 'user-driver-001',
      userName: 'Ahmet Yılmaz',
      request: const CreateVehicleRecordRequest(
        type: VehicleRecordType.fault,
        title: 'Silecek arızası',
        description: 'Sağ silecek iz bırakıyor.',
        mileage: 48400,
      ),
    );
    await repository.reviewVehicleFault(
      recordId: fault.id,
      reviewedByUserId: 'chief-vehicle-detail-test',
      reviewedByName: 'Test Şef',
      request: const ReviewVehicleFaultRequest(
        decision: VehicleFaultReviewDecision.continueInService,
        note: 'Bir sonraki bakımda değiştirilecek.',
      ),
    );
    final controller = VehicleDetailController(repository: repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, 'vehicle-demo-001'));
    await tester.pumpAndSettle();

    expect(find.text('Arıza ve Bakım Geçmişi'), findsOneWidget);
    expect(find.text('Arıza: Silecek arızası'), findsOneWidget);
    expect(find.text('Sağ silecek iz bırakıyor.'), findsOneWidget);
    expect(find.text('Kullanıma Devam'), findsOneWidget);
    expect(
      find.textContaining('Bir sonraki bakımda değiştirilecek.'),
      findsOneWidget,
    );
    expect(find.textContaining('Ahmet Yılmaz'), findsWidgets);
  });
}

Widget _app(
  VehicleDetailController controller,
  String vehicleId, {
  Future<void> Function(Vehicle vehicle)? onEditVehicle,
  Future<void> Function(Vehicle vehicle)? onManageAssignment,
}) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: VehicleDetailPage(
      vehicleId: vehicleId,
      currentUser: _chief,
      onLogout: () async {},
      controller: controller,
      onEditVehicle: onEditVehicle,
      onManageAssignment: onManageAssignment,
    ),
  );
}

const _chief = AppUser(
  id: 'chief-vehicle-detail-test',
  fullName: 'Test Şef',
  username: 'test.sef',
  role: UserRole.chief,
  permissions: {AppPermission.viewVehicleFleet},
);

const _allOkayInspection = VehicleInspection(
  bodyworkOkay: true,
  tiresOkay: true,
  lightsOkay: true,
  glassAndMirrorsOkay: true,
  leakFree: true,
  equipmentComplete: true,
  notes: '',
);
