import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/enums/vehicle_operational_status.dart';
import '../../domain/enums/vehicle_ownership_type.dart';
import '../../domain/enums/vehicle_type.dart';
import '../../domain/models/create_vehicle_request.dart';
import '../../domain/models/vehicle.dart';
import '../controllers/vehicle_controller.dart';
import '../vehicle_presentation.dart';

class CreateVehiclePage extends StatefulWidget {
  final VehicleController controller;

  const CreateVehiclePage({super.key, required this.controller});

  @override
  State<CreateVehiclePage> createState() => _CreateVehiclePageState();
}

class _CreateVehiclePageState extends State<CreateVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _licensePlateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _modelYearController = TextEditingController();
  final _mileageController = TextEditingController(text: '0');
  final _contractorController = TextEditingController();

  VehicleType _type = VehicleType.passengerCar;
  VehicleOwnershipType _ownershipType = VehicleOwnershipType.institutionOwned;
  VehicleOperationalStatus _operationalStatus = VehicleOperationalStatus.active;

  @override
  void dispose() {
    _licensePlateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _modelYearController.dispose();
    _mileageController.dispose();
    _contractorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Araç')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppPageHeader(
                        title: 'Filoya Araç Ekle',
                        subtitle:
                            'Kurum aracı veya sözleşmeli araç bilgilerini kaydedin.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionTitle(
                                icon: Icons.directions_car_outlined,
                                title: 'Temel Bilgiler',
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _ResponsiveFields(
                                children: [
                                  AppTextField(
                                    controller: _licensePlateController,
                                    label: 'Plaka',
                                    hint: '81 KGM 101',
                                    prefixIcon: Icons.pin_outlined,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    validator: _requiredValidator,
                                  ),
                                  _DropdownField<VehicleType>(
                                    label: 'Araç türü',
                                    value: _type,
                                    icon: Icons.category_outlined,
                                    items: VehicleType.values,
                                    itemLabel: (value) => value.label,
                                    onChanged: (value) =>
                                        setState(() => _type = value!),
                                  ),
                                  AppTextField(
                                    controller: _brandController,
                                    label: 'Marka',
                                    prefixIcon: Icons.factory_outlined,
                                    validator: _requiredValidator,
                                  ),
                                  AppTextField(
                                    controller: _modelController,
                                    label: 'Model',
                                    prefixIcon: Icons.badge_outlined,
                                    validator: _requiredValidator,
                                  ),
                                  AppTextField(
                                    controller: _modelYearController,
                                    label: 'Model yılı',
                                    prefixIcon: Icons.calendar_today_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: _modelYearValidator,
                                  ),
                                  AppTextField(
                                    controller: _mileageController,
                                    label: 'Güncel kilometre',
                                    prefixIcon: Icons.speed_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: _mileageValidator,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              _SectionTitle(
                                icon: Icons.account_balance_outlined,
                                title: 'Mülkiyet ve Durum',
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _ResponsiveFields(
                                children: [
                                  _DropdownField<VehicleOwnershipType>(
                                    label: 'Mülkiyet türü',
                                    value: _ownershipType,
                                    icon: Icons.handshake_outlined,
                                    items: VehicleOwnershipType.values,
                                    itemLabel: (value) => value.label,
                                    onChanged: (value) {
                                      setState(() => _ownershipType = value!);
                                    },
                                  ),
                                  _DropdownField<VehicleOperationalStatus>(
                                    label: 'Operasyon durumu',
                                    value: _operationalStatus,
                                    icon: Icons.tune_outlined,
                                    items: VehicleOperationalStatus.values,
                                    itemLabel: (value) => value.label,
                                    onChanged: (value) {
                                      setState(
                                        () => _operationalStatus = value!,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              if (_ownershipType ==
                                  VehicleOwnershipType.contracted) ...[
                                const SizedBox(height: AppSpacing.lg),
                                AppTextField(
                                  controller: _contractorController,
                                  label: 'Yüklenici firma',
                                  prefixIcon: Icons.business_outlined,
                                  validator: _requiredValidator,
                                ),
                              ],
                              if (widget.controller.creationErrorMessage !=
                                  null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  widget.controller.creationErrorMessage!,
                                  key: const ValueKey('vehicle-creation-error'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              Align(
                                alignment: Alignment.centerRight,
                                child: AppButton.primary(
                                  label: widget.controller.isCreating
                                      ? 'Kaydediliyor...'
                                      : 'Aracı Kaydet',
                                  icon: Icons.add_rounded,
                                  onPressed: widget.controller.isCreating
                                      ? null
                                      : _submit,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final request = CreateVehicleRequest(
      licensePlate: _licensePlateController.text.trim(),
      brand: _brandController.text.trim(),
      model: _modelController.text.trim(),
      modelYear: _modelYearController.text.trim().isEmpty
          ? null
          : int.parse(_modelYearController.text.trim()),
      currentMileage: int.parse(_mileageController.text.trim()),
      ownershipType: _ownershipType,
      operationalStatus: _operationalStatus,
      contractorName: _ownershipType == VehicleOwnershipType.contracted
          ? _contractorController.text.trim()
          : null,
      type: _type,
    );
    final vehicle = await widget.controller.createVehicle(request);
    if (vehicle != null && mounted) {
      Navigator.of(context).pop<Vehicle>(vehicle);
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan zorunludur.';
    }
    return null;
  }

  String? _modelYearValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final year = int.tryParse(value.trim());
    final maximumYear = DateTime.now().year + 1;
    if (year == null || year < Vehicle.minimumModelYear || year > maximumYear) {
      return '${Vehicle.minimumModelYear}-$maximumYear arasında olmalıdır.';
    }
    return null;
  }

  String? _mileageValidator(String? value) {
    final mileage = int.tryParse(value?.trim() ?? '');
    if (mileage == null || mileage < 0) {
      return 'Geçerli bir kilometre girin.';
    }
    return null;
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveFields({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - AppSpacing.lg) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final IconData icon;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(itemLabel(item))),
      ],
      onChanged: onChanged,
    );
  }
}
