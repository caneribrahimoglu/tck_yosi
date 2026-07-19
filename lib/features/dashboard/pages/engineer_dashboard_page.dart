import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/models/app_user.dart';
import '../../technical_operations/domain/enums/technical_work_priority.dart';
import '../../technical_operations/domain/models/technical_work.dart';
import '../../technical_operations/presentation/controllers/technical_work_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_load_status.dart';
import '../../technical_operations/presentation/technical_work_presentation.dart';

class EngineerDashboardPage extends StatefulWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final TechnicalWorkController technicalWorkController;

  const EngineerDashboardPage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.technicalWorkController,
  });

  @override
  State<EngineerDashboardPage> createState() {
    return _EngineerDashboardPageState();
  }
}

class _EngineerDashboardPageState extends State<EngineerDashboardPage> {
  @override
  void initState() {
    super.initState();

    widget.technicalWorkController.load(widget.currentUser.id);
  }

  @override
  void didUpdateWidget(covariant EngineerDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentUser.id != widget.currentUser.id) {
      widget.technicalWorkController.load(widget.currentUser.id);
    }
  }

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
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.technicalWorkController,
        builder: (context, child) {
          return switch (widget.technicalWorkController.status) {
            TechnicalWorkLoadStatus.initial ||
            TechnicalWorkLoadStatus.loading => const AppLoading(
              message: 'Teknik işler yükleniyor...',
            ),
            TechnicalWorkLoadStatus.loaded => _buildLoadedContent(context),
            TechnicalWorkLoadStatus.failure => _buildFailureContent(context),
          };
        },
      ),
    );
  }

  Widget _buildLoadedContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPageHeader(
            title: 'Teknik Operasyonlar',
            subtitle:
                'Hoş geldin, ${widget.currentUser.fullName}. '
                'Saha işlerini ve teknik süreçleri '
                'buradan takip edebilirsin.',
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildSummarySection(context),
          const SizedBox(height: AppSpacing.xl),
          _buildQuickActions(context),
          const SizedBox(height: AppSpacing.xl),
          _buildAssignedWorkSection(context),
        ],
      ),
    );
  }

  Widget _buildFailureContent(BuildContext context) {
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
              widget.technicalWorkController.errorMessage ??
                  'Beklenmeyen bir hata oluştu.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Tekrar Dene',
              icon: Icons.refresh_rounded,
              onPressed: () {
                widget.technicalWorkController.load(widget.currentUser.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    final controller = widget.technicalWorkController;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = switch (constraints.maxWidth) {
          >= 1100 => 3,
          >= 650 => 2,
          _ => 1,
        };

        final totalSpacing = AppSpacing.md * (columnCount - 1);

        final cardWidth = (constraints.maxWidth - totalSpacing) / columnCount;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Açık Teknik İşler',
                value: controller.openWorkCount.toString(),
                icon: Icons.engineering_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Kritik Bildirimler',
                value: controller.criticalWorkCount.toString(),
                icon: Icons.warning_amber_rounded,
                color: Colors.red,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'İnceleme Bekleyenler',
                value: controller.awaitingInspectionCount.toString(),
                icon: Icons.manage_search_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (widget.currentUser.hasPermission(
              AppPermission.createFaultReport,
            ))
              AppButton.primary(
                label: 'Saha Bildirimi Oluştur',
                icon: Icons.add_location_alt_outlined,
                onPressed: () {},
              ),
            AppButton.secondary(
              label: 'Bana Atanan İşler',
              icon: Icons.assignment_ind_outlined,
              onPressed: () {},
            ),
            AppButton.secondary(
              label: 'Planlı Çalışmalar',
              icon: Icons.event_note_outlined,
              onPressed: () {},
            ),
            if (widget.currentUser.hasPermission(AppPermission.viewReports))
              AppButton.secondary(
                label: 'Teknik Raporlar',
                icon: Icons.description_outlined,
                onPressed: () {},
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignedWorkSection(BuildContext context) {
    final assignedWorks = widget.technicalWorkController.assignedWorks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bana Atanan Teknik İşler',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        if (assignedWorks.isEmpty)
          const AppCard(
            child: Text(
              'Şu anda sana atanmış bir teknik iş '
              'bulunmuyor.',
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: assignedWorks.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: AppSpacing.md);
            },
            itemBuilder: (context, index) {
              final work = assignedWorks[index];

              return _TechnicalWorkCard(work: work);
            },
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
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
          ),
        ],
      ),
    );
  }
}

class _TechnicalWorkCard extends StatelessWidget {
  final TechnicalWork work;

  const _TechnicalWorkCard({required this.work});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final workDetails = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                work.category.icon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.location,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      work.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      work.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          );

          final statusChips = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (work.priority == TechnicalWorkPriority.high ||
                  work.priority == TechnicalWorkPriority.critical)
                AppStatusChip(
                  label: work.priority.label,
                  type: work.priority.statusType,
                ),
              AppStatusChip(
                label: work.status.label,
                type: work.status.statusType,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                workDetails,
                const SizedBox(height: AppSpacing.md),
                statusChips,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: workDetails),
              const SizedBox(width: AppSpacing.lg),
              statusChips,
            ],
          );
        },
      ),
    );
  }
}
