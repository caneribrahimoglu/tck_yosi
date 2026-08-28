import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/vehicles/data/repositories/fake_vehicle_repository.dart';
import 'package:tck_yosi/features/vehicles/domain/enums/vehicle_ownership_type.dart';
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
}

VehicleController _controller() => VehicleController(
  repository: FakeVehicleRepository(vehicles: [], delay: Duration.zero),
);

Widget _app(VehicleController controller) => MaterialApp(
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
  home: CreateVehiclePage(controller: controller),
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
