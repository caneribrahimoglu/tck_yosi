import 'package:flutter/material.dart';

import '../../../../shared/widgets/responsive_metric_strip.dart';
import '../controllers/vehicle_controller.dart';

class VehicleSummaryGrid extends StatelessWidget {
  final VehicleController controller;

  const VehicleSummaryGrid({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ResponsiveMetricStrip(
      metrics: [
        AppMetric(
          label: 'Toplam Araç',
          compactLabel: 'Toplam',
          value: controller.totalCount.toString(),
          icon: Icons.directions_car_outlined,
          color: primary,
          itemKey: const ValueKey('vehicle-summary-total'),
        ),
        AppMetric(
          label: 'Aktif',
          value: controller.activeCount.toString(),
          icon: Icons.check_circle_outline_rounded,
          color: Colors.green,
          itemKey: const ValueKey('vehicle-summary-active'),
        ),
        AppMetric(
          label: 'Bakımda',
          value: controller.maintenanceCount.toString(),
          icon: Icons.build_outlined,
          color: Colors.orange,
          itemKey: const ValueKey('vehicle-summary-maintenance'),
        ),
        AppMetric(
          label: 'Sözleşmeli',
          value: controller.contractedCount.toString(),
          icon: Icons.handshake_outlined,
          color: primary,
          itemKey: const ValueKey('vehicle-summary-contracted'),
        ),
      ],
    );
  }
}
