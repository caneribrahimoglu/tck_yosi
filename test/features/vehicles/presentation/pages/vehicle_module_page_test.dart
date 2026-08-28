import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/models/vehicle.dart';
import 'package:tck_yosi/features/vehicles/domain/repositories/vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/presentation/controllers/vehicle_controller.dart';
import 'package:tck_yosi/features/vehicles/presentation/pages/vehicle_module_page.dart';
import 'package:tck_yosi/shared/widgets/app_text_field.dart';

void main() {
  testWidgets('sayfa loading ve ardından gerçek demo filo durumunu gösterir', (
    tester,
  ) async {
    final completer = Completer<List<Vehicle>>();
    final controller = VehicleController(
      repository: _VehicleRepository(completer: completer),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pump();
    expect(find.text('Araçlar yükleniyor...'), findsOneWidget);

    final demoVehicles = await FakeVehicleRepository(
      delay: Duration.zero,
    ).getAllVehicles();
    completer.complete(demoVehicles);
    await tester.pumpAndSettle();

    expect(find.text('Toplam Araç'), findsOneWidget);
    expect(find.text('Filo Listesi (4)'), findsOneWidget);
    expect(find.text('81 KGM 101'), findsOneWidget);
    expect(find.text('81 DEM 303'), findsOneWidget);
    expect(find.text('Kuruma Ait'), findsNWidgets(2));
    expect(find.text('Sözleşmeli'), findsNWidgets(3));
    expect(find.text('Yüklenici: Demo Yol Hizmetleri A.Ş.'), findsOneWidget);
  });

  testWidgets('failure durumu güvenli mesaj ve tekrar dene aksiyonu gösterir', (
    tester,
  ) async {
    final controller = VehicleController(
      repository: _VehicleRepository(error: StateError('test')),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Araç bilgileri yüklenemedi.'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets('boş filo güvenli empty state gösterir', (tester) async {
    final controller = VehicleController(
      repository: FakeVehicleRepository(vehicles: [], delay: Duration.zero),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Henüz araç kaydı bulunmuyor.'), findsOneWidget);
    expect(find.text('Araç Ekle'), findsNothing);
  });

  testWidgets('arama ve mülkiyet filtresi listeyi etkileşimle daraltır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = VehicleController(
      repository: FakeVehicleRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    final searchField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Araç ara',
      ),
      matching: find.byType(EditableText),
    );
    await tester.enterText(searchField, 'arocs');
    await tester.pump();

    expect(find.text('81 DEM 303'), findsOneWidget);
    expect(find.text('81 KGM 101'), findsNothing);

    await tester.tap(find.text('Filtreleri Temizle'));
    await tester.pump();
    await tester.tap(find.text('Tüm mülkiyet tipleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sözleşmeli').last);
    await tester.pumpAndSettle();

    expect(find.text('81 DEM 303'), findsOneWidget);
    expect(find.text('81 DEM 404'), findsOneWidget);
    expect(find.text('81 KGM 101'), findsNothing);

    await tester.tap(find.text('Filtreleri Temizle'));
    await tester.pump();
    await tester.tap(find.text('Tüm durumlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bakımda').last);
    await tester.pumpAndSettle();

    expect(find.text('81 KGM 202'), findsOneWidget);
    expect(find.text('81 DEM 303'), findsNothing);
  });

  testWidgets('mobil ve geniş yerleşim yatay taşma olmadan oluşur', (
    tester,
  ) async {
    final controller = VehicleController(
      repository: FakeVehicleRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);
    await controller.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(390, 1100);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('81 KGM 101'), findsOneWidget);

    final totalSummary = find.byKey(const ValueKey('vehicle-summary-total'));
    final activeSummary = find.byKey(const ValueKey('vehicle-summary-active'));
    final maintenanceSummary = find.byKey(
      const ValueKey('vehicle-summary-maintenance'),
    );
    final totalPosition = tester.getTopLeft(totalSummary);
    final activePosition = tester.getTopLeft(activeSummary);
    final maintenancePosition = tester.getTopLeft(maintenanceSummary);

    expect(activePosition.dx, greaterThan(totalPosition.dx));
    expect((activePosition.dy - totalPosition.dy).abs(), lessThan(1));
    expect((maintenancePosition.dx - totalPosition.dx).abs(), lessThan(1));
    expect(maintenancePosition.dy, greaterThan(totalPosition.dy));

    tester.view.physicalSize = const Size(1400, 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('81 DEM 404'), findsOneWidget);
  });

  testWidgets('araç kartına dokununca seçilen araç geri bildirilir', (
    tester,
  ) async {
    final controller = VehicleController(
      repository: FakeVehicleRepository(delay: Duration.zero),
    );
    addTearDown(controller.dispose);
    Vehicle? selectedVehicle;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: VehicleModulePage(
          currentUser: _chief,
          onLogout: () async {},
          controller: controller,
          onViewVehicle: (vehicle) => selectedVehicle = vehicle,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final vehicleCard = find.byKey(const ValueKey('vehicle-vehicle-demo-001'));
    await tester.ensureVisible(vehicleCard);
    await tester.pumpAndSettle();
    await tester.tap(vehicleCard);
    await tester.pump();

    expect(selectedVehicle?.id, 'vehicle-demo-001');
  });
}

Widget _app(VehicleController controller) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: VehicleModulePage(
      currentUser: _chief,
      onLogout: () async {},
      controller: controller,
    ),
  );
}

class _VehicleRepository implements VehicleRepository {
  final Completer<List<Vehicle>>? completer;
  final Object? error;

  _VehicleRepository({this.completer, this.error});

  @override
  Future<List<Vehicle>> getAllVehicles() async {
    if (error != null) {
      throw error!;
    }
    return completer?.future ?? const [];
  }

  @override
  Future<Vehicle?> getVehicleById(String vehicleId) async => null;
}

const _chief = AppUser(
  id: 'chief-vehicle-test',
  fullName: 'Test Şef',
  username: 'test.sef',
  role: UserRole.chief,
  permissions: {AppPermission.viewVehicleFleet},
);
