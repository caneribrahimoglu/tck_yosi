import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/enums/vehicle_operational_status.dart';
import '../../domain/enums/vehicle_ownership_type.dart';
import '../controllers/vehicle_controller.dart';

class VehicleFilterPanel extends StatelessWidget {
  final VehicleController controller;
  final TextEditingController searchController;
  final VoidCallback onClearFilters;

  const VehicleFilterPanel({
    super.key,
    required this.controller,
    required this.searchController,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          final search = AppTextField(
            controller: searchController,
            label: 'Araç ara',
            hint: 'Plaka, marka veya model',
            prefixIcon: Icons.search_rounded,
            onChanged: controller.setSearchQuery,
          );
          final ownership = AppDropdown<_OwnershipFilterOption>(
            key: ValueKey(_ownershipOption),
            value: _ownershipOption,
            label: 'Mülkiyet / tedarik',
            prefixIcon: Icons.business_outlined,
            items: _OwnershipFilterOption.values
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (option) =>
                controller.setOwnershipFilter(option?.ownershipType),
          );
          final status = AppDropdown<_StatusFilterOption>(
            key: ValueKey(_statusOption),
            value: _statusOption,
            label: 'Operasyon durumu',
            prefixIcon: Icons.tune_rounded,
            items: _StatusFilterOption.values
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (option) => controller.setStatusFilter(option?.status),
          );
          final clearButton = AppButton.secondary(
            label: 'Filtreleri Temizle',
            icon: Icons.filter_alt_off_outlined,
            onPressed: controller.hasActiveFilters ? onClearFilters : null,
          );
          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: AppSpacing.md),
                ownership,
                const SizedBox(height: AppSpacing.md),
                status,
                const SizedBox(height: AppSpacing.md),
                clearButton,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ownership),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: status),
                  const SizedBox(width: AppSpacing.md),
                  clearButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  _OwnershipFilterOption get _ownershipOption =>
      switch (controller.ownershipFilter) {
        VehicleOwnershipType.institutionOwned =>
          _OwnershipFilterOption.institutionOwned,
        VehicleOwnershipType.contracted => _OwnershipFilterOption.contracted,
        null => _OwnershipFilterOption.all,
      };

  _StatusFilterOption get _statusOption => switch (controller.statusFilter) {
    VehicleOperationalStatus.active => _StatusFilterOption.active,
    VehicleOperationalStatus.maintenance => _StatusFilterOption.maintenance,
    VehicleOperationalStatus.outOfService => _StatusFilterOption.outOfService,
    null => _StatusFilterOption.all,
  };
}

enum _OwnershipFilterOption { all, institutionOwned, contracted }

extension on _OwnershipFilterOption {
  String get label => switch (this) {
    _OwnershipFilterOption.all => 'Tüm mülkiyet tipleri',
    _OwnershipFilterOption.institutionOwned => 'Kuruma Ait',
    _OwnershipFilterOption.contracted => 'Sözleşmeli',
  };

  VehicleOwnershipType? get ownershipType => switch (this) {
    _OwnershipFilterOption.all => null,
    _OwnershipFilterOption.institutionOwned =>
      VehicleOwnershipType.institutionOwned,
    _OwnershipFilterOption.contracted => VehicleOwnershipType.contracted,
  };
}

enum _StatusFilterOption { all, active, maintenance, outOfService }

extension on _StatusFilterOption {
  String get label => switch (this) {
    _StatusFilterOption.all => 'Tüm durumlar',
    _StatusFilterOption.active => 'Aktif',
    _StatusFilterOption.maintenance => 'Bakımda',
    _StatusFilterOption.outOfService => 'Hizmet Dışı',
  };

  VehicleOperationalStatus? get status => switch (this) {
    _StatusFilterOption.all => null,
    _StatusFilterOption.active => VehicleOperationalStatus.active,
    _StatusFilterOption.maintenance => VehicleOperationalStatus.maintenance,
    _StatusFilterOption.outOfService => VehicleOperationalStatus.outOfService,
  };
}
