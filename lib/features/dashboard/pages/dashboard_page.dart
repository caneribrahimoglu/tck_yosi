import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_dropdown.dart';
import '../../../../core/enums/app_dialog_type.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../core/enums/app_snackbar_type.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../core/enums/app_status_type.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../auth/domain/models/app_user.dart';

class DashboardPage extends StatefulWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;

  const DashboardPage({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedMenuIndex = 0;
  String? selectedFuelType;

  Future<void> _confirmLogout() async {
    final confirmed = await AppDialog.show(
      context: context,
      type: AppDialogType.confirm,
      title: 'Çıkış Yap',
      message: 'Oturumunuzu kapatmak istediğinize emin misiniz?',
      primaryButtonText: 'Çıkış Yap',
      secondaryButtonText: 'Vazgeç',
    );

    if (!confirmed) {
      return;
    }

    await widget.onLogout();
  }

  final List<_DashboardMenuItem> menuItems = const [
    _DashboardMenuItem(title: 'Personel', icon: Icons.people_alt_outlined),
    _DashboardMenuItem(title: 'Araçlar', icon: Icons.local_shipping_outlined),
    _DashboardMenuItem(title: 'Envanter', icon: Icons.inventory_2_outlined),
    _DashboardMenuItem(title: 'Raporlar', icon: Icons.bar_chart_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCK YÖSİ'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Row(
              children: [
                Text(widget.currentUser.fullName),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Çıkış yap',
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 240, child: _buildSideMenu()),
                const VerticalDivider(width: 1),
                Expanded(child: _buildDashboardContent()),
              ],
            );
          }

          return _buildDashboardContent();
        },
      ),
      drawer: MediaQuery.sizeOf(context).width < 900
          ? Drawer(child: SafeArea(child: _buildSideMenu()))
          : null,
    );
  }

  Widget _buildSideMenu() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Text(
              'Yönetim Menüsü',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          ...List.generate(menuItems.length, (index) {
            final item = menuItems[index];
            final isSelected = selectedMenuIndex == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                selected: isSelected,
                leading: Icon(item.icon),
                title: Text(item.title),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  setState(() {
                    selectedMenuIndex = index;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPageHeader(
            title: 'TCK YÖSİ Dashboard',
            subtitle: 'Yönetim sistemine genel bakış',
          ),
          const SizedBox(height: AppSpacing.xl),

          _buildSummaryCards(),

          const SizedBox(height: AppSpacing.xl),

          Text(
            'AppButton Test Alanı',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),

          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              AppButton.primary(
                label: 'Primary',
                icon: Icons.add,
                onPressed: () {
                  debugPrint('Primary butona basıldı');
                },
              ),
              AppButton.secondary(
                label: 'Secondary',
                icon: Icons.edit_outlined,
                onPressed: () {
                  debugPrint('Secondary butona basıldı');
                },
              ),
              AppButton.danger(
                label: 'Danger',
                icon: Icons.delete_outline,
                onPressed: () {
                  debugPrint('Danger butona basıldı');
                },
              ),
              const AppButton.primary(
                label: 'Kaydetme Yetkiniz Yok',
                icon: Icons.lock_outline,
                onPressed: null,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            'AppLoading Test Alanı',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppSpacing.md),

          const AppCard(child: AppLoading(message: 'Veriler yükleniyor...')),

          const SizedBox(height: AppSpacing.xl),

          Text(
            'AppTextField Test Alanı',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: AppSpacing.md),

          AppCard(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Araç plakası',
                    hint: '34 ABC 123',
                    prefixIcon: Icons.directions_car_outlined,
                  ),
                  SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Devre dışı alan',
                    hint: 'Bu alan düzenlenemez',
                    prefixIcon: Icons.lock_outline,
                    enabled: false,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppDropdown<String>(
                    label: 'Yakıt türü',
                    hint: 'Seçiniz',
                    prefixIcon: Icons.local_gas_station_outlined,
                    value: selectedFuelType,
                    items: const [
                      DropdownMenuItem(value: 'diesel', child: Text('Dizel')),
                      DropdownMenuItem(
                        value: 'gasoline',
                        child: Text('Benzin'),
                      ),
                      DropdownMenuItem(value: 'hybrid', child: Text('Hibrit')),
                      DropdownMenuItem(
                        value: 'electric',
                        child: Text('Elektrik'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedFuelType = value;
                      });
                    },
                  ),
                  AppButton.secondary(
                    label: 'Dialog Aç',
                    icon: Icons.open_in_new,
                    onPressed: () async {
                      final confirmed = await AppDialog.show(
                        context: context,
                        type: AppDialogType.confirm,
                        title: 'Kaydı Sil',
                        message: 'Bu işlem geri alınamaz.',
                        primaryButtonText: 'Sil',
                        secondaryButtonText: 'Vazgeç',
                      );

                      debugPrint('Dialog sonucu: $confirmed');
                    },
                  ),
                  AppButton.primary(
                    label: 'Başarılı',
                    icon: Icons.check_circle_outline,
                    onPressed: () {
                      AppSnackbar.show(
                        context: context,
                        type: AppSnackbarType.success,
                        message: 'Kayıt başarıyla oluşturuldu.',
                      );
                    },
                  ),

                  AppButton.danger(
                    label: 'Hata',
                    icon: Icons.error_outline,
                    onPressed: () {
                      AppSnackbar.show(
                        context: context,
                        type: AppSnackbarType.error,
                        message: 'İşlem sırasında bir hata oluştu.',
                      );
                    },
                  ),

                  AppButton.secondary(
                    label: 'Uyarı',
                    icon: Icons.warning_amber_rounded,
                    onPressed: () {
                      AppSnackbar.show(
                        context: context,
                        type: AppSnackbarType.warning,
                        message: 'Lütfen zorunlu alanları kontrol edin.',
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    'AppStatusChip Test Alanı',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  const Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppStatusChip(
                        label: 'Aktif',
                        type: AppStatusType.success,
                      ),
                      AppStatusChip(
                        label: 'Bakımda',
                        type: AppStatusType.warning,
                      ),
                      AppStatusChip(
                        label: 'Arızalı',
                        type: AppStatusType.error,
                      ),
                      AppStatusChip(label: 'Bilgi', type: AppStatusType.info),
                      AppStatusChip(
                        label: 'Pasif',
                        type: AppStatusType.neutral,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 1000
            ? (constraints.maxWidth - (AppSpacing.md * 2)) / 3
            : constraints.maxWidth >= 600
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: cardWidth,
              child: const _SummaryCard(
                title: 'Personel',
                value: '24',
                icon: Icons.people_alt_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: const _SummaryCard(
                title: 'Araç',
                value: '12',
                icon: Icons.local_shipping_outlined,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: const _SummaryCard(
                title: 'Envanter',
                value: '96',
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMenuItem {
  final String title;
  final IconData icon;

  const _DashboardMenuItem({required this.title, required this.icon});
}
