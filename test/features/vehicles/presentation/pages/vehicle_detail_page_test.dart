import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
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
