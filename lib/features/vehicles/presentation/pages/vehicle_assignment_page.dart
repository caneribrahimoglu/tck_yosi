import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../auth/domain/enums/user_role.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_assignment.dart';
import '../controllers/vehicle_controller.dart';

class VehicleAssignmentPage extends StatefulWidget {
  final Vehicle vehicle;
  final VehicleAssignment? currentAssignment;
  final VehicleController controller;

  const VehicleAssignmentPage({
    super.key,
    required this.vehicle,
    required this.currentAssignment,
    required this.controller,
  });

  @override
  State<VehicleAssignmentPage> createState() => _VehicleAssignmentPageState();
}

class _VehicleAssignmentPageState extends State<VehicleAssignmentPage> {
  AppUser? _selectedUser;

  @override
  void initState() {
    super.initState();
    widget.controller.loadAssignmentCandidates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Araç Personel Ataması')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    title: widget.vehicle.licensePlate,
                    subtitle:
                        '${widget.vehicle.brand} ${widget.vehicle.model} için sorumlu personeli seçin.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Mevcut atama',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          widget.currentAssignment?.assignedToName ??
                              'Araç şu anda bir personele atanmamış.',
                        ),
                        if (widget.currentAssignment != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AppButton.danger(
                              label: 'Atamayı Sonlandır',
                              icon: Icons.person_remove_outlined,
                              onPressed: widget.controller.isAssigning
                                  ? null
                                  : _release,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Yeni personel ata',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (widget.controller.isLoadingAssignmentCandidates)
                          const Center(child: CircularProgressIndicator())
                        else if (widget.controller.assignmentCandidates.isEmpty)
                          const Text('Atanabilir aktif personel bulunamadı.')
                        else
                          DropdownButtonFormField<AppUser>(
                            key: const ValueKey('vehicle-assignee-dropdown'),
                            initialValue: _selectedUser,
                            decoration: const InputDecoration(
                              labelText: 'Sorumlu personel',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final user
                                  in widget.controller.assignmentCandidates)
                                DropdownMenuItem(
                                  value: user,
                                  child: Text(
                                    '${user.fullName} · ${user.role.label}',
                                  ),
                                ),
                            ],
                            onChanged: widget.controller.isAssigning
                                ? null
                                : (value) =>
                                      setState(() => _selectedUser = value),
                          ),
                        if (widget.controller.assignmentErrorMessage
                            case final error?) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppButton.primary(
                            label: widget.controller.isAssigning
                                ? 'Atanıyor...'
                                : 'Personeli Ata',
                            icon: Icons.assignment_ind_outlined,
                            onPressed:
                                widget.controller.isAssigning ||
                                    _selectedUser == null
                                ? null
                                : _assign,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _assign() async {
    final user = _selectedUser;
    if (user == null) {
      return;
    }
    final assignment = await widget.controller.assignVehicle(
      vehicleId: widget.vehicle.id,
      user: user,
    );
    if (assignment != null && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _release() async {
    final released = await widget.controller.releaseVehicle(widget.vehicle.id);
    if (released && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

extension on UserRole {
  String get label => switch (this) {
    UserRole.driver => 'Şoför',
    UserRole.engineer => 'Mühendis',
    UserRole.technician => 'Teknisyen',
    UserRole.cleaningStaff => 'Temizlik personeli',
    UserRole.chief => 'Şef',
    UserRole.director => 'Müdür',
    UserRole.admin => 'Yönetici',
  };
}
