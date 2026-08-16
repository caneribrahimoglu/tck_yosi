import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/enums/app_status_type.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../core/enums/app_snackbar_type.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/models/app_user.dart';
import '../../technical_operations/domain/enums/technical_work_priority.dart';
import '../../technical_operations/domain/enums/assignment_target_type.dart';
import '../../technical_operations/domain/models/assignment_target.dart';
import '../../technical_operations/domain/models/technical_work.dart';
import '../../technical_operations/presentation/controllers/technical_work_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_load_status.dart';
import '../../technical_operations/presentation/technical_work_presentation.dart';

class ChiefDashboardPage extends StatefulWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final TechnicalWorkController technicalWorkController;
  final Future<void> Function() onCreateFieldReport;
  final Future<void> Function() onManageTeams;
  final Future<void> Function(TechnicalWork work)? onViewDetail;

  const ChiefDashboardPage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.technicalWorkController,
    required this.onCreateFieldReport,
    required this.onManageTeams,
    this.onViewDetail,
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
              AppPermission.createFieldReport,
            ))
              AppButton.secondary(
                label: 'Saha Bildirimi Oluştur',
                icon: Icons.add_location_alt_outlined,
                onPressed: widget.onCreateFieldReport,
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
                onPressed: widget.onManageTeams,
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
              return _ChiefWorkCard(
                work: priorityWorks[index],
                assignedToName: widget.technicalWorkController.assignedToName(
                  priorityWorks[index],
                ),
                startedByName: widget.technicalWorkController.startedByName(
                  priorityWorks[index],
                ),
                onViewDetail: widget.onViewDetail == null
                    ? null
                    : () => widget.onViewDetail!(priorityWorks[index]),
                onInspect:
                    !priorityWorks[index].isAssigned &&
                        widget.currentUser.hasPermission(
                          AppPermission.assignTechnicalWork,
                        )
                    ? () => _openAssignmentDialog(priorityWorks[index])
                    : null,
              );
            },
          ),
      ],
    );
  }

  Future<void> _openAssignmentDialog(TechnicalWork work) async {
    final assigned = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WorkAssignmentDialog(
        work: work,
        controller: widget.technicalWorkController,
      ),
    );

    if (!mounted || assigned == null) {
      return;
    }

    AppSnackbar.show(
      context: context,
      message: assigned
          ? 'Bildirim önceliklendirildi ve başarıyla atandı.'
          : widget.technicalWorkController.errorMessage ??
                'Bildirim atanamadı.',
      type: assigned ? AppSnackbarType.success : AppSnackbarType.error,
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
                _RecentOperationRow(
                  work: displayedWorks[index],
                  assignedToName: widget.technicalWorkController.assignedToName(
                    displayedWorks[index],
                  ),
                  startedByName: widget.technicalWorkController.startedByName(
                    displayedWorks[index],
                  ),
                  onViewDetail: widget.onViewDetail == null
                      ? null
                      : () => widget.onViewDetail!(displayedWorks[index]),
                ),
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
  final String? assignedToName;
  final String? startedByName;
  final VoidCallback? onInspect;
  final VoidCallback? onViewDetail;

  const _ChiefWorkCard({
    required this.work,
    required this.assignedToName,
    required this.startedByName,
    this.onInspect,
    this.onViewDetail,
  });

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
                    if (assignedToName != null ||
                        startedByName != null ||
                        work.startedAt != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _WorkTraceMetadata(
                        assignedToName: assignedToName,
                        startedByName: startedByName,
                        startedAt: work.startedAt,
                      ),
                    ],
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
              if (onViewDetail != null)
                AppButton.secondary(
                  label: 'Detayı Gör',
                  icon: Icons.open_in_new_rounded,
                  onPressed: onViewDetail,
                ),
              if (onInspect != null)
                AppButton.primary(
                  label: 'İncele ve Ata',
                  icon: Icons.assignment_ind_outlined,
                  onPressed: onInspect,
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

class _WorkAssignmentDialog extends StatefulWidget {
  final TechnicalWork work;
  final TechnicalWorkController controller;

  const _WorkAssignmentDialog({required this.work, required this.controller});

  @override
  State<_WorkAssignmentDialog> createState() => _WorkAssignmentDialogState();
}

class _WorkAssignmentDialogState extends State<_WorkAssignmentDialog> {
  late TechnicalWorkPriority _priority;
  AssignmentTarget? _target;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _priority = widget.work.priority;
  }

  Future<void> _assign() async {
    if (_target == null) {
      setState(() {
        _validationMessage = 'Lütfen bir mühendis veya ekip seçin.';
      });
      return;
    }

    final succeeded = await widget.controller.assignWork(
      workId: widget.work.id,
      priority: _priority,
      target: _target!,
    );

    if (mounted) {
      Navigator.of(context).pop(succeeded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final isAssigning = widget.controller.isAssigning;

        return PopScope(
          canPop: !isAssigning,
          child: AlertDialog(
            title: const Text('Saha Bildirimini İncele'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.work.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(widget.work.description),
                    const SizedBox(height: AppSpacing.md),
                    _AssignmentDetailRow(
                      icon: Icons.location_on_outlined,
                      text: widget.work.location,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AssignmentDetailRow(
                      icon: widget.work.category.icon,
                      text: widget.work.category.label,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppDropdown<TechnicalWorkPriority>(
                      value: _priority,
                      label: 'Öncelik',
                      prefixIcon: Icons.priority_high_rounded,
                      items: TechnicalWorkPriority.values
                          .map(
                            (priority) => DropdownMenuItem(
                              value: priority,
                              child: Text(priority.label),
                            ),
                          )
                          .toList(),
                      onChanged: isAssigning
                          ? null
                          : (priority) {
                              if (priority != null) {
                                setState(() => _priority = priority);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppDropdown<AssignmentTarget>(
                      value: _target,
                      label: 'Mühendis / Ekip',
                      prefixIcon: Icons.groups_outlined,
                      items: widget.controller.assignmentTargets
                          .map(
                            (target) => DropdownMenuItem(
                              value: target,
                              child: Text(
                                '${target.name} (${target.type.label})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isAssigning
                          ? null
                          : (target) {
                              setState(() {
                                _target = target;
                                _validationMessage = null;
                              });
                            },
                    ),
                    if (_validationMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _validationMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              AppButton.secondary(
                label: 'Vazgeç',
                onPressed: isAssigning
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
              AppButton.primary(
                label: isAssigning ? 'Atanıyor...' : 'Görevi Ata',
                icon: Icons.assignment_turned_in_outlined,
                onPressed: isAssigning ? null : _assign,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssignmentDetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AssignmentDetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    );
  }
}

extension on AssignmentTargetType {
  String get label => switch (this) {
    AssignmentTargetType.engineer => 'Mühendis',
    AssignmentTargetType.team => 'Ekip',
  };
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
  final String? assignedToName;
  final String? startedByName;
  final VoidCallback? onViewDetail;

  const _RecentOperationRow({
    required this.work,
    required this.assignedToName,
    required this.startedByName,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final information = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              if (assignedToName != null ||
                  startedByName != null ||
                  work.startedAt != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _WorkTraceMetadata(
                  assignedToName: assignedToName,
                  startedByName: startedByName,
                  startedAt: work.startedAt,
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppStatusChip(label: work.status.label, type: work.status.statusType),
        if (onViewDetail != null)
          AppButton.secondary(
            label: 'Detayı Gör',
            icon: Icons.open_in_new_rounded,
            onPressed: onViewDetail,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              information,
              const SizedBox(height: AppSpacing.md),
              actions,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: information),
            const SizedBox(width: AppSpacing.md),
            actions,
          ],
        );
      },
    );
  }
}

class _WorkTraceMetadata extends StatelessWidget {
  final String? assignedToName;
  final String? startedByName;
  final DateTime? startedAt;

  const _WorkTraceMetadata({
    required this.assignedToName,
    required this.startedByName,
    required this.startedAt,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        if (assignedToName != null)
          Text('Atanan: $assignedToName', style: style),
        if (startedByName != null)
          Text('Başlatan: $startedByName', style: style),
        if (startedAt != null)
          Text('Başlangıç: ${_formatDateTime(startedAt!)}', style: style),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
