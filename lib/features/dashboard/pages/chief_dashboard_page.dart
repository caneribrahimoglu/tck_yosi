import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/enums/app_status_type.dart';
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

class ChiefDashboardPage extends StatefulWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final TechnicalWorkController technicalWorkController;

  const ChiefDashboardPage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.technicalWorkController,
  });

  @override
  State<ChiefDashboardPage> createState() {
    return _ChiefDashboardPageState();
  }
}

class _ChiefDashboardPageState extends State<ChiefDashboardPage> {
  @override
  void initState() {
    super.initState();

    widget.technicalWorkController.load(widget.currentUser.id);
  }

  @override
  void didUpdateWidget(covariant ChiefDashboardPage oldWidget) {
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
              message: 'Şeflik operasyonları yükleniyor...',
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
            title: 'Şeflik Operasyon Merkezi',
            subtitle:
                'Hoş geldin, ${widget.currentUser.fullName}. '
                'Şefliğindeki operasyonları, ekipleri ve '
                'kritik süreçleri buradan yönetebilirsin.',
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildSummarySection(context),
          const SizedBox(height: AppSpacing.xl),
          _buildQuickManagementSection(context),
          const SizedBox(height: AppSpacing.xl),
          _buildManagementPanels(context),
          const SizedBox(height: AppSpacing.xl),
          _buildRecentOperationsSection(context),
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
                  'Operasyon bilgileri yüklenemedi.',
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
          >= 1200 => 4,
          _ => 2,
        };

        final totalSpacing = AppSpacing.md * (columnCount - 1);

        final cardWidth = (constraints.maxWidth - totalSpacing) / columnCount;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: cardWidth,
              child: _ChiefSummaryCard(
                title: 'Açık Operasyonlar',
                value: controller.openWorkCount.toString(),
                icon: Icons.dashboard_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ChiefSummaryCard(
                title: 'Kritik Olaylar',
                value: controller.criticalWorkCount.toString(),
                icon: Icons.crisis_alert_rounded,
                color: Colors.red,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ChiefSummaryCard(
                title: 'Atanmamış İşler',
                value: controller.unassignedWorkCount.toString(),
                icon: Icons.person_off_outlined,
                color: Colors.orange,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ChiefSummaryCard(
                title: 'Devam Eden İşler',
                value: controller.inProgressWorkCount.toString(),
                icon: Icons.sync_rounded,
                color: Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı Yönetim',
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
              AppPermission.assignTechnicalWork,
            ))
              AppButton.primary(
                label: 'Görev ve İş Ata',
                icon: Icons.assignment_add,
                onPressed: () {},
              ),
            if (widget.currentUser.hasPermission(
              AppPermission.approveOperations,
            ))
              AppButton.secondary(
                label: 'Onay Kuyruğu',
                icon: Icons.fact_check_outlined,
                onPressed: () {},
              ),
            if (widget.currentUser.hasPermission(AppPermission.managePersonnel))
              AppButton.secondary(
                label: 'Ekip Yönetimi',
                icon: Icons.groups_outlined,
                onPressed: () {},
              ),
            if (widget.currentUser.hasPermission(
              AppPermission.manageTeamPermissions,
            ))
              AppButton.secondary(
                label: 'Yetki Yönetimi',
                icon: Icons.admin_panel_settings_outlined,
                onPressed: () {},
              ),
            if (widget.currentUser.hasPermission(AppPermission.viewReports))
              AppButton.secondary(
                label: 'Operasyon Raporları',
                icon: Icons.analytics_outlined,
                onPressed: () {},
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildManagementPanels(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final prioritySection = _buildPriorityOperationsSection(context);

        final sidePanels = Column(
          children: [
            _buildTeamStatusCard(context),
            const SizedBox(height: AppSpacing.md),
            _buildApprovalQueueCard(context),
          ],
        );

        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: prioritySection),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(width: 360, child: sidePanels),
            ],
          );
        }

        return Column(
          children: [
            prioritySection,
            const SizedBox(height: AppSpacing.lg),
            sidePanels,
          ],
        );
      },
    );
  }

  Widget _buildPriorityOperationsSection(BuildContext context) {
    final priorityWorks = widget.technicalWorkController.allWorks
        .where((work) => work.isOpen && (work.isCritical || !work.isAssigned))
        .toList();

    priorityWorks.sort((first, second) {
      if (first.isAssigned != second.isAssigned) {
        return first.isAssigned ? 1 : -1;
      }

      return second.priority.index.compareTo(first.priority.index);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Öncelikli ve Atanmamış İşler',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        if (priorityWorks.isEmpty)
          const AppCard(
            child: Text(
              'Takip gerektiren kritik veya atanmamış '
              'bir iş bulunmuyor.',
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: priorityWorks.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: AppSpacing.md);
            },
            itemBuilder: (context, index) {
              return _ChiefWorkCard(work: priorityWorks[index]);
            },
          ),
      ],
    );
  }

  Widget _buildTeamStatusCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ekip Durumu',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _MetricRow(
            icon: Icons.engineering_outlined,
            label: 'Görevde',
            value: '3',
            color: Colors.blue,
          ),
          const SizedBox(height: AppSpacing.md),
          const _MetricRow(
            icon: Icons.check_circle_outline_rounded,
            label: 'Müsait',
            value: '2',
            color: Colors.green,
          ),
          const SizedBox(height: AppSpacing.md),
          const _MetricRow(
            icon: Icons.event_busy_outlined,
            label: 'İzinli',
            value: '1',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalQueueCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onay Bekleyenler',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ApprovalRow(label: 'İş tamamlama onayı', count: 2),
          const SizedBox(height: AppSpacing.md),
          const _ApprovalRow(label: 'Planlı çalışma onayı', count: 1),
          const SizedBox(height: AppSpacing.md),
          const _ApprovalRow(label: 'Görev değişikliği', count: 1),
        ],
      ),
    );
  }

  Widget _buildRecentOperationsSection(BuildContext context) {
    final recentWorks = [...widget.technicalWorkController.allWorks]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));

    final displayedWorks = recentWorks.take(4).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Operasyonlar',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              for (var index = 0; index < displayedWorks.length; index++) ...[
                _RecentOperationRow(work: displayedWorks[index]),
                if (index != displayedWorks.length - 1)
                  const Divider(height: AppSpacing.xl),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChiefSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ChiefSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 220;

        final iconContainer = Container(
          width: isCompact ? 40 : 48,
          height: isCompact ? 40 : 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: isCompact ? 22 : 24, color: color),
        );

        if (isCompact) {
          return AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    iconContainer,
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return AppCard(
          child: Row(
            children: [
              iconContainer,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChiefWorkCard extends StatelessWidget {
  final TechnicalWork work;

  const _ChiefWorkCard({required this.work});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final workInformation = Row(
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

          final workStatus = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (!work.isAssigned)
                const AppStatusChip(
                  label: 'Atanmamış',
                  type: AppStatusType.warning,
                ),
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
                workInformation,
                const SizedBox(height: AppSpacing.md),
                workStatus,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: workInformation),
              const SizedBox(width: AppSpacing.lg),
              workStatus,
            ],
          );
        },
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  final String label;
  final int count;

  const _ApprovalRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.pending_actions_outlined, color: Colors.orange),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
        AppStatusChip(
          label: count.toString(),
          type: AppStatusType.warning,
          showIcon: false,
        ),
      ],
    );
  }
}

class _RecentOperationRow extends StatelessWidget {
  final TechnicalWork work;

  const _RecentOperationRow({required this.work});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(work.category.icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                work.title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(work.location, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppStatusChip(label: work.status.label, type: work.status.statusType),
      ],
    );
  }
}
