import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/enums/app_snackbar_type.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../auth_failure_message.dart';
import '../controllers/auth_controller.dart';

class ChangePasswordPage extends StatefulWidget {
  final AuthController controller;
  const ChangePasswordPage({super.key, required this.controller});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final success = await widget.controller.changePassword(
      currentPassword: _current.text,
      newPassword: _new.text,
    );
    if (!mounted || success) return;
    AppSnackbar.show(
      context: context,
      type: AppSnackbarType.error,
      message: authFailureMessage(widget.controller.failure),
    );
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final busy = widget.controller.isChangingPassword;
      return PopScope(
        canPop: !busy,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AppCard(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Parolanızı Değiştirin',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'İlk girişinizi tamamlamak için geçici parolanızı değiştirin. Yeni parola en az 12 karakter olmalıdır.',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _current,
                            label: 'Mevcut parola',
                            obscureText: true,
                            enabled: !busy,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Mevcut parola zorunludur.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _new,
                            label: 'Yeni parola',
                            obscureText: true,
                            enabled: !busy,
                            validator: (v) => v == null || v.length < 12
                                ? 'Parola en az 12 karakter olmalıdır.'
                                : v == _current.text
                                ? 'Yeni parola mevcut paroladan farklı olmalıdır.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _confirm,
                            label: 'Yeni parola tekrar',
                            obscureText: true,
                            enabled: !busy,
                            validator: (v) =>
                                v != _new.text ? 'Parolalar eşleşmiyor.' : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton.primary(
                            label: busy
                                ? 'Kaydediliyor...'
                                : 'Parolayı Değiştir',
                            onPressed: busy ? null : _submit,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: busy ? null : widget.controller.logout,
                            child: const Text('Çıkış yap'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
