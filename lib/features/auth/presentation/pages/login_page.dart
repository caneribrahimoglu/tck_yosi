import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/enums/app_snackbar_type.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/enums/auth_failure.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends StatefulWidget {
  final AuthController authController;

  const LoginPage({super.key, required this.authController});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid) {
      return;
    }

    final success = await widget.authController.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted || success) {
      return;
    }

    AppSnackbar.show(
      context: context,
      type: AppSnackbarType.error,
      message: _failureMessage(widget.authController.failure),
    );
  }

  String _failureMessage(AuthFailure? failure) {
    return switch (failure) {
      AuthFailure.invalidCredentials => 'Kullanıcı adı veya parola hatalı.',
      AuthFailure.inactiveAccount =>
        'Hesabınız aktif değil. Sistem yöneticisiyle iletişime geçin.',
      AuthFailure.networkError =>
        'Sunucuya ulaşılamadı. Lütfen bağlantınızı kontrol edin.',
      AuthFailure.unknown || null => 'Beklenmeyen bir hata oluştu.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, child) {
        final isLoading = widget.authController.isLoading;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.account_circle_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'TCK YÖSİ',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Operasyon Yönetim Platformu',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppTextField(
                              controller: _usernameController,
                              label: 'Kullanıcı adı',
                              hint: 'Kullanıcı adınızı girin',
                              prefixIcon: Icons.person_outline,
                              enabled: !isLoading,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Kullanıcı adı zorunludur.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              controller: _passwordController,
                              label: 'Parola',
                              hint: 'Parolanızı girin',
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixIconPressed: isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                              enabled: !isLoading,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                _submit();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Parola zorunludur.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppButton.primary(
                              label: isLoading
                                  ? 'Giriş yapılıyor...'
                                  : 'Giriş Yap',
                              icon: isLoading ? null : Icons.login,
                              onPressed: isLoading ? null : _submit,
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
}
