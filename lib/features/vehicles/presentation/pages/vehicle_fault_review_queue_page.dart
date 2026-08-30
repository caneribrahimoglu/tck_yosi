import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/enums/vehicle_fault_review_decision.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_record.dart';
import '../controllers/vehicle_controller.dart';
import '../vehicle_presentation.dart';

class VehicleFaultReviewQueuePage extends StatefulWidget {
  final AppUser currentUser;
  final VehicleController controller;

  const VehicleFaultReviewQueuePage({
    super.key,
    required this.currentUser,
    required this.controller,
  });

  @override
  State<VehicleFaultReviewQueuePage> createState() =>
      _VehicleFaultReviewQueuePageState();
}

class _VehicleFaultReviewQueuePageState
    extends State<VehicleFaultReviewQueuePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadOpenVehicleFaults();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Araç Arıza İncelemeleri')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          if (widget.controller.isLoadingFaultReviews) {
            return const AppLoading(message: 'Araç arızaları yükleniyor...');
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: 'Arıza İnceleme Kuyruğu',
                      subtitle:
                          'Şoförlerin bildirdiği araç arızalarını değerlendirin ve aracın durumunu belirleyin.',
                    ),
                    if (widget.controller.faultReviewErrorMessage
                        case final error?) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (widget.controller.openVehicleFaults.isEmpty)
                      const AppCard(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: [
                              Icon(Icons.task_alt_rounded, size: 48),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                'Açık araç arızası bulunmuyor.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      for (final record
                          in widget.controller.openVehicleFaults) ...[
                        _FaultReviewCard(
                          record: record,
                          vehicle: _findVehicle(record.vehicleId),
                          isSubmitting: widget.controller.isReviewingFault,
                          onDecision: (decision) => _review(record, decision),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Vehicle? _findVehicle(String vehicleId) {
    for (final vehicle in widget.controller.allVehicles) {
      if (vehicle.id == vehicleId) {
        return vehicle;
      }
    }
    return null;
  }

  Future<void> _review(
    VehicleRecord record,
    VehicleFaultReviewDecision decision,
  ) async {
    var note = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(decision.actionLabel),
        content: TextField(
          key: const ValueKey('vehicle-fault-review-note'),
          onChanged: (value) => note = value,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Şef değerlendirme açıklaması',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kararı Kaydet'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    note = note.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değerlendirme açıklaması zorunludur.')),
      );
      return;
    }
    final success = await widget.controller.reviewVehicleFault(
      record: record,
      currentUser: widget.currentUser,
      decision: decision,
      note: note,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${decision.label} kararı kaydedildi.')),
      );
    }
  }
}

class _FaultReviewCard extends StatelessWidget {
  final VehicleRecord record;
  final Vehicle? vehicle;
  final bool isSubmitting;
  final ValueChanged<VehicleFaultReviewDecision> onDecision;

  const _FaultReviewCard({
    required this.record,
    required this.vehicle,
    required this.isSubmitting,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    final latestReview = record.latestFaultReview;
    final decisions = <VehicleFaultReviewDecision>[
      VehicleFaultReviewDecision.continueInService,
      VehicleFaultReviewDecision.takeToMaintenance,
      VehicleFaultReviewDecision.takeOutOfService,
      if (latestReview != null) VehicleFaultReviewDecision.resolve,
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                vehicle?.licensePlate ?? 'Bilinmeyen araç',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              AppStatusChip(
                label: record.faultReviewLabel,
                type: record.faultReviewStatusType,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            record.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(record.description),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${record.mileage} km · ${record.createdByName} · ${_formatDate(record.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (latestReview != null) ...[
            const Divider(height: AppSpacing.xl),
            Text(
              'Son değerlendirme: ${latestReview.reviewedByName} · ${_formatDate(latestReview.reviewedAt)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(latestReview.note),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final decision in decisions)
                if (decision != latestReview?.decision)
                  decision == VehicleFaultReviewDecision.takeOutOfService
                      ? AppButton.secondary(
                          label: decision.actionLabel,
                          icon: Icons.block_rounded,
                          onPressed: isSubmitting
                              ? null
                              : () => onDecision(decision),
                        )
                      : AppButton.primary(
                          label: decision.actionLabel,
                          icon: _decisionIcon(decision),
                          onPressed: isSubmitting
                              ? null
                              : () => onDecision(decision),
                        ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _decisionIcon(VehicleFaultReviewDecision decision) =>
    switch (decision) {
      VehicleFaultReviewDecision.continueInService =>
        Icons.directions_car_outlined,
      VehicleFaultReviewDecision.takeToMaintenance => Icons.build_outlined,
      VehicleFaultReviewDecision.takeOutOfService => Icons.block_rounded,
      VehicleFaultReviewDecision.resolve => Icons.task_alt_rounded,
    };

String _formatDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
