import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/enums/app_snackbar_type.dart';
import '../../../../core/enums/app_dialog_type.dart';
import '../../../../core/enums/app_status_type.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_status_chip.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../auth/domain/enums/app_permission.dart';
import '../../domain/models/team.dart';
import '../../domain/models/team_candidate.dart';
import '../controllers/team_controller.dart';
import '../controllers/team_load_status.dart';
import '../controllers/team_list_filter.dart';
import '../team_permission_presentation.dart';

class TeamManagementPage extends StatefulWidget {
  final TeamController controller;

  const TeamManagementPage({super.key, required this.controller});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ekip Yönetimi')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          return switch (widget.controller.status) {
            TeamLoadStatus.initial || TeamLoadStatus.loading =>
              const AppLoading(message: 'Ekipler yükleniyor...'),
            TeamLoadStatus.failure => _buildFailure(),
            TeamLoadStatus.loaded => _buildContent(),
          };
        },
      ),
    );
  }

  Widget _buildFailure() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(widget.controller.errorMessage ?? 'Ekipler yüklenemedi.'),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Tekrar Dene',
              icon: Icons.refresh_rounded,
              onPressed: widget.controller.load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final listPanel = _TeamListPanel(
      controller: widget.controller,
      onCreate: () => _openTeamDialog(),
    );
    final selectedTeam = widget.controller.selectedTeam;
    final detailPanel = selectedTeam == null
        ? const AppCard(child: Text('Yönetilecek bir ekip bulunmuyor.'))
        : _TeamDetailPanel(
            key: ValueKey(selectedTeam.id),
            controller: widget.controller,
            team: selectedTeam,
            onEdit: () => _openTeamDialog(team: selectedTeam),
            onArchive: () => _confirmArchive(selectedTeam),
            onRestore: () => _confirmRestore(selectedTeam),
            onResult: _showResult,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final header = AppPageHeader(
          title: 'Ekipler ve Üyelikler',
          subtitle:
              'Ekip bilgilerini, üyelikleri ve devredilebilir yetkileri yönetin.',
          actions: [
            AppButton.primary(
              label: 'Yeni Ekip',
              icon: Icons.group_add_outlined,
              onPressed: widget.controller.isProcessing
                  ? null
                  : () => _openTeamDialog(),
            ),
          ],
        );

        if (constraints.maxWidth >= 900) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 330, child: listPanel),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: SingleChildScrollView(child: detailPanel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            header,
            const SizedBox(height: AppSpacing.lg),
            listPanel,
            const SizedBox(height: AppSpacing.lg),
            detailPanel,
          ],
        );
      },
    );
  }

  Future<void> _openTeamDialog({Team? team}) async {
    final result = await showDialog<_TeamFormValue>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TeamFormDialog(team: team),
    );
    if (result == null) {
      return;
    }
    final succeeded = team == null
        ? await widget.controller.createTeam(
            name: result.name,
            description: result.description,
          )
        : await widget.controller.updateTeam(
            teamId: team.id,
            name: result.name,
            description: result.description,
          );
    if (mounted) {
      if (!succeeded &&
          team == null &&
          widget.controller.archivedNameConflict != null) {
        await _offerArchivedTeamRestore();
      } else {
        _showResult(succeeded);
      }
    }
  }

  void _showResult(bool succeeded) {
    AppSnackbar.show(
      context: context,
      type: succeeded ? AppSnackbarType.success : AppSnackbarType.error,
      message: succeeded
          ? widget.controller.successMessage ?? 'İşlem tamamlandı.'
          : widget.controller.errorMessage ?? 'İşlem tamamlanamadı.',
    );
  }

  Future<void> _confirmArchive(Team team) async {
    final confirmed = await AppDialog.show(
      context: context,
      type: AppDialogType.warning,
      title: 'Ekibi Sil',
      message:
          '${team.name} arşivlenecek. Ekip yeni atamalarda görünmeyecek; '
          'geçmiş operasyon kayıtları korunacak.',
      primaryButtonText: 'Ekibi Sil',
      secondaryButtonText: 'Vazgeç',
    );
    if (!confirmed) {
      return;
    }
    final succeeded = await widget.controller.archiveTeam(team.id);
    if (mounted) {
      _showResult(succeeded);
    }
  }

  Future<void> _offerArchivedTeamRestore() async {
    final conflict = widget.controller.archivedNameConflict;
    if (conflict == null) {
      return;
    }
    final confirmed = await AppDialog.show(
      context: context,
      type: AppDialogType.warning,
      title: 'Arşivlenmiş Ekip Bulundu',
      message:
          '${conflict.teamName} adında arşivlenmiş bir ekip var. Yeni ekip '
          'yerine bu ekibi arşivden geri getirmek ister misiniz?',
      primaryButtonText: 'Arşivden Geri Getir',
      secondaryButtonText: 'İptal',
    );
    if (!confirmed) {
      return;
    }
    final succeeded = await widget.controller.restoreTeam(conflict.teamId);
    if (mounted) {
      _showResult(succeeded);
    }
  }

  Future<void> _confirmRestore(Team team) async {
    final confirmed = await AppDialog.show(
      context: context,
      type: AppDialogType.info,
      title: 'Ekibi Geri Getir',
      message:
          '${team.name} pasif olarak geri yüklenecek. Üyeleri ve yetkileri '
          'kontrol ettikten sonra ekibi ayrıca aktifleştirmeniz gerekir.',
      primaryButtonText: 'Arşivden Geri Getir',
      secondaryButtonText: 'Vazgeç',
    );
    if (!confirmed) {
      return;
    }
    final succeeded = await widget.controller.restoreTeam(team.id);
    if (mounted) {
      _showResult(succeeded);
    }
  }
}

class _TeamListPanel extends StatelessWidget {
  final TeamController controller;
  final VoidCallback onCreate;

  const _TeamListPanel({required this.controller, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('Aktif / Pasif'),
              selected: controller.listFilter == TeamListFilter.active,
              onSelected: (_) =>
                  controller.setListFilter(TeamListFilter.active),
            ),
            ChoiceChip(
              label: const Text('Arşivlenmiş'),
              selected: controller.listFilter == TeamListFilter.archived,
              onSelected: (_) =>
                  controller.setListFilter(TeamListFilter.archived),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (controller.teams.isEmpty)
          AppCard(
            child: Column(
              children: [
                Text(
                  controller.listFilter == TeamListFilter.archived
                      ? 'Arşivlenmiş ekip bulunmuyor.'
                      : 'Henüz ekip oluşturulmadı.',
                ),
                if (controller.listFilter == TeamListFilter.active) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton.primary(
                    label: 'İlk Ekibi Oluştur',
                    onPressed: onCreate,
                  ),
                ],
              ],
            ),
          )
        else
          for (final team in controller.teams) ...[
            AppCard(
              onTap: () => controller.selectTeam(team.id),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${controller.membershipsFor(team.id).length} üye',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AppStatusChip(
                    label: team.isArchived
                        ? 'Arşivlenmiş'
                        : team.isActive
                        ? 'Aktif'
                        : 'Pasif',
                    type: team.isArchived
                        ? AppStatusType.warning
                        : team.isActive
                        ? AppStatusType.success
                        : AppStatusType.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _TeamDetailPanel extends StatefulWidget {
  final TeamController controller;
  final Team team;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final ValueChanged<bool> onResult;

  const _TeamDetailPanel({
    super.key,
    required this.controller,
    required this.team,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onResult,
  });

  @override
  State<_TeamDetailPanel> createState() => _TeamDetailPanelState();
}

class _TeamDetailPanelState extends State<_TeamDetailPanel> {
  late Set<AppPermission> _selectedPermissions;

  @override
  void initState() {
    super.initState();
    _selectedPermissions = Set.of(widget.team.permissions);
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.controller.selectedTeam ?? widget.team;
    final members = widget.controller.candidates
        .where(
          (candidate) => widget.controller.isMember(
            teamId: team.id,
            userId: candidate.userId,
          ),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    team.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final actions = Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: team.isArchived
                        ? [
                            AppButton.primary(
                              label: 'Arşivden Geri Getir',
                              icon: Icons.restore_rounded,
                              onPressed: widget.controller.isProcessing
                                  ? null
                                  : widget.onRestore,
                            ),
                          ]
                        : [
                            AppButton.secondary(
                              label: 'Düzenle',
                              icon: Icons.edit_outlined,
                              onPressed: widget.controller.isProcessing
                                  ? null
                                  : widget.onEdit,
                            ),
                            AppButton.danger(
                              label: 'Ekibi Sil',
                              icon: Icons.delete_outline_rounded,
                              onPressed: widget.controller.isProcessing
                                  ? null
                                  : widget.onArchive,
                            ),
                          ],
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: AppSpacing.md),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: AppSpacing.md),
                      actions,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                team.description.isEmpty
                    ? 'Açıklama eklenmemiş.'
                    : team.description,
              ),
              if (team.isArchived) ...[
                const SizedBox(height: AppSpacing.md),
                const AppStatusChip(
                  label: 'Arşivlenmiş',
                  type: AppStatusType.warning,
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ekip aktif'),
                  subtitle: const Text(
                    'Pasif ekiplerin yetkileri etkin yetki hesabına katılmaz.',
                  ),
                  value: team.isActive,
                  onChanged: widget.controller.isProcessing
                      ? null
                      : (value) async {
                          final result = await widget.controller.setTeamActive(
                            teamId: team.id,
                            isActive: value,
                          );
                          widget.onResult(result);
                        },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildMembersCard(context, team, members),
        const SizedBox(height: AppSpacing.lg),
        _buildPermissionsCard(context, team),
      ],
    );
  }

  Widget _buildMembersCard(
    BuildContext context,
    Team team,
    List<TeamCandidate> members,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Üyeler',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('${members.length} kullanıcı bu ekibin üyesi.'),
          const SizedBox(height: AppSpacing.lg),
          for (final candidate in widget.controller.candidates.where(
            (item) => item.isActive,
          ))
            CheckboxListTile(
              key: ValueKey('member-${team.id}-${candidate.userId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(candidate.fullName),
              subtitle: Text(candidate.roleLabel),
              value: widget.controller.isMember(
                teamId: team.id,
                userId: candidate.userId,
              ),
              onChanged: team.isArchived || widget.controller.isProcessing
                  ? null
                  : (selected) async {
                      final result = selected == true
                          ? await widget.controller.addMember(
                              teamId: team.id,
                              userId: candidate.userId,
                            )
                          : await widget.controller.removeMember(
                              teamId: team.id,
                              userId: candidate.userId,
                            );
                      widget.onResult(result);
                    },
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(BuildContext context, Team team) {
    final permissions = widget.controller.grantablePermissions.toList()
      ..sort((first, second) => first.index.compareTo(second.index));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ekip Yetkileri',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Yalnızca size devredilmiş ve ekip düzeyinde güvenli yetkiler gösterilir.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final permission in permissions)
                FilterChip(
                  label: Text(permission.teamLabel),
                  selected: _selectedPermissions.contains(permission),
                  onSelected: team.isArchived || widget.controller.isProcessing
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _selectedPermissions.add(permission);
                            } else {
                              _selectedPermissions.remove(permission);
                            }
                          });
                        },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: widget.controller.isProcessing
                ? 'Kaydediliyor...'
                : 'Yetkileri Kaydet',
            icon: Icons.security_outlined,
            onPressed: team.isArchived || widget.controller.isProcessing
                ? null
                : () async {
                    final result = await widget.controller.updatePermissions(
                      teamId: team.id,
                      permissions: _selectedPermissions,
                    );
                    widget.onResult(result);
                  },
          ),
        ],
      ),
    );
  }
}

class _TeamFormValue {
  final String name;
  final String description;

  const _TeamFormValue({required this.name, required this.description});
}

class _TeamFormDialog extends StatefulWidget {
  final Team? team;

  const _TeamFormDialog({this.team});

  @override
  State<_TeamFormDialog> createState() => _TeamFormDialogState();
}

class _TeamFormDialogState extends State<_TeamFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team?.name);
    _descriptionController = TextEditingController(
      text: widget.team?.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.team == null ? 'Yeni Ekip Oluştur' : 'Ekibi Düzenle'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Ekip adı',
                prefixIcon: Icons.groups_outlined,
                maxLength: 80,
                validator: (value) => value == null || value.trim().length < 3
                    ? 'En az 3 karakter girin.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descriptionController,
                label: 'Açıklama',
                prefixIcon: Icons.notes_outlined,
                minLines: 3,
                maxLines: 4,
                maxLength: 240,
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton.secondary(
          label: 'Vazgeç',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.team == null ? 'Ekibi Oluştur' : 'Kaydet',
          onPressed: () {
            if (_formKey.currentState?.validate() != true) {
              return;
            }
            Navigator.of(context).pop(
              _TeamFormValue(
                name: _nameController.text,
                description: _descriptionController.text,
              ),
            );
          },
        ),
      ],
    );
  }
}
