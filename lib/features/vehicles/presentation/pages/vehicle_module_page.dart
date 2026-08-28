import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/domain/enums/app_permission.dart';
import '../../domain/models/vehicle.dart';
import '../controllers/vehicle_controller.dart';
import '../controllers/vehicle_load_status.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/vehicle_filter_panel.dart';
import '../widgets/vehicle_summary_grid.dart';

class VehicleModulePage extends StatefulWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final VehicleController controller;
  final ValueChanged<Vehicle>? onViewVehicle;
  final Future<void> Function()? onAddVehicle;

  const VehicleModulePage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.controller,
    this.onViewVehicle,
    this.onAddVehicle,
  });

  @override
  State<VehicleModulePage> createState() => _VehicleModulePageState();
}

class _VehicleModulePageState extends State<VehicleModulePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
    if (widget.controller.status == VehicleLoadStatus.initial) {
      widget.controller.load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Yönetimi'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Row(
              children: [
                Text(widget.currentUser.fullName),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Çıkış yap',
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) => switch (widget.controller.status) {
          VehicleLoadStatus.initial || VehicleLoadStatus.loading =>
            const AppLoading(message: 'Araçlar yükleniyor...'),
          VehicleLoadStatus.failure => _FailureState(
            message:
                widget.controller.errorMessage ?? 'Araç bilgileri yüklenemedi.',
            onRetry: widget.controller.load,
          ),
          VehicleLoadStatus.loaded => _buildLoadedContent(context),
        },
      ),
    );
  }

  Widget _buildLoadedContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Araç Yönetimi',
                subtitle:
                    'Kurum ve sözleşmeli araçlardan oluşan filonun güncel durumunu izleyin.',
                actions: [
                  if (widget.currentUser.hasPermission(
                        AppPermission.manageVehicleFleet,
                      ) &&
                      widget.onAddVehicle != null)
                    AppButton.primary(
                      label: 'Araç Ekle',
                      icon: Icons.add_rounded,
                      onPressed: widget.onAddVehicle,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              VehicleSummaryGrid(controller: widget.controller),
              const SizedBox(height: AppSpacing.xl),
              VehicleFilterPanel(
                controller: widget.controller,
                searchController: _searchController,
                onClearFilters: _clearFilters,
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildVehicleResults(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleResults(BuildContext context) {
    final vehicles = widget.controller.vehicles;
    if (widget.controller.allVehicles.isEmpty) {
      return const _EmptyState(
        icon: Icons.directions_car_outlined,
        message: 'Henüz araç kaydı bulunmuyor.',
      );
    }
    if (vehicles.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        message: 'Filtrelere uygun araç bulunamadı.',
        action: AppButton.secondary(
          label: 'Filtreleri Temizle',
          onPressed: _clearFilters,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Filo Listesi (${vehicles.length})',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000 ? 2 : 1;
            final width = columns == 2
                ? (constraints.maxWidth - AppSpacing.lg) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                for (final vehicle in vehicles)
                  SizedBox(
                    width: width,
                    child: VehicleCard(
                      vehicle: vehicle,
                      onTap: widget.onViewVehicle == null
                          ? null
                          : () => widget.onViewVehicle!(vehicle),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _clearFilters() {
    _searchController.clear();
    widget.controller.clearFilters();
  }
}

class _FailureState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _FailureState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            AppButton.primary(label: 'Tekrar Dene', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _EmptyState({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
