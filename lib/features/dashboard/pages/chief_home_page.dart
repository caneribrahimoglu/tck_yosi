import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/models/app_user.dart';
import '../../technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_completion_status.dart';
import '../../technical_operations/presentation/controllers/technical_work_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_load_status.dart';
import '../widgets/module_card.dart';

class ChiefHomePage extends StatefulWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final TechnicalWorkController technicalWorkController;
  final TechnicalWorkCompletionController? completionController;
  final Future<void> Function()? onOpenOperations;
  final Future<void> Function()? onOpenVehicles;
  final Future<void> Function()? onOpenPersonnel;

  const ChiefHomePage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.technicalWorkController,
    this.completionController,
    this.onOpenOperations,
    this.onOpenVehicles,
    this.onOpenPersonnel,
  });

  @override
  State<ChiefHomePage> createState() => _ChiefHomePageState();
}

class _ChiefHomePageState extends State<ChiefHomePage> {
  bool get _canViewOperations =>
      widget.currentUser.hasPermission(AppPermission.viewAllTechnicalWork);

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  @override
  void didUpdateWidget(covariant ChiefHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id) {
      _loadSummaries();
    }
  }

  void _loadSummaries() {
    if (!_canViewOperations) {
      return;
    }
    widget.technicalWorkController.load(widget.currentUser.id);
    if (widget.technicalWorkController.supportsCompletion &&
        widget.currentUser.hasPermission(
          AppPermission.reviewTechnicalWorkCompletion,
        )) {
      widget.completionController?.loadPending(widget.currentUser.id);
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
        animation: Listenable.merge([
          widget.technicalWorkController,
          if (widget.completionController != null) widget.completionController!,
        ]),
        builder: (context, child) => _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final cards = <Widget>[
      if (_canViewOperations && widget.onOpenOperations != null)
        ModuleCard(
          key: const ValueKey('chief-operations-module'),
          icon: Icons.monitor_heart_outlined,
          title: 'Operasyon Merkezi',
          description:
              'Teknik işleri, saha bildirimlerini, ekipleri ve onay süreçlerini yönetin.',
          statusLabel: 'Canlı',
          summaries: _operationSummaries,
          onTap: widget.onOpenOperations!,
        ),
      if (widget.currentUser.hasPermission(AppPermission.viewVehicleFleet) &&
          widget.onOpenVehicles != null)
        ModuleCard(
          key: const ValueKey('chief-vehicles-module'),
          icon: Icons.directions_car_filled_outlined,
          title: 'Araç Yönetimi',
          description:
              'Kurum ve sözleşmeli araçların güncel filo durumunu izleyin.',
          statusLabel: 'Canlı',
          onTap: widget.onOpenVehicles!,
        ),
      if (widget.currentUser.hasPermission(AppPermission.viewPersonnel) &&
          widget.onOpenPersonnel != null)
        ModuleCard(
          key: const ValueKey('chief-personnel-module'),
          icon: Icons.badge_outlined,
          title: 'Personel Yönetimi',
          description:
              'Personel süreçleri için hazırlanan yönetim modülüne geçin.',
          statusLabel: 'Hazırlanıyor',
          onTap: widget.onOpenPersonnel!,
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Şeflik Ana Sayfası',
                subtitle:
                    'Hoş geldin, ${widget.currentUser.fullName}. Yönetmek istediğin modülü seçebilirsin.',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (cards.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Erişebileceğiniz bir yönetim modülü bulunmuyor.',
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 650) {
                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < cards.length;
                            index++
                          ) ...[
                            cards[index],
                            if (index < cards.length - 1)
                              const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      );
                    }
                    final columnCount = constraints.maxWidth >= 1100 ? 3 : 2;
                    final cardHeight = constraints.maxWidth >= 1100
                        ? 340.0
                        : 400.0;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnCount,
                        crossAxisSpacing: AppSpacing.lg,
                        mainAxisSpacing: AppSpacing.lg,
                        mainAxisExtent: cardHeight,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) => cards[index],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<ModuleSummary> get _operationSummaries {
    if (widget.technicalWorkController.status !=
        TechnicalWorkLoadStatus.loaded) {
      return const [
        ModuleSummary(label: 'Operasyon verileri', value: 'Yükleniyor'),
      ];
    }
    return [
      ModuleSummary(
        label: 'Açık operasyon',
        value: widget.technicalWorkController.openWorkCount.toString(),
      ),
      ModuleSummary(
        label: 'Kritik olay',
        value: widget.technicalWorkController.criticalWorkCount.toString(),
      ),
      if (widget.currentUser.hasPermission(
        AppPermission.reviewTechnicalWorkCompletion,
      ))
        ModuleSummary(
          label: 'Tamamlama onayı',
          value: widget.technicalWorkController.supportsCompletion
              ? switch (widget.completionController?.queueStatus) {
                  TechnicalWorkCompletionStatus.loaded ||
                  TechnicalWorkCompletionStatus.success ||
                  TechnicalWorkCompletionStatus.submitting =>
                    widget.completionController!.pendingCount.toString(),
                  TechnicalWorkCompletionStatus.failure => 'Yüklenemedi',
                  _ => 'Yükleniyor',
                }
              : 'Hazırlanıyor',
        ),
    ];
  }
}
