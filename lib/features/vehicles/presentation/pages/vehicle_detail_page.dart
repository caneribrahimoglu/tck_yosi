import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/enums/vehicle_operational_status.dart';
import '../../domain/enums/vehicle_ownership_type.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_assignment.dart';
import '../../domain/models/vehicle_inspection.dart';
import '../../domain/models/vehicle_usage_session.dart';
import '../controllers/vehicle_detail_controller.dart';
import '../controllers/vehicle_detail_load_status.dart';
import '../vehicle_presentation.dart';

class VehicleDetailPage extends StatefulWidget {
  final String vehicleId;
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final VehicleDetailController controller;
  final Future<void> Function(Vehicle vehicle)? onEditVehicle;
  final Future<void> Function(Vehicle vehicle)? onManageAssignment;

  const VehicleDetailPage({
    super.key,
    required this.vehicleId,
    required this.currentUser,
    required this.onLogout,
    required this.controller,
    this.onEditVehicle,
    this.onManageAssignment,
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
            assignments: widget.controller.assignments,
            usageSessions: widget.controller.usageSessions,
            currentAssignment: widget.controller.currentAssignment,
            onEditVehicle: widget.onEditVehicle,
            onManageAssignment: widget.onManageAssignment,
          ),
        },
      ),
    );
  }
}

class _LoadedVehicleDetail extends StatelessWidget {
  final Vehicle vehicle;
  final List<VehicleAssignment> assignments;
  final List<VehicleUsageSession> usageSessions;
  final VehicleAssignment? currentAssignment;
  final Future<void> Function(Vehicle vehicle)? onEditVehicle;
  final Future<void> Function(Vehicle vehicle)? onManageAssignment;

  const _LoadedVehicleDetail({
    required this.vehicle,
    required this.assignments,
    required this.usageSessions,
    required this.currentAssignment,
    this.onEditVehicle,
    this.onManageAssignment,
  });

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
                actions: [
                  if (onManageAssignment != null &&
                      (vehicle.operationalStatus ==
                              VehicleOperationalStatus.active ||
                          currentAssignment != null))
                    AppButton.secondary(
                      label: currentAssignment == null
                          ? 'Personel Ata'
                          : 'Atamayı Yönet',
                      icon: Icons.assignment_ind_outlined,
                      onPressed: () => onManageAssignment!(vehicle),
                    ),
                  if (onEditVehicle != null)
                    AppButton.primary(
                      label: 'Düzenle',
                      icon: Icons.edit_outlined,
                      onPressed: () => onEditVehicle!(vehicle),
                    ),
                ],
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
              const SizedBox(height: AppSpacing.xl),
              _AssignmentHistoryCard(
                assignments: assignments,
                currentAssignment: currentAssignment,
                usageSessions: usageSessions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentHistoryCard extends StatelessWidget {
  final List<VehicleAssignment> assignments;
  final VehicleAssignment? currentAssignment;
  final List<VehicleUsageSession> usageSessions;

  const _AssignmentHistoryCard({
    required this.assignments,
    required this.currentAssignment,
    required this.usageSessions,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Personel Ataması ve Kullanım Geçmişi',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (currentAssignment == null)
            const Text('Araç şu anda bir personele atanmamış.')
          else
            _AssignmentRow(
              assignment: currentAssignment!,
              title: 'Mevcut sorumlu',
            ),
          if (assignments
              .where((assignment) => !assignment.isActive)
              .isNotEmpty) ...[
            const Divider(height: AppSpacing.xxl),
            Text(
              'Geçmiş atamalar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final assignment in assignments.where(
              (assignment) => !assignment.isActive,
            ))
              _AssignmentRow(assignment: assignment, title: 'Önceki sorumlu'),
          ],
          if (usageSessions.isNotEmpty) ...[
            const Divider(height: AppSpacing.xxl),
            Text(
              'Teslim ve iade kayıtları',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final session in usageSessions)
              _UsageSessionRow(session: session),
          ],
        ],
      ),
    );
  }
}

class _UsageSessionRow extends StatelessWidget {
  final VehicleUsageSession session;

  const _UsageSessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            session.isActive
                ? Icons.key_outlined
                : Icons.assignment_return_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.userName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Teslim: ${_formatVehicleDate(session.receivedAt)} · ${_formatVehicleMileage(session.receivedMileage)}',
                ),
                if (session.returnedAt != null)
                  Text(
                    'İade: ${_formatVehicleDate(session.returnedAt!)} · ${_formatVehicleMileage(session.returnedMileage!)}',
                  )
                else
                  const Text('Araç halen kullanıcıda'),
                _InspectionSummary(
                  title: 'Teslim',
                  inspection: session.receiveInspection,
                ),
                if (session.returnInspection case final inspection?)
                  _InspectionSummary(title: 'İade', inspection: inspection),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionSummary extends StatelessWidget {
  final String title;
  final VehicleInspection inspection;

  const _InspectionSummary({required this.title, required this.inspection});

  @override
  Widget build(BuildContext context) {
    final issues = _inspectionIssueLabels(inspection);
    final notes = inspection.notes.trim();

    if (issues.isEmpty && notes.isEmpty) {
      return const SizedBox.shrink();
    }

    if (issues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text('$title notu: $notes'),
      );
    }

    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: errorColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title sırasında tespit edilen sorunlar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: errorColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: errorColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      issue,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Açıklama: $notes'),
          ],
        ],
      ),
    );
  }
}

List<String> _inspectionIssueLabels(VehicleInspection inspection) => [
  if (!inspection.bodyworkOkay) 'Kaporta veya dış gövde sorunu',
  if (!inspection.tiresOkay) 'Lastik sorunu',
  if (!inspection.lightsOkay) 'Far veya sinyal arızası',
  if (!inspection.wipersOkay) 'Silecek arızası',
  if (!inspection.glassAndMirrorsOkay) 'Cam veya ayna sorunu',
  if (!inspection.leakFree) 'Yağ veya sıvı kaçağı',
  if (!inspection.equipmentComplete) 'Eksik ruhsat veya araç ekipmanı',
];

String _formatVehicleDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

String _formatVehicleMileage(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }
  return '$buffer km';
}

class _AssignmentRow extends StatelessWidget {
  final VehicleAssignment assignment;
  final String title;

  const _AssignmentRow({required this.assignment, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.person_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  assignment.assignedToName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  assignment.endedAt == null
                      ? '${_formatDate(assignment.assignedAt)} tarihinden beri kullanıyor'
                      : '${_formatDate(assignment.assignedAt)} – ${_formatDate(assignment.endedAt!)}',
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
