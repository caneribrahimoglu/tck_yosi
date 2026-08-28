import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_operational_status.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_type.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/pages/create_vehicle_page.dart';
import 'package:tck_yosi/shared/widgets/app_text_field.dart';

void main() {
  testWidgets('zorunlu alanlar boşken repositoryye araç göndermez', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.ensureVisible(find.text('Aracı Kaydet'));
    await tester.tap(find.text('Aracı Kaydet'));
    await tester.pump();

    expect(find.text('Bu alan zorunludur.'), findsNWidgets(3));
    expect(controller.totalCount, 0);
  });

  testWidgets('sözleşmeli araçta yüklenici zorunlu olur ve kayıt eklenir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await _enter(tester, 'Plaka', '81 YEN 001');
    await _enter(tester, 'Marka', 'Ford');
    await _enter(tester, 'Model', 'Ranger');
    await tester.tap(find.text('Kuruma Ait'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sözleşmeli').last);
    await tester.pumpAndSettle();

    expect(find.text('Yüklenici firma'), findsOneWidget);
    await _enter(tester, 'Yüklenici firma', 'Demo Filo A.Ş.');
    await tester.ensureVisible(find.text('Aracı Kaydet'));
    await tester.tap(find.text('Aracı Kaydet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.totalCount, 1);
    expect(
      controller.allVehicles.single.ownershipType,
      VehicleOwnershipType.contracted,
    );
    expect(controller.allVehicles.single.contractorName, 'Demo Filo A.Ş.');
  });

  testWidgets('düzenleme formu mevcut bilgileri gösterir ve durumu günceller', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeVehicleRepository(
      vehicles: [_vehicle],
      delay: Duration.zero,
    );
    final controller = VehicleController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(_editApp(controller, _vehicle));
    await tester.pumpAndSettle();

    expect(find.text('Araç Bilgilerini Düzenle'), findsOneWidget);
    expect(find.text('81 TST 001'), findsOneWidget);
    await tester.tap(find.text('Aktif'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bakımda').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Değişiklikleri Kaydet'));
    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      controller.allVehicles.single.operationalStatus,
      VehicleOperationalStatus.maintenance,
    );
  });
}

VehicleController _controller() => VehicleController(
  repository: FakeVehicleRepository(vehicles: [], delay: Duration.zero),
);

Widget _app(VehicleController controller) => MaterialApp(
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
  home: CreateVehiclePage(controller: controller),
);

Widget _editApp(VehicleController controller, Vehicle vehicle) => MaterialApp(
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
  home: CreateVehiclePage.edit(controller: controller, vehicle: vehicle),
);

final _vehicle = Vehicle(
  id: 'vehicle-test-edit',
  licensePlate: '81 TST 001',
  brand: 'Ford',
  model: 'Ranger',
  modelYear: 2022,
  currentMileage: 1000,
  ownershipType: VehicleOwnershipType.institutionOwned,
  operationalStatus: VehicleOperationalStatus.active,
  type: VehicleType.pickup,
);

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is AppTextField && widget.label == label,
    ),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}
