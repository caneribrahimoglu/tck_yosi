import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedMenuIndex = 0;

  final List<_DashboardMenuItem> menuItems = const [
    _DashboardMenuItem(title: 'Personel', icon: Icons.people_alt),
    _DashboardMenuItem(title: 'Araçlar', icon: Icons.local_shipping),
    _DashboardMenuItem(title: 'Görevler', icon: Icons.assessment),
    _DashboardMenuItem(title: 'Raporlar', icon: Icons.bar_chart),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('Dashboard initState çalıştı');
  }

  @override
  void dispose() {
    debugPrint('Dashboard dispose çalıştı');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Dashboard built çalıştı');

    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(title: const Text('TCK YÖSİ'), centerTitle: true),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileTabletLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedMenuIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedMenuIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          destinations: menuItems
              .map(
                (item) => NavigationRailDestination(
                  icon: Icon(item.icon),
                  label: Text(item.title),
                ),
              )
              .toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _DashboardContent(
            selectedTitle: menuItems[selectedMenuIndex].title,
            crossAxisCount: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabletLayout() {
    final isTablet = Responsive.isTablet(context);

    return _DashboardContent(
      selectedTitle: menuItems[selectedMenuIndex].title,
      crossAxisCount: isTablet ? 3 : 2,
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final String selectedTitle;
  final int crossAxisCount;

  const _DashboardContent({
    required this.selectedTitle,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Seçili modül: $selectedTitle',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: GridView.count(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: AppSpacing.lg,
                crossAxisSpacing: AppSpacing.lg,
                children: const [
                  _SummaryCard(
                    title: 'Personel',
                    value: '24',
                    icon: Icons.people_alt,
                  ),
                  _SummaryCard(
                    title: 'Araçlar',
                    value: '12',
                    icon: Icons.local_shipping,
                  ),
                  _SummaryCard(
                    title: 'Aktif Görev',
                    value: '8',
                    icon: Icons.assignment,
                  ),
                  _SummaryCard(
                    title: 'Envanter',
                    value: '96',
                    icon: Icons.warning_amber,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                AppButton.primary(
                  label: 'Kaydet',
                  icon: Icons.save_outlined,
                  onPressed: () {
                    debugPrint('Kaydet tıklandı');
                  },
                ),
                AppButton.secondary(
                  label: 'İptal',
                  onPressed: () {
                    debugPrint('İptal tıklandı');
                  },
                ),
                AppButton.danger(
                  label: 'Sil',
                  icon: Icons.delete_outline,
                  onPressed: () {
                    debugPrint('Sil tıklandı');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
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
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(title, textAlign: TextAlign.center),
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
