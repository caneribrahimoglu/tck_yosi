import 'package:flutter/material.dart';

import '../../auth/domain/enums/user_role.dart';
import '../../auth/domain/enums/app_permission.dart';
import '../../auth/domain/models/app_user.dart';
import '../../technical_operations/domain/models/technical_work.dart';
import '../../technical_operations/presentation/controllers/field_report_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import '../../technical_operations/presentation/controllers/technical_work_hold_controller.dart';
import '../../technical_operations/presentation/pages/technical_work_detail_page.dart';
import '../../technical_operations/presentation/pages/technical_work_completion_queue_page.dart';
import '../../technical_operations/presentation/pages/field_report_page.dart';
import '../../teams/presentation/controllers/team_controller.dart';
import '../../teams/presentation/pages/team_management_page.dart';
import '../../vehicles/presentation/pages/vehicle_module_page.dart';
import '../../vehicles/domain/models/vehicle.dart';
import '../../vehicles/presentation/pages/vehicle_detail_page.dart';
import '../../vehicles/presentation/pages/create_vehicle_page.dart';
import '../../vehicles/presentation/pages/vehicle_assignment_page.dart';
import '../../vehicles/presentation/pages/vehicle_handover_page.dart';
import '../../vehicles/presentation/pages/create_vehicle_record_page.dart';
import '../../vehicles/presentation/pages/vehicle_fault_review_queue_page.dart';
import '../../vehicles/domain/enums/vehicle_record_type.dart';
import '../../vehicles/presentation/controllers/vehicle_controller.dart';
import '../../vehicles/presentation/controllers/vehicle_detail_controller.dart';
import '../../personnel/presentation/pages/personnel_module_page.dart';
import '../../users/presentation/user_management_controller.dart';
import '../../users/presentation/user_management_page.dart';
import '../pages/chief_home_page.dart';
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
  final TechnicalWorkHoldController? technicalWorkHoldController;
  final FieldReportController fieldReportController;
  final TeamController teamController;
  final VehicleController vehicleController;
  final VehicleDetailController? vehicleDetailController;
  final UserManagementController? userManagementController;

  const RoleDashboardResolver({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.technicalWorkController,
    this.technicalWorkDetailController,
    this.technicalWorkCompletionController,
    this.technicalWorkHoldController,
    required this.fieldReportController,
    required this.teamController,
    required this.vehicleController,
    this.vehicleDetailController,
    this.userManagementController,
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

    if (createdWork == null || !context.mounted) {
      return;
    }

    await technicalWorkController.load(currentUser.id);
  }

  Future<void> _openTeamManagement(BuildContext context) async {
    if (!currentUser.hasPermission(AppPermission.manageTeamPermissions)) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TeamManagementPage(controller: teamController),
      ),
    );
    if (!context.mounted) {
      return;
    }
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
          holdController: technicalWorkHoldController,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    await technicalWorkController.load(currentUser.id);
    if (currentUser.role == UserRole.chief &&
        technicalWorkController.supportsCompletion &&
        currentUser.hasPermission(
          AppPermission.reviewTechnicalWorkCompletion,
        )) {
      await technicalWorkCompletionController?.loadPending(currentUser.id);
    }
  }

  Future<void> _openCompletionQueue(BuildContext context) async {
    final controller = technicalWorkCompletionController;
    if (controller == null ||
        !technicalWorkController.supportsCompletion ||
        !currentUser.hasPermission(
          AppPermission.reviewTechnicalWorkCompletion,
        )) {
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
    if (!context.mounted) {
      return;
    }
    await technicalWorkController.load(currentUser.id);
    await controller.loadPending(currentUser.id);
  }

  Future<void> _openChiefOperations(BuildContext context) async {
    if (!currentUser.hasPermission(AppPermission.viewAllTechnicalWork)) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (operationsContext) => ChiefDashboardPage(
          currentUser: currentUser,
          onLogout: onLogout,
          technicalWorkController: technicalWorkController,
          onCreateFieldReport: () => _openFieldReport(operationsContext),
          onManageTeams: () => _openTeamManagement(operationsContext),
          onViewDetail: technicalWorkDetailController == null
              ? null
              : (work) => _openTechnicalWorkDetail(operationsContext, work),
          completionController: technicalWorkCompletionController,
          onOpenCompletionQueue: technicalWorkCompletionController == null
              ? null
              : () => _openCompletionQueue(operationsContext),
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    await technicalWorkController.load(currentUser.id);
    if (technicalWorkController.supportsCompletion &&
        currentUser.hasPermission(
          AppPermission.reviewTechnicalWorkCompletion,
        )) {
      await technicalWorkCompletionController?.loadPending(currentUser.id);
    }
  }

  Future<void> _openVehicleModule(BuildContext context) async {
    if (!currentUser.hasPermission(AppPermission.viewVehicleFleet)) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => VehicleModulePage(
          currentUser: currentUser,
          onLogout: onLogout,
          controller: vehicleController,
          onViewVehicle: vehicleDetailController == null
              ? null
              : (vehicle) => _openVehicleDetail(context, vehicle.id),
          onAddVehicle:
              currentUser.hasPermission(AppPermission.manageVehicleFleet)
              ? () => _openCreateVehicle(context)
              : null,
          onOpenFaultReviews:
              currentUser.hasPermission(AppPermission.reviewVehicleFaults)
              ? () => _openVehicleFaultReviews(context)
              : null,
        ),
      ),
    );
  }

  Future<void> _openCreateVehicle(BuildContext context) async {
    if (!currentUser.hasPermission(AppPermission.manageVehicleFleet)) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CreateVehiclePage(controller: vehicleController),
      ),
    );
  }

  Future<void> _openVehicleFaultReviews(BuildContext context) async {
    if (!currentUser.hasPermission(AppPermission.reviewVehicleFaults)) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => VehicleFaultReviewQueuePage(
          currentUser: currentUser,
          controller: vehicleController,
        ),
      ),
    );
    if (context.mounted) {
      await vehicleController.load();
    }
  }

  Future<void> _openVehicleDetail(
    BuildContext context,
    String vehicleId,
  ) async {
    final controller = vehicleDetailController;
    if (controller == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => VehicleDetailPage(
          vehicleId: vehicleId,
          currentUser: currentUser,
          onLogout: onLogout,
          controller: controller,
          onEditVehicle:
              currentUser.hasPermission(AppPermission.manageVehicleFleet)
              ? (vehicle) => _openEditVehicle(context, vehicle)
              : null,
          onManageAssignment:
              currentUser.hasPermission(AppPermission.manageVehicleFleet)
              ? (vehicle) => _openVehicleAssignment(context, vehicle)
              : null,
        ),
      ),
    );
  }

  Future<void> _openEditVehicle(BuildContext context, Vehicle vehicle) async {
    if (!currentUser.hasPermission(AppPermission.manageVehicleFleet)) {
      return;
    }
    final updatedVehicle = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(
        builder: (context) => CreateVehiclePage.edit(
          controller: vehicleController,
          vehicle: vehicle,
        ),
      ),
    );
    if (updatedVehicle == null || !context.mounted) {
      return;
    }
    await vehicleDetailController?.load(updatedVehicle.id);
  }

  Future<void> _openVehicleAssignment(
    BuildContext context,
    Vehicle vehicle,
  ) async {
    if (!currentUser.hasPermission(AppPermission.manageVehicleFleet)) {
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VehicleAssignmentPage(
          vehicle: vehicle,
          currentAssignment: vehicleDetailController?.currentAssignment,
          controller: vehicleController,
        ),
      ),
    );
    if (changed == true && context.mounted) {
      await vehicleDetailController?.load(vehicle.id);
    }
  }

  Future<void> _openPersonnelModule(BuildContext context) async {
    if (!currentUser.hasPermission(AppPermission.viewPersonnel)) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            userManagementController != null &&
                currentUser.hasPermission(AppPermission.manageUsers)
            ? UserManagementPage(
                currentUser: currentUser,
                onLogout: onLogout,
                controller: userManagementController!,
              )
            : PersonnelModulePage(currentUser: currentUser, onLogout: onLogout),
      ),
    );
  }

  Future<void> _openVehicleHandover(
    BuildContext context,
    VehicleHandoverType type,
  ) async {
    final vehicle = vehicleController.assignedVehicle;
    if (vehicle == null) {
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VehicleHandoverPage(
          type: type,
          vehicle: vehicle,
          currentUser: currentUser,
          controller: vehicleController,
        ),
      ),
    );
  }

  Future<void> _openVehicleRecord(
    BuildContext context,
    VehicleRecordType type,
  ) async {
    final vehicle = vehicleController.assignedVehicle;
    if (vehicle == null || vehicleController.currentUsageSession == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CreateVehicleRecordPage(
          type: type,
          vehicle: vehicle,
          currentUser: currentUser,
          controller: vehicleController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (currentUser.role) {
      UserRole.driver => DriverDashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
        onCreateFieldReport: () => _openFieldReport(context),
        vehicleController: vehicleController,
        onReceiveVehicle: () =>
            _openVehicleHandover(context, VehicleHandoverType.receive),
        onReturnVehicle: () =>
            _openVehicleHandover(context, VehicleHandoverType.returnVehicle),
        onCreateFaultRecord: () =>
            _openVehicleRecord(context, VehicleRecordType.fault),
        onCreateMaintenanceRecord: () =>
            _openVehicleRecord(context, VehicleRecordType.maintenance),
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
      UserRole.chief => ChiefHomePage(
        currentUser: currentUser,
        onLogout: onLogout,
        technicalWorkController: technicalWorkController,
        completionController: technicalWorkCompletionController,
        onOpenOperations:
            currentUser.hasPermission(AppPermission.viewAllTechnicalWork)
            ? () => _openChiefOperations(context)
            : null,
        onOpenVehicles:
            currentUser.hasPermission(AppPermission.viewVehicleFleet)
            ? () => _openVehicleModule(context)
            : null,
        onOpenPersonnel: currentUser.hasPermission(AppPermission.viewPersonnel)
            ? () => _openPersonnelModule(context)
            : null,
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
