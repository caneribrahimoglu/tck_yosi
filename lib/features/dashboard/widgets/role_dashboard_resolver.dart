import 'package:flutter/material.dart';

import '../../auth/domain/enums/user_role.dart';
import '../../auth/domain/models/app_user.dart';
import '../../technical_operations/domain/models/technical_work.dart';
import '../../technical_operations/presentation/controllers/field_report_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import '../../technical_operations/presentation/pages/technical_work_detail_page.dart';
import '../../technical_operations/presentation/pages/technical_work_completion_queue_page.dart';
import '../../technical_operations/presentation/pages/field_report_page.dart';
import '../../teams/presentation/controllers/team_controller.dart';
import '../../teams/presentation/pages/team_management_page.dart';
import '../pages/chief_dashboard_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/driver_dashboard_page.dart';
import '../pages/engineer_dashboard_page.dart';

class RoleDashboardResolver extends StatelessWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final TechnicalWorkController technicalWorkController;
  final TechnicalWorkDetailController? technicalWorkDetailController;
  final TechnicalWorkCompletionController? technicalWorkCompletionController;
  final FieldReportController fieldReportController;
  final TeamController teamController;

  const RoleDashboardResolver({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.technicalWorkController,
    this.technicalWorkDetailController,
    this.technicalWorkCompletionController,
    required this.fieldReportController,
    required this.teamController,
  });

  Future<void> _openFieldReport(BuildContext context) async {
    final createdWork = await Navigator.of(context).push<TechnicalWork>(
      MaterialPageRoute(
        builder: (context) {
          return FieldReportPage(
            controller: fieldReportController,
            currentUserId: currentUser.id,
          );
        },
      ),
    );

    if (createdWork == null) {
      return;
    }

    await technicalWorkController.load(currentUser.id);
  }

  Future<void> _openTeamManagement(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TeamManagementPage(controller: teamController),
      ),
    );
    await technicalWorkController.load(currentUser.id);
  }

  Future<void> _openTechnicalWorkDetail(
    BuildContext context,
    TechnicalWork work,
  ) async {
    final detailController = technicalWorkDetailController;
    if (detailController == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TechnicalWorkDetailPage(
          workId: work.id,
          currentUser: currentUser,
          controller: detailController,
          completionController: technicalWorkCompletionController,
        ),
      ),
    );
    await technicalWorkController.load(currentUser.id);
    if (currentUser.role == UserRole.chief) {
      await technicalWorkCompletionController?.loadPending(currentUser.id);
    }
  }

  Future<void> _openCompletionQueue(BuildContext context) async {
    final controller = technicalWorkCompletionController;
    if (controller == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TechnicalWorkCompletionQueuePage(
          currentUser: currentUser,
          controller: controller,
          onViewDetail: technicalWorkDetailController == null
              ? null
              : (work) => _openTechnicalWorkDetail(context, work),
        ),
      ),
    );
    await technicalWorkController.load(currentUser.id);
    await controller.loadPending(currentUser.id);
  }

  @override
  Widget build(BuildContext context) {
    return switch (currentUser.role) {
      UserRole.driver => DriverDashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
        onCreateFieldReport: () => _openFieldReport(context),
      ),
      UserRole.engineer => EngineerDashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
        technicalWorkController: technicalWorkController,
        onCreateFieldReport: () => _openFieldReport(context),
        onViewDetail: technicalWorkDetailController == null
            ? null
            : (work) => _openTechnicalWorkDetail(context, work),
      ),
      UserRole.chief => ChiefDashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
        technicalWorkController: technicalWorkController,
        onCreateFieldReport: () => _openFieldReport(context),
        onManageTeams: () => _openTeamManagement(context),
        onViewDetail: technicalWorkDetailController == null
            ? null
            : (work) => _openTechnicalWorkDetail(context, work),
        completionController: technicalWorkCompletionController,
        onOpenCompletionQueue: technicalWorkCompletionController == null
            ? null
            : () => _openCompletionQueue(context),
      ),
      UserRole.cleaningStaff ||
      UserRole.technician ||
      UserRole.director ||
      UserRole.admin => DashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
      ),
    };
  }
}
