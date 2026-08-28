import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/enums/vehicle_ownership_type.dart';
import '../../domain/models/vehicle.dart';
import '../controllers/vehicle_detail_controller.dart';
import '../controllers/vehicle_detail_load_status.dart';
import '../vehicle_presentation.dart';

class VehicleDetailPage extends StatefulWidget {
  final String vehicleId;
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final VehicleDetailController controller;

  const VehicleDetailPage({
    super.key,
    required this.vehicleId,
    required this.currentUser,
    required this.onLogout,
    required this.controller,
  });

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.vehicleId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Detayı'),
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
          VehicleDetailLoadStatus.initial || VehicleDetailLoadStatus.loading =>
            const AppLoading(message: 'Araç detayı yükleniyor...'),
          VehicleDetailLoadStatus.notFound => const _MessageState(
            icon: Icons.directions_car_outlined,
            message: 'Araç kaydı bulunamadı.',
          ),
          VehicleDetailLoadStatus.failure => _MessageState(
            icon: Icons.error_outline_rounded,
            message:
                widget.controller.errorMessage ?? 'Araç detayı yüklenemedi.',
            action: AppButton.primary(
              label: 'Tekrar Dene',
              onPressed: () => widget.controller.load(widget.vehicleId),
            ),
          ),
          VehicleDetailLoadStatus.loaded => _LoadedVehicleDetail(
            vehicle: widget.controller.vehicle!,
          ),
        },
      ),
    );
  }
}

class _LoadedVehicleDetail extends StatelessWidget {
  final Vehicle vehicle;

  const _LoadedVehicleDetail({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: vehicle.licensePlate,
                subtitle: '${vehicle.brand} ${vehicle.model}',
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppStatusChip(
                    label: vehicle.operationalStatus.label,
                    type: vehicle.operationalStatus.statusType,
                  ),
                  AppStatusChip(
                    label: vehicle.ownershipType.label,
                    type: vehicle.ownershipType.statusType,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _VehicleHeroCard(vehicle: vehicle),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  final identityCard = _InformationCard(
                    title: 'Araç Bilgileri',
                    children: [
                      _InformationRow(
                        icon: Icons.category_outlined,
                        label: 'Araç türü',
                        value: vehicle.type.label,
                      ),
                      _InformationRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Model yılı',
                        value: vehicle.modelYear?.toString() ?? 'Belirtilmemiş',
                      ),
                      _InformationRow(
                        icon: Icons.speed_rounded,
                        label: 'Güncel kilometre',
                        value: vehicle.formattedMileage,
                      ),
                    ],
                  );
                  final ownershipCard = _InformationCard(
                    title: 'Mülkiyet Bilgileri',
                    children: [
                      _InformationRow(
                        icon: Icons.account_balance_outlined,
                        label: 'Mülkiyet türü',
                        value: vehicle.ownershipType.label,
                      ),
                      if (vehicle.ownershipType ==
                          VehicleOwnershipType.contracted)
                        _InformationRow(
                          icon: Icons.business_center_outlined,
                          label: 'Yüklenici',
                          value: vehicle.contractorName ?? 'Belirtilmemiş',
                        ),
                      _InformationRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Operasyon durumu',
                        value: vehicle.operationalStatus.label,
                      ),
                    ],
                  );

                  if (!isWide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identityCard,
                        const SizedBox(height: AppSpacing.lg),
                        ownershipCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: identityCard),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: ownershipCard),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleHeroCard extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleHeroCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              vehicle.type.icon,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.licensePlate,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${vehicle.brand} ${vehicle.model}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InformationCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _MessageState({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
