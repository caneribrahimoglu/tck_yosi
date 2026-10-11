import 'package:flutter/material.dart';
import '../../../core/enums/app_snackbar_type.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/enums/user_role.dart';
import '../../auth/domain/models/app_user.dart';
import '../../teams/presentation/team_permission_presentation.dart';
import 'user_management_controller.dart';

class UserManagementPage extends StatefulWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final UserManagementController controller;
  const UserManagementPage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.controller,
  });

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  Future<void> _form({AppUser? user, bool permissions = false}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserForm(
        controller: widget.controller,
        user: user,
        permissions: permissions,
      ),
    );
  }

  Future<void> _setActive(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          user.isActive ? 'Kullanıcıyı pasifleştir' : 'Kullanıcıyı aktifleştir',
        ),
        content: Text(
          '${user.fullName} için hesap durumu değiştirilecek. Pasif kullanıcı giriş yapamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await widget.controller.setActive(user, !user.isActive);
    if (!mounted) return;
    AppSnackbar.show(
      context: context,
      type: success ? AppSnackbarType.success : AppSnackbarType.error,
      message: success
          ? 'Hesap durumu güncellendi.'
          : widget.controller.errorMessage ?? 'İşlem yapılamadı.',
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Personel Yönetimi'),
          actions: [
            IconButton(
              tooltip: 'Çıkış yap',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: !c.canManage
            ? const Center(
                child: Text('Kullanıcı yönetimi yetkiniz bulunmuyor.'),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Kullanıcı Yönetimi',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${widget.currentUser.fullName} • Hesaplar ve doğrudan yetkiler gerçek sunucu kayıtlarıdır.',
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: c.isProcessing ? null : () => _form(),
                              icon: const Icon(Icons.person_add_outlined),
                              label: const Text('Kullanıcı Oluştur'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  c.status == UserManagementStatus.loading ||
                                      c.isProcessing
                                  ? null
                                  : c.load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Yenile'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (c.status == UserManagementStatus.loading)
                          const Center(child: CircularProgressIndicator())
                        else if (c.status == UserManagementStatus.failure)
                          Text(c.errorMessage ?? 'Kullanıcılar yüklenemedi.')
                        else if (c.users.isEmpty)
                          const Text('Henüz kullanıcı bulunmuyor.')
                        else
                          ...c.users.map(
                            (user) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '${user.username} • ${_roleLabel(user.role)} • ${user.isActive ? "Aktif" : "Pasif"}',
                                    ),
                                    if (user.mustChangePassword)
                                      const Text(
                                        'İlk girişte parola değişimi gerekli.',
                                      ),
                                    Text(
                                      'Doğrudan yetki: ${user.permissions.length}',
                                    ),
                                    if (c.canModify(user))
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          TextButton(
                                            onPressed: c.isProcessing
                                                ? null
                                                : () => _form(
                                                    user: user,
                                                    permissions: true,
                                                  ),
                                            child: const Text(
                                              'Yetkileri Düzenle',
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: c.isProcessing
                                                ? null
                                                : () => _form(user: user),
                                            child: const Text('Geçici Parola'),
                                          ),
                                          TextButton(
                                            onPressed: c.isProcessing
                                                ? null
                                                : () => _setActive(user),
                                            child: Text(
                                              user.isActive
                                                  ? 'Pasifleştir'
                                                  : 'Aktifleştir',
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const Text('Yönetici hesabı korunuyor.'),
                                  ],
                                ),
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
  );
}

String _roleLabel(UserRole role) => switch (role) {
  UserRole.engineer => 'Mühendis',
  UserRole.driver => 'Şoför',
  UserRole.chief => 'Şef',
  UserRole.technician => 'Teknisyen',
  UserRole.cleaningStaff => 'Temizlik Personeli',
  UserRole.director => 'Müdür',
  UserRole.admin => 'Yönetici',
};

class _UserForm extends StatefulWidget {
  final UserManagementController controller;
  final AppUser? user;
  final bool permissions;
  const _UserForm({
    required this.controller,
    this.user,
    this.permissions = false,
  });
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.engineer;
  late final Set<AppPermission> _permissions = Set.of(
    widget.user?.permissions ?? {},
  );

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final c = widget.controller;
    final user = widget.user;
    final success = widget.permissions
        ? await c.updatePermissions(user!, _permissions)
        : user == null
        ? await c.createUser(
            fullName: _name.text,
            username: _username.text,
            role: _role,
            temporaryPassword: _password.text,
          )
        : await c.resetPassword(user, _password.text);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      AppSnackbar.show(
        context: context,
        type: AppSnackbarType.success,
        message: widget.permissions
            ? 'Doğrudan yetkiler güncellendi.'
            : user == null
            ? 'Kullanıcı oluşturuldu. İlk girişte parolasını değiştirmelidir.'
            : 'Geçici parola yenilendi. İlk girişte değiştirilmelidir.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final creating = widget.user == null;
      return PopScope(
        canPop: !c.isProcessing,
        child: AlertDialog(
          title: Text(
            widget.permissions
                ? 'Doğrudan Yetkiler'
                : creating
                ? 'Kullanıcı Oluştur'
                : 'Geçici Parola',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.permissions) ...[
                      const Text(
                        'Ekip yetkileri ayrı yönetilir. Yönetim yetkileri bu listeden devredilemez.',
                      ),
                      ...c.grantablePermissions.map(
                        (permission) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(permission.teamLabel),
                          value: _permissions.contains(permission),
                          onChanged: c.isProcessing
                              ? null
                              : (checked) => setState(() {
                                  checked == true
                                      ? _permissions.add(permission)
                                      : _permissions.remove(permission);
                                }),
                        ),
                      ),
                    ] else ...[
                      if (creating) ...[
                        AppTextField(
                          controller: _name,
                          label: 'Ad Soyad',
                          enabled: !c.isProcessing,
                          validator: (v) => (v?.trim().length ?? 0) < 2
                              ? 'Ad soyad gerekli.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _username,
                          label: 'Kullanıcı adı',
                          enabled: !c.isProcessing,
                          validator: (v) =>
                              !RegExp(
                                r'^[a-zA-Z0-9_.-]{3,50}$',
                              ).hasMatch(v?.trim() ?? '')
                              ? 'En az 3 karakter; harf, sayı, nokta, tire veya alt çizgi.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        AppDropdown<UserRole>(
                          label: 'Rol',
                          value: _role,
                          enabled: !c.isProcessing,
                          items:
                              [
                                    UserRole.engineer,
                                    UserRole.driver,
                                    UserRole.technician,
                                    UserRole.cleaningStaff,
                                  ]
                                  .map(
                                    (role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(_roleLabel(role)),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (role) {
                            if (role != null) _role = role;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      AppTextField(
                        controller: _password,
                        label: 'Geçici parola',
                        obscureText: true,
                        enabled: !c.isProcessing,
                        validator: (v) => (v?.length ?? 0) < 12
                            ? 'En az 12 karakter gerekli.'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kullanıcı ilk girişte bu parolayı değiştirmek zorundadır.',
                      ),
                    ],
                    if (c.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          c.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: c.isProcessing ? null : () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: c.isProcessing ? null : _submit,
              child: Text(c.isProcessing ? 'Kaydediliyor...' : 'Kaydet'),
            ),
          ],
        ),
      );
    },
  );
}
