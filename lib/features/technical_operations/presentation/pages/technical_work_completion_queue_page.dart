import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/enums/app_dialog_type.dart';
import '../../../../core/enums/app_snackbar_type.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/technical_work.dart';
import '../controllers/technical_work_completion_controller.dart';
import '../controllers/technical_work_completion_status.dart';

class TechnicalWorkCompletionQueuePage extends StatefulWidget {
  final AppUser currentUser;
  final TechnicalWorkCompletionController controller;
  final Future<void> Function(TechnicalWork work)? onViewDetail;

  const TechnicalWorkCompletionQueuePage({
    super.key,
    required this.currentUser,
    required this.controller,
    this.onViewDetail,
  });

  @override
  State<TechnicalWorkCompletionQueuePage> createState() =>
      _TechnicalWorkCompletionQueuePageState();
}

class _TechnicalWorkCompletionQueuePageState
    extends State<TechnicalWorkCompletionQueuePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.loadPending(widget.currentUser.id);
      }
    });
  }

  Future<void> _approve(String requestId) async {
    final confirmed = await AppDialog.show(
      context: context,
      type: AppDialogType.success,
      title: 'İşi Tamamla',
      message: 'Bu tamamlama talebini onaylamak istiyor musunuz?',
      primaryButtonText: 'Onayla',
      secondaryButtonText: 'Vazgeç',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final succeeded = await widget.controller.approve(requestId);
    if (!mounted) {
      return;
    }
    _showResult(succeeded, 'İş tamamlandı.');
  }

  Future<void> _reject(String requestId) async {
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _RejectionDialog(),
    );
    if (reason == null || !mounted) {
      return;
    }
    final succeeded = await widget.controller.reject(
      requestId: requestId,
      reason: reason,
    );
    if (!mounted) {
      return;
    }
    _showResult(succeeded, 'Talep reddedildi; iş devam ediyor.');
  }

  void _showResult(bool succeeded, String successMessage) {
    AppSnackbar.show(
      context: context,
      type: succeeded ? AppSnackbarType.success : AppSnackbarType.error,
      message: succeeded
          ? successMessage
          : widget.controller.errorMessage ?? 'İşlem tamamlanamadı.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İş Tamamlama Onayları')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          if (widget.controller.queueStatus ==
              TechnicalWorkCompletionStatus.loading) {
            return const AppLoading(message: 'Onay talepleri yükleniyor...');
          }
          if (widget.controller.queueStatus ==
                  TechnicalWorkCompletionStatus.failure &&
              widget.controller.pendingReviews.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.controller.errorMessage ??
                          'Onay talepleri yüklenemedi.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(
                      label: 'Tekrar Dene',
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          widget.controller.loadPending(widget.currentUser.id),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = widget.controller.pendingReviews;
          if (items.isEmpty) {
            return const Center(
              child: Text('Bekleyen iş tamamlama onayı yok.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              final request = item.request;
              final busy = widget.controller.isReviewingAny;
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.work.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.work.location),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Talep eden: '
                      '${widget.controller.userName(request.requestedByUserId) ?? 'Kullanıcı'}',
                    ),
                    Text(
                      'Talep zamanı: ${_formatDateTime(request.requestedAt)}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(request.summary),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (widget.onViewDetail != null)
                          AppButton.secondary(
                            label: 'Detayı Gör',
                            icon: Icons.open_in_new_rounded,
                            onPressed: busy
                                ? null
                                : () => widget.onViewDetail!(item.work),
                          ),
                        AppButton.danger(
                          label: busy ? 'İşleniyor...' : 'Reddet',
                          icon: Icons.close_rounded,
                          onPressed: busy ? null : () => _reject(request.id),
                        ),
                        AppButton.primary(
                          label: busy ? 'İşleniyor...' : 'Onayla',
                          icon: Icons.check_rounded,
                          onPressed: busy ? null : () => _approve(request.id),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog();

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tamamlama Talebini Reddet'),
      content: Form(
        key: _formKey,
        child: AppTextField(
          controller: _controller,
          label: 'Ret nedeni',
          hint: 'Eksik veya düzeltilmesi gereken noktayı açıklayın.',
          prefixIcon: Icons.feedback_outlined,
          minLines: 3,
          maxLines: 5,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Ret nedeni boş olamaz.'
              : null,
        ),
      ),
      actions: [
        AppButton.secondary(
          label: 'Vazgeç',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.danger(label: 'Reddet', onPressed: _submit),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
