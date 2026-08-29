import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/enums/vehicle_record_type.dart';
import '../../domain/models/create_vehicle_record_request.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_record.dart';
import '../controllers/vehicle_controller.dart';
import '../vehicle_presentation.dart';

class CreateVehicleRecordPage extends StatefulWidget {
  final VehicleRecordType type;
  final Vehicle vehicle;
  final AppUser currentUser;
  final VehicleController controller;

  const CreateVehicleRecordPage({
    super.key,
    required this.type,
    required this.vehicle,
    required this.currentUser,
    required this.controller,
  });

  @override
  State<CreateVehicleRecordPage> createState() =>
      _CreateVehicleRecordPageState();
}

class _CreateVehicleRecordPageState extends State<CreateVehicleRecordPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final TextEditingController _mileageController;

  @override
  void initState() {
    super.initState();
    _mileageController = TextEditingController(
      text: widget.vehicle.currentMileage.toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    return PopScope(
      canPop: !widget.controller.isSubmittingRecord,
      child: Scaffold(
        appBar: AppBar(title: Text('${type.label} Kaydı')),
        body: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, child) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPageHeader(
                        title: '${type.label} Kaydı Oluştur',
                        subtitle:
                            '${widget.vehicle.licensePlate} · ${widget.vehicle.brand} ${widget.vehicle.model}',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              key: const ValueKey('vehicle-record-title'),
                              controller: _titleController,
                              maxLength: 120,
                              decoration: InputDecoration(
                                labelText: '${type.label} başlığı',
                                prefixIcon: Icon(type.icon),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'Başlık zorunludur.'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              key: const ValueKey('vehicle-record-mileage'),
                              controller: _mileageController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Güncel kilometre',
                                suffixText: 'km',
                                prefixIcon: const Icon(Icons.speed_rounded),
                                border: const OutlineInputBorder(),
                                helperText:
                                    '${widget.vehicle.currentMileage} km değerinden düşük olamaz.',
                              ),
                              validator: (value) {
                                final mileage = int.tryParse(value ?? '');
                                if (mileage == null) {
                                  return 'Kilometre zorunludur.';
                                }
                                if (mileage < widget.vehicle.currentMileage) {
                                  return 'Kilometre geriye gidemez.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              key: const ValueKey('vehicle-record-description'),
                              controller: _descriptionController,
                              minLines: 4,
                              maxLines: 7,
                              maxLength: 1000,
                              decoration: InputDecoration(
                                labelText: type == VehicleRecordType.fault
                                    ? 'Arızayı ve belirtilerini açıklayın'
                                    : 'Yapılan bakımı açıklayın',
                                alignLabelWithHint: true,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'Açıklama zorunludur.'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      if (widget.controller.recordErrorMessage
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton.primary(
                          label: widget.controller.isSubmittingRecord
                              ? 'Kaydediliyor...'
                              : '${type.label} Kaydını Ekle',
                          icon: type.icon,
                          onPressed: widget.controller.isSubmittingRecord
                              ? null
                              : _submit,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final record = await widget.controller.createVehicleRecord(
      currentUser: widget.currentUser,
      request: CreateVehicleRecordRequest(
        type: widget.type,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        mileage: int.parse(_mileageController.text),
      ),
    );
    if (record != null && mounted) {
      Navigator.of(context).pop<VehicleRecord>(record);
    }
  }
}
