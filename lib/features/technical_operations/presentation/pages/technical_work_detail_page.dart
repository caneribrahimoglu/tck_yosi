import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/enums/app_snackbar_type.dart';
import '../../../../core/enums/app_button_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/technical_work_progress_note.dart';
import '../controllers/technical_work_detail_controller.dart';
import '../controllers/technical_work_completion_controller.dart';
import '../controllers/technical_work_completion_status.dart';
import '../controllers/technical_work_load_status.dart';
import '../technical_work_presentation.dart';
import '../../domain/enums/technical_work_completion_decision.dart';
import '../../domain/models/technical_work_completion_request.dart';

class TechnicalWorkDetailPage extends StatefulWidget {
  final String workId;
  final AppUser currentUser;
  final TechnicalWorkDetailController controller;
  final TechnicalWorkCompletionController? completionController;

  const TechnicalWorkDetailPage({
    super.key,
    required this.workId,
    required this.currentUser,
    required this.controller,
    this.completionController,
  });

  @override
  State<TechnicalWorkDetailPage> createState() =>
      _TechnicalWorkDetailPageState();
}

class _TechnicalWorkDetailPageState extends State<TechnicalWorkDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _completionFormKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _completionSummaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.load(
      workId: widget.workId,
      userId: widget.currentUser.id,
    );
    widget.completionController?.loadForWork(
      workId: widget.workId,
      userId: widget.currentUser.id,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _completionSummaryController.dispose();
    super.dispose();
  }

  Future<void> _submitCompletionRequest() async {
    if (!(_completionFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final completionController = widget.completionController;
    if (completionController == null) {
      return;
    }
    final succeeded = await completionController.submit(
      _completionSummaryController.text,
    );
    if (!mounted) {
      return;
    }
    if (succeeded) {
      _completionSummaryController.clear();
      await widget.controller.load(
        workId: widget.workId,
        userId: widget.currentUser.id,
      );
      if (!mounted) {
        return;
      }
      AppSnackbar.show(
        context: context,
        type: AppSnackbarType.success,
        message: 'Tamamlama talebi onaya gönderildi.',
      );
    } else {
      AppSnackbar.show(
        context: context,
        type: AppSnackbarType.error,
        message:
            completionController.errorMessage ??
            'Tamamlama talebi gönderilemedi.',
      );
    }
  }

  Future<void> _submitProgress() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final succeeded = await widget.controller.addProgress(_noteController.text);
    if (!mounted) {
      return;
    }
    if (succeeded) {
      _noteController.clear();
      AppSnackbar.show(
        context: context,
        type: AppSnackbarType.success,
        message: 'İlerleme kaydı eklendi.',
      );
      return;
    }
    AppSnackbar.show(
      context: context,
      type: AppSnackbarType.error,
      message: widget.controller.errorMessage ?? 'İlerleme kaydı eklenemedi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teknik İş Detayı')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          if (widget.completionController != null) widget.completionController!,
        ]),
        builder: (context, child) {
          return switch (widget.controller.loadStatus) {
            TechnicalWorkLoadStatus.initial ||
            TechnicalWorkLoadStatus.loading => const AppLoading(
              message: 'Teknik iş detayı yükleniyor...',
            ),
            TechnicalWorkLoadStatus.failure => _buildFailure(context),
            TechnicalWorkLoadStatus.loaded => _buildContent(context),
          };
        },
      ),
    );
  }

  Widget _buildFailure(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.controller.errorMessage ?? 'Teknik iş detayı yüklenemedi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Tekrar Dene',
              icon: Icons.refresh_rounded,
              onPressed: () => widget.controller.load(
                workId: widget.workId,
                userId: widget.currentUser.id,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final work = widget.controller.work!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        work.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AppStatusChip(
                            label: work.priority.label,
                            type: work.priority.statusType,
                          ),
                          AppStatusChip(
                            label: work.status.label,
                            type: work.status.statusType,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _DetailLine(
                        icon: work.category.icon,
                        label: 'Kategori',
                        value: work.category.label,
                      ),
                      _DetailLine(
                        icon: Icons.location_on_outlined,
                        label: 'Konum',
                        value: work.location,
                      ),
                      _DetailLine(
                        icon: Icons.groups_outlined,
                        label: 'Atanan',
                        value: widget.controller.assignedToName ?? 'Atanmamış',
                      ),
                      _DetailLine(
                        icon: Icons.person_outline_rounded,
                        label: 'Oluşturan',
                        value: widget.controller.creatorName ?? 'Bilinmiyor',
                      ),
                      _DetailLine(
                        icon: Icons.schedule_rounded,
                        label: 'Oluşturulma',
                        value: _formatDateTime(work.createdAt),
                      ),
                      if (work.startedAt != null) ...[
                        _DetailLine(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Başlatan',
                          value: widget.controller.starterName ?? 'Bilinmiyor',
                        ),
                        _DetailLine(
                          icon: Icons.timer_outlined,
                          label: 'Başlangıç',
                          value: _formatDateTime(work.startedAt!),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Açıklama',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(work.description),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildProgressSection(context),
                if (widget.completionController != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildCompletionSection(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final notes = widget.controller.notes;
    final isSubmitting = widget.controller.isSubmitting;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İlerleme Geçmişi',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          if (notes.isEmpty)
            const Text('Henüz ilerleme kaydı yok.')
          else
            for (var index = 0; index < notes.length; index++) ...[
              _ProgressNoteRow(
                note: notes[index],
                authorName:
                    widget.controller.authorName(notes[index]) ?? 'Kullanıcı',
              ),
              if (index != notes.length - 1)
                const Divider(height: AppSpacing.xl),
            ],
          if (widget.controller.canAddProgress) ...[
            const SizedBox(height: AppSpacing.xl),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _noteController,
                    label: 'İlerleme notu',
                    hint: 'Yapılan çalışmayı ve mevcut durumu açıklayın.',
                    prefixIcon: Icons.edit_note_rounded,
                    enabled: !isSubmitting,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'İlerleme notu boş olamaz.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton.primary(
                      label: isSubmitting
                          ? 'Kaydediliyor...'
                          : 'İlerleme Kaydı Ekle',
                      onPressed: isSubmitting ? null : _submitProgress,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionSection(BuildContext context) {
    final controller = widget.completionController!;
    final isLoading =
        controller.detailStatus == TechnicalWorkCompletionStatus.loading;
    final isSubmitting = controller.isSubmittingRequest;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tamamlama Talepleri',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isLoading)
            const AppLoading(message: 'Tamamlama geçmişi yükleniyor...')
          else if (controller.history.isEmpty)
            const Text('Henüz tamamlama talebi yok.')
          else
            for (var index = 0; index < controller.history.length; index++) ...[
              _CompletionRequestRow(
                request: controller.history[index],
                requesterName:
                    controller.userName(
                      controller.history[index].requestedByUserId,
                    ) ??
                    'Kullanıcı',
                reviewerName: controller.history[index].reviewedByUserId == null
                    ? null
                    : controller.userName(
                        controller.history[index].reviewedByUserId!,
                      ),
              ),
              if (index != controller.history.length - 1)
                const Divider(height: AppSpacing.xl),
            ],
          if (controller.canRequestCompletion) ...[
            const SizedBox(height: AppSpacing.xl),
            Form(
              key: _completionFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _completionSummaryController,
                    label: 'Tamamlama özeti',
                    hint: 'Tamamlanan çalışmayı ve sonucu açıklayın.',
                    prefixIcon: Icons.task_alt_rounded,
                    enabled: !isSubmitting,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Tamamlama özeti boş olamaz.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton.primary(
                      label: isSubmitting
                          ? 'Gönderiliyor...'
                          : 'Tamamlanmak Üzere Gönder',
                      size: AppButtonSize.small,
                      onPressed: isSubmitting ? null : _submitCompletionRequest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletionRequestRow extends StatelessWidget {
  final TechnicalWorkCompletionRequest request;
  final String requesterName;
  final String? reviewerName;

  const _CompletionRequestRow({
    required this.request,
    required this.requesterName,
    required this.reviewerName,
  });

  @override
  Widget build(BuildContext context) {
    final decisionLabel = switch (request.decision) {
      TechnicalWorkCompletionDecision.pending => 'Onay Bekliyor',
      TechnicalWorkCompletionDecision.approved => 'Onaylandı',
      TechnicalWorkCompletionDecision.rejected => 'Reddedildi',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              requesterName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(_formatDateTime(request.requestedAt)),
            Text(decisionLabel),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(request.summary),
        if (request.reviewedAt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'İnceleyen: ${reviewerName ?? 'Kullanıcı'} · '
            '${_formatDateTime(request.reviewedAt!)}',
          ),
        ],
        if (request.rejectionReason != null)
          Text('Ret nedeni: ${request.rejectionReason}'),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ProgressNoteRow extends StatelessWidget {
  final TechnicalWorkProgressNote note;
  final String authorName;

  const _ProgressNoteRow({required this.note, required this.authorName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              authorName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              _formatDateTime(note.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(note.content),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
