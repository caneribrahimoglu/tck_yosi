import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/shared/widgets/responsive_metric_strip.dart';

void main() {
  testWidgets('normal telefonda dört metriği tek satırda gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(_app(width: 350));

    final positions = _positions(tester);
    expect(positions[1].dx, greaterThan(positions[0].dx));
    expect(positions[2].dx, greaterThan(positions[1].dx));
    expect(positions[3].dx, greaterThan(positions[2].dx));
    expect(positions.map((position) => position.dy).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dar ekranda dört metriği ikiye iki gösterir', (tester) async {
    await tester.pumpWidget(_app(width: 280));

    final positions = _positions(tester);
    expect(positions[1].dx, greaterThan(positions[0].dx));
    expect((positions[1].dy - positions[0].dy).abs(), lessThan(1));
    expect((positions[2].dx - positions[0].dx).abs(), lessThan(1));
    expect(positions[2].dy, greaterThan(positions[0].dy));
    expect(positions[3].dx, greaterThan(positions[2].dx));
    expect((positions[3].dy - positions[2].dy).abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });
}

Widget _app({required double width}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: ResponsiveMetricStrip(
          metrics: const [
            AppMetric(
              label: 'Toplam Araç',
              compactLabel: 'Toplam',
              value: '4',
              icon: Icons.directions_car_outlined,
              color: Colors.purple,
              itemKey: ValueKey('metric-0'),
            ),
            AppMetric(
              label: 'Aktif',
              value: '2',
              icon: Icons.check_circle_outline,
              color: Colors.green,
              itemKey: ValueKey('metric-1'),
            ),
            AppMetric(
              label: 'Bakımda',
              value: '1',
              icon: Icons.build_outlined,
              color: Colors.orange,
              itemKey: ValueKey('metric-2'),
            ),
            AppMetric(
              label: 'Sözleşmeli',
              value: '2',
              icon: Icons.handshake_outlined,
              color: Colors.blue,
              itemKey: ValueKey('metric-3'),
            ),
          ],
        ),
      ),
    ),
  ),
);

List<Offset> _positions(WidgetTester tester) => [
  for (var index = 0; index < 4; index++)
    tester.getTopLeft(find.byKey(ValueKey('metric-$index'))),
];
