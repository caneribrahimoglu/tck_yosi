import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';

class DashboardPage extends StatefulWidget{
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
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Dashboard built çalıştı');

    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('TCK YÖSİ'),
        centerTitle: true,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileTabletLayout(),
    );

  }

  Widget _buildDesktopLayout() {
    return Row (
      children: [
        NavigationRail(
          selectedIndex: selectedMenuIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedMenuIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          destinations: menuItems.map(
              (item) => NavigationRailDestination(
                  icon: Icon(item.icon),
                  label: Text(item.title)),
          ).toList(),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Seçili modül: $selectedTitle',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
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
    return Card(
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMenuItem {
  final String title;
  final IconData icon;

  const _DashboardMenuItem({
    required this.title,
    required this.icon,
  });
}