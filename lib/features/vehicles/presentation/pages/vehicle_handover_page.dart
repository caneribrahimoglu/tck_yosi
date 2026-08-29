import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_inspection.dart';
import '../controllers/vehicle_controller.dart';

enum VehicleHandoverType { receive, returnVehicle }

class VehicleHandoverPage extends StatefulWidget {
  final VehicleHandoverType type;
  final Vehicle vehicle;
  final AppUser currentUser;
  final VehicleController controller;

  const VehicleHandoverPage({
    super.key,
    required this.type,
    required this.vehicle,
    required this.currentUser,
    required this.controller,
  });

  @override
  State<VehicleHandoverPage> createState() => _VehicleHandoverPageState();
}

class _VehicleHandoverPageState extends State<VehicleHandoverPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mileageController;
  final _notesController = TextEditingController();

  bool _bodyworkOkay = true;
  bool _tiresOkay = true;
  bool _lightsOkay = true;
  bool _wipersOkay = true;
  bool _glassAndMirrorsOkay = true;
  bool _leakFree = true;
  bool _equipmentComplete = true;

  bool get _hasIssue =>
      !_bodyworkOkay ||
      !_tiresOkay ||
      !_lightsOkay ||
      !_wipersOkay ||
      !_glassAndMirrorsOkay ||
      !_leakFree ||
      !_equipmentComplete;

  bool get _isReturn => widget.type == VehicleHandoverType.returnVehicle;

  @override
  void initState() {
    super.initState();
    _mileageController = TextEditingController(
      text: widget.vehicle.currentMileage.toString(),
    );
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.controller.isSubmittingHandover,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isReturn ? 'Araç İade Kontrolü' : 'Araç Teslim Kontrolü',
          ),
        ),
        body: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, child) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPageHeader(
                        title: _isReturn ? 'Aracı İade Et' : 'Aracı Teslim Al',
                        subtitle:
                            '${widget.vehicle.licensePlate} · ${widget.vehicle.brand} ${widget.vehicle.model}',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isReturn
                                  ? 'İade kilometresi'
                                  : 'Teslim kilometresi',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              key: const ValueKey('handover-mileage'),
                              controller: _mileageController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Kilometre',
                                suffixText: 'km',
                                prefixIcon: const Icon(Icons.speed_rounded),
                                border: const OutlineInputBorder(),
                                helperText:
                                    'Sistemdeki güncel değer: ${widget.vehicle.currentMileage} km',
                              ),
                              validator: (value) {
                                final mileage = int.tryParse(value ?? '');
                                if (mileage == null) {
                                  return 'Kilometre bilgisi zorunludur.';
                                }
                                if (mileage < widget.vehicle.currentMileage) {
                                  return '${widget.vehicle.currentMileage} km değerinden düşük olamaz.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Genel araç kontrolü',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Uygun olmayan bir maddeyi kapatın ve açıklamasını aşağıya yazın.',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _checkItem(
                              'Dış gövde ve kaporta uygun',
                              _bodyworkOkay,
                              (value) => _bodyworkOkay = value,
                            ),
                            _checkItem(
                              'Lastikler uygun',
                              _tiresOkay,
                              (value) => _tiresOkay = value,
                            ),
                            _checkItem(
                              'Farlar ve sinyaller çalışıyor',
                              _lightsOkay,
                              (value) => _lightsOkay = value,
                            ),
                            _checkItem(
                              'Silecekler çalışıyor',
                              _wipersOkay,
                              (value) => _wipersOkay = value,
                            ),
                            _checkItem(
                              'Camlar ve aynalar uygun',
                              _glassAndMirrorsOkay,
                              (value) => _glassAndMirrorsOkay = value,
                            ),
                            _checkItem(
                              'Yağ veya sıvı kaçağı yok',
                              _leakFree,
                              (value) => _leakFree = value,
                            ),
                            _checkItem(
                              'Ruhsat ve araç ekipmanları tam',
                              _equipmentComplete,
                              (value) => _equipmentComplete = value,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              key: const ValueKey('handover-notes'),
                              controller: _notesController,
                              maxLines: 4,
                              maxLength: 1000,
                              decoration: InputDecoration(
                                labelText: _hasIssue
                                    ? 'Sorun açıklaması (zorunlu)'
                                    : 'Genel açıklama (isteğe bağlı)',
                                alignLabelWithHint: true,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (_hasIssue &&
                                    (value?.trim().isEmpty ?? true)) {
                                  return 'Uygun olmayan maddeleri açıklayın.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      if (widget.controller.handoverErrorMessage
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
                          label: widget.controller.isSubmittingHandover
                              ? 'Kaydediliyor...'
                              : (_isReturn
                                    ? 'Kontrolü Kaydet ve İade Et'
                                    : 'Kontrolü Kaydet ve Teslim Al'),
                          icon: _isReturn
                              ? Icons.assignment_return_outlined
                              : Icons.key_rounded,
                          onPressed: widget.controller.isSubmittingHandover
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

  Widget _checkItem(String label, bool value, ValueChanged<bool> onChanged) =>
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: widget.controller.isSubmittingHandover
            ? null
            : (newValue) => setState(() => onChanged(newValue ?? false)),
        controlAffinity: ListTileControlAffinity.leading,
      );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final mileage = int.parse(_mileageController.text);
    final inspection = VehicleInspection(
      bodyworkOkay: _bodyworkOkay,
      tiresOkay: _tiresOkay,
      lightsOkay: _lightsOkay,
      wipersOkay: _wipersOkay,
      glassAndMirrorsOkay: _glassAndMirrorsOkay,
      leakFree: _leakFree,
      equipmentComplete: _equipmentComplete,
      notes: _notesController.text.trim(),
    );
    final success = _isReturn
        ? await widget.controller.returnAssignedVehicle(
            userId: widget.currentUser.id,
            mileage: mileage,
            inspection: inspection,
          )
        : await widget.controller.receiveAssignedVehicle(
            userId: widget.currentUser.id,
            mileage: mileage,
            inspection: inspection,
          );
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
