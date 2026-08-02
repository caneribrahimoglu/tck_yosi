import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/enums/app_snackbar_type.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/enums/technical_work_category.dart';
import '../../domain/models/create_field_report_request.dart';
import '../controllers/field_report_controller.dart';
import '../controllers/field_report_submission_status.dart';

class FieldReportPage extends StatefulWidget {
  final FieldReportController controller;
  final String currentUserId;

  const FieldReportPage({
    super.key,
    required this.controller,
    required this.currentUserId,
  });

  @override
  State<FieldReportPage> createState() => _FieldReportPageState();
}

class _FieldReportPageState extends State<FieldReportPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  TechnicalWorkCategory? _selectedCategory;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid || _selectedCategory == null) {
      return;
    }

    final request = CreateFieldReportRequest(
      category: _selectedCategory!,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
    );

    await widget.controller.submit(
      request: request,
      createdByUserId: widget.currentUserId,
    );

    if (!mounted) {
      return;
    }

    if (widget.controller.status == FieldReportSubmissionStatus.success) {
      AppSnackbar.show(
        context: context,
        type: AppSnackbarType.success,
        message: 'Saha bildirimi başarıyla oluşturuldu.',
      );

      Navigator.of(context).pop(widget.controller.createdWork);
      return;
    }

    if (widget.controller.status == FieldReportSubmissionStatus.failure) {
      AppSnackbar.show(
        context: context,
        type: AppSnackbarType.error,
        message:
            widget.controller.errorMessage ?? 'Saha bildirimi gönderilemedi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saha Bildirimi Oluştur')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          final isSubmitting =
              widget.controller.status ==
              FieldReportSubmissionStatus.submitting;

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: AppCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Yeni saha bildirimi',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Tespit ettiğiniz durumu ilgili ekibin '
                                'incelemesi için kaydedin.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              AppDropdown<TechnicalWorkCategory>(
                                value: _selectedCategory,
                                label: 'Kategori',
                                hint: 'Kategori seçiniz',
                                prefixIcon: Icons.category_outlined,
                                items: TechnicalWorkCategory.values.map((
                                  category,
                                ) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(_categoryLabel(category)),
                                  );
                                }).toList(),
                                onChanged: isSubmitting
                                    ? null
                                    : (category) {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Lütfen bir kategori seçin.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppTextField(
                                controller: _titleController,
                                label: 'Başlık',
                                hint: 'Örn. Aydınlatma arızası',
                                prefixIcon: Icons.title_rounded,
                                enabled: !isSubmitting,
                                maxLength: 100,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Başlık zorunludur.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppTextField(
                                controller: _descriptionController,
                                label: 'Açıklama',
                                hint: 'Tespit ettiğiniz durumu açıklayın.',
                                prefixIcon: Icons.description_outlined,
                                enabled: !isSubmitting,
                                minLines: 4,
                                maxLines: 6,
                                maxLength: 1000,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Açıklama zorunludur.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppTextField(
                                controller: _locationController,
                                label: 'Konum',
                                hint: 'Örn. D-100 / Km 14+200',
                                prefixIcon: Icons.location_on_outlined,
                                enabled: !isSubmitting,
                                maxLength: 150,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  _submit();
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Konum zorunludur.';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              AppButton.primary(
                                label: isSubmitting
                                    ? 'Gönderiliyor...'
                                    : 'Bildirimi Gönder',
                                icon: isSubmitting
                                    ? Icons.hourglass_top_rounded
                                    : Icons.send_rounded,
                                onPressed: isSubmitting ? null : _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _categoryLabel(TechnicalWorkCategory category) {
    return switch (category) {
      TechnicalWorkCategory.roadSurface => 'Yol yüzeyi',
      TechnicalWorkCategory.trafficAccident => 'Trafik kazası',
      TechnicalWorkCategory.lighting => 'Aydınlatma',
      TechnicalWorkCategory.trafficSign => 'Trafik levhası',
      TechnicalWorkCategory.roadMarking => 'Yol çizgisi',
      TechnicalWorkCategory.barrier => 'Bariyer',
      TechnicalWorkCategory.drainage => 'Drenaj',
      TechnicalWorkCategory.bridgeAndViaduct => 'Köprü ve viyadük',
      TechnicalWorkCategory.tunnel => 'Tünel',
      TechnicalWorkCategory.landslide => 'Heyelan',
      TechnicalWorkCategory.building => 'Yapı',
      TechnicalWorkCategory.electricalSystem => 'Elektrik sistemi',
      TechnicalWorkCategory.vehicle => 'Araç',
      TechnicalWorkCategory.workMachine => 'İş makinesi',
      TechnicalWorkCategory.other => 'Diğer',
    };
  }
}
