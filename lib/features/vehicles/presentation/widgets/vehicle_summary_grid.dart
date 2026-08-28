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
      (
        'total',
        'Toplam Araç',
        controller.totalCount,
        Icons.directions_car_outlined,
      ),
      (
        'active',
        'Aktif',
        controller.activeCount,
        Icons.check_circle_outline_rounded,
      ),
      (
        'maintenance',
        'Bakımda',
        controller.maintenanceCount,
        Icons.build_outlined,
      ),
      (
        'contracted',
        'Sözleşmeli',
        controller.contractedCount,
        Icons.handshake_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : 2;
        final isCompact = constraints.maxWidth < 520;
        final spacing = AppSpacing.md * (columns - 1);
        final width = (constraints.maxWidth - spacing) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final summary in summaries)
              SizedBox(
                width: width,
                height: isCompact ? 112 : null,
                child: AppCard(
                  key: ValueKey('vehicle-summary-${summary.$1}'),
                  padding: EdgeInsets.all(
                    isCompact ? AppSpacing.md : AppSpacing.lg,
                  ),
                  child: isCompact
                      ? _CompactSummary(
                          label: summary.$2,
                          value: summary.$3,
                          icon: summary.$4,
                        )
                      : _WideSummary(
                          label: summary.$2,
                          value: summary.$3,
                          icon: summary.$4,
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CompactSummary extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _CompactSummary({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              value.toString(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _WideSummary extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _WideSummary({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ],
    );
  }
}
