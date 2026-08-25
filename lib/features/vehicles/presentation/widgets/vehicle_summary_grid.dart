import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../controllers/vehicle_controller.dart';

class VehicleSummaryGrid extends StatelessWidget {
  final VehicleController controller;

  const VehicleSummaryGrid({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final summaries = [
      ('Toplam Araç', controller.totalCount, Icons.directions_car_outlined),
      ('Aktif', controller.activeCount, Icons.check_circle_outline_rounded),
      ('Bakımda', controller.maintenanceCount, Icons.build_outlined),
      ('Sözleşmeli', controller.contractedCount, Icons.handshake_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final spacing = AppSpacing.md * (columns - 1);
        final width = (constraints.maxWidth - spacing) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final summary in summaries)
              SizedBox(
                width: width,
                child: AppCard(
                  child: Row(
                    children: [
                      Icon(
                        summary.$3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.$2.toString(),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(summary.$1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
