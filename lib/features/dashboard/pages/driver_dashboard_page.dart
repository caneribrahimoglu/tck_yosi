import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/models/app_user.dart';
import '../../vehicles/presentation/controllers/vehicle_controller.dart';
import '../../vehicles/presentation/vehicle_presentation.dart';
import '../../vehicles/domain/enums/vehicle_record_type.dart';
import '../../vehicles/domain/models/vehicle_record.dart';

class DriverDashboardPage extends StatefulWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final Future<void> Function() onCreateFieldReport;
  final Future<void> Function() onReceiveVehicle;
  final Future<void> Function() onReturnVehicle;
  final Future<void> Function() onCreateFaultRecord;
  final Future<void> Function() onCreateMaintenanceRecord;
  final VehicleController vehicleController;

  const DriverDashboardPage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.onCreateFieldReport,
    required this.onReceiveVehicle,
    required this.onReturnVehicle,
    required this.onCreateFaultRecord,
    required this.onCreateMaintenanceRecord,
    required this.vehicleController,
  });

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  @override
  void initState() {
    super.initState();
    widget.vehicleController.loadAssignedVehicle(widget.currentUser.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCK YÖSİ'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              right: AppSpacing.md,
            ),
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
        animation: widget.vehicleController,
        builder: (context, child) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(
                title: 'Hoş geldin, ${widget.currentUser.fullName}',
                subtitle: 'Görevlerin ve araç işlemlerin',
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildAssignedVehicle(context),
              if (widget.vehicleController.currentUsageSession != null &&
                  widget
                      .vehicleController
                      .assignedVehicleRecords
                      .isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildVehicleHistory(context),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Hızlı İşlemler',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedVehicle(BuildContext context) {
    final controller = widget.vehicleController;
    if (controller.isLoadingAssignedVehicle) {
      return const AppCard(child: Center(child: CircularProgressIndicator()));
    }
    if (controller.handoverErrorMessage case final error?) {
      return AppCard(
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: 'Tekrar Dene',
              onPressed: () =>
                  controller.loadAssignedVehicle(widget.currentUser.id),
            ),
          ],
        ),
      );
    }

    final vehicle = controller.assignedVehicle;
    if (vehicle == null) {
      return const AppCard(
        child: Column(
          children: [
            Icon(Icons.no_transfer_outlined, size: 44),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Atanmış Araç Yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Şef tarafından araç atandığında burada görüntülenecek.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final usage = controller.currentUsageSession;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            vehicle.type.icon,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atanmış Aracın',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  vehicle.licensePlate,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${vehicle.brand} ${vehicle.model} • ${vehicle.formattedMileage}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  usage == null
                      ? 'Teslim alınmayı bekliyor'
                      : 'Teslim alındı · ${_formatDate(usage.receivedAt)} · ${usage.receivedMileage} km',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: usage == null
                        ? Theme.of(context).colorScheme.tertiary
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final hasVehicle = widget.vehicleController.assignedVehicle != null;
    final isReceived = widget.vehicleController.currentUsageSession != null;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        if (hasVehicle &&
            !isReceived &&
            widget.currentUser.hasPermission(AppPermission.receiveVehicle))
          AppButton.primary(
            label: 'Aracı Teslim Al',
            icon: Icons.key_rounded,
            onPressed: widget.onReceiveVehicle,
          ),
        if (hasVehicle &&
            isReceived &&
            widget.currentUser.hasPermission(AppPermission.returnVehicle))
          AppButton.primary(
            label: 'Aracı İade Et',
            icon: Icons.assignment_return_outlined,
            onPressed: widget.onReturnVehicle,
          ),
        if (isReceived &&
            widget.currentUser.hasPermission(AppPermission.updateMileage))
          const AppButton.secondary(
            label: 'Kilometre Gir',
            icon: Icons.speed_rounded,
            onPressed: null,
          ),
        if (isReceived &&
            widget.currentUser.hasPermission(AppPermission.createFuelRecord))
          const AppButton.secondary(
            label: 'Yakıt Kaydı',
            icon: Icons.local_gas_station_outlined,
            onPressed: null,
          ),
        if (isReceived &&
            widget.currentUser.hasPermission(
              AppPermission.createVehicleFaultRecord,
            ))
          AppButton.secondary(
            label: 'Arıza Kaydı',
            icon: Icons.car_crash_outlined,
            onPressed: widget.onCreateFaultRecord,
          ),
        if (isReceived &&
            widget.currentUser.hasPermission(
              AppPermission.createVehicleMaintenanceRecord,
            ))
          AppButton.secondary(
            label: 'Bakım Kaydı',
            icon: Icons.build_outlined,
            onPressed: widget.onCreateMaintenanceRecord,
          ),
        if (widget.currentUser.hasPermission(AppPermission.createFieldReport))
          AppButton.secondary(
            label: 'Saha Bildirimi Oluştur',
            icon: Icons.add_location_alt_outlined,
            onPressed: widget.onCreateFieldReport,
          ),
      ],
    );
  }

  Widget _buildVehicleHistory(BuildContext context) {
    final records = widget.vehicleController.assignedVehicleRecords.take(3);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Son Araç Kayıtları',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final record in records) _buildVehicleRecord(context, record),
        ],
      ),
    );
  }

  Widget _buildVehicleRecord(BuildContext context, VehicleRecord record) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final review = record.latestFaultReview;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Icon(record.type.icon, color: colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${record.type.label}: ${record.title}',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (record.type == VehicleRecordType.fault)
                      AppStatusChip(
                        label: record.faultReviewLabel,
                        type: record.faultReviewStatusType,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(record.description),
                if (review != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Şef değerlendirmesi',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(review.note),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${review.reviewedByName} · ${_formatDate(review.reviewedAt)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${record.mileage} km · Bildirim: ${_formatDate(record.createdAt)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
