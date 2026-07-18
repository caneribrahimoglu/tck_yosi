import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../auth/domain/models/app_user.dart';
import '../../auth/domain/enums/app_permission.dart';

class DriverDashboardPage extends StatelessWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;

  const DriverDashboardPage({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

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
                Text(currentUser.fullName),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Çıkış yap',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Hoş geldin, ${currentUser.fullName}',
              subtitle: 'Bugünkü görevlerin ve araç işlemlerin',
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildAssignedVehicle(context),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Hızlı İşlemler',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                if (currentUser.hasPermission(AppPermission.receiveVehicle))
                  AppButton.primary(
                    label: 'Aracı Teslim Al',
                    icon: Icons.key_rounded,
                    onPressed: () {},
                  ),
                if (currentUser.hasPermission(AppPermission.updateMileage))
                  AppButton.secondary(
                    label: 'Kilometre Gir',
                    icon: Icons.speed_rounded,
                    onPressed: () {},
                  ),
                if (currentUser.hasPermission(AppPermission.createFuelRecord))
                  AppButton.secondary(
                    label: 'Yakıt Kaydı',
                    icon: Icons.local_gas_station_outlined,
                    onPressed: () {},
                  ),
                if (currentUser.hasPermission(AppPermission.createFaultReport))
                  AppButton.danger(
                    label: 'Arıza Bildir',
                    icon: Icons.warning_amber_rounded,
                    onPressed: () {},
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedVehicle(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bugünkü Aracın',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '34 ABC 123',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Ford Transit • 125.430 km',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
