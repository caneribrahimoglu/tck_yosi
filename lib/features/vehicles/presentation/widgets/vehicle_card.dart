import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../domain/enums/vehicle_ownership_type.dart';
import '../../domain/models/vehicle.dart';
import '../vehicle_presentation.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;

  const VehicleCard({super.key, required this.vehicle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: ValueKey('vehicle-${vehicle.id}'),
      onTap: onTap,
      shadows: AppShadows.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  vehicle.type.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.licensePlate,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('${vehicle.brand} ${vehicle.model}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppStatusChip(
                label: vehicle.ownershipType.label,
                type: vehicle.ownershipType.statusType,
              ),
              AppStatusChip(
                label: vehicle.operationalStatus.label,
                type: vehicle.operationalStatus.statusType,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _VehicleFact(
                icon: Icons.category_outlined,
                text: vehicle.type.label,
              ),
              if (vehicle.modelYear != null)
                _VehicleFact(
                  icon: Icons.calendar_today_outlined,
                  text: vehicle.modelYear.toString(),
                ),
              _VehicleFact(
                icon: Icons.speed_rounded,
                text: vehicle.formattedMileage,
              ),
            ],
          ),
          if (vehicle.ownershipType == VehicleOwnershipType.contracted &&
              vehicle.contractorName != null) ...[
            const SizedBox(height: AppSpacing.md),
            _VehicleFact(
              icon: Icons.business_center_outlined,
              text: 'Yüklenici: ${vehicle.contractorName}',
            ),
          ],
        ],
      ),
    );
  }
}

class _VehicleFact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _VehicleFact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(text)),
      ],
    );
  }
}
