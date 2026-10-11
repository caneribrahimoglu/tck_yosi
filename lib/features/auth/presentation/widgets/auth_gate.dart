import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_loading.dart';
import '../../../dashboard/widgets/role_dashboard_resolver.dart';
import '../../../technical_operations/presentation/controllers/field_report_controller.dart';
import '../../../technical_operations/presentation/controllers/technical_work_controller.dart';
import '../../../technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import '../../../technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import '../../../technical_operations/presentation/controllers/technical_work_hold_controller.dart';
import '../../../teams/presentation/controllers/team_controller.dart';
import '../../../vehicles/presentation/controllers/vehicle_controller.dart';
import '../../../vehicles/presentation/controllers/vehicle_detail_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_status.dart';
import '../pages/login_page.dart';
import '../pages/change_password_page.dart';
import '../../../users/presentation/user_management_controller.dart';

class AuthGate extends StatefulWidget {
  final AuthController authController;
  final TechnicalWorkController technicalWorkController;
  final TechnicalWorkDetailController technicalWorkDetailController;
  final TechnicalWorkCompletionController technicalWorkCompletionController;
  final TechnicalWorkHoldController technicalWorkHoldController;
  final FieldReportController fieldReportController;
  final TeamController teamController;
  final VehicleController vehicleController;
  final VehicleDetailController vehicleDetailController;
  final bool demoBusinessData;
  final UserManagementController? userManagementController;

  const AuthGate({
    super.key,
    required this.authController,
    required this.technicalWorkController,
    required this.technicalWorkDetailController,
    required this.technicalWorkCompletionController,
    required this.technicalWorkHoldController,
    required this.fieldReportController,
    required this.teamController,
    required this.vehicleController,
    required this.vehicleDetailController,
    this.demoBusinessData = false,
    this.userManagementController,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_handleAuthStateChanged);
    widget.authController.initialize();
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authController == widget.authController) {
      return;
    }
    oldWidget.authController.removeListener(_handleAuthStateChanged);
    widget.authController.addListener(_handleAuthStateChanged);
  }

  void _handleAuthStateChanged() {
    if (widget.authController.status != AuthStatus.unauthenticated) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.authController.status != AuthStatus.unauthenticated) {
        return;
      }
      Navigator.maybeOf(
        context,
        rootNavigator: true,
      )?.popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, child) {
        final currentUser = widget.authController.currentUser;
        widget.userManagementController?.updateActor(
          widget.authController.isAuthenticated ? currentUser : null,
        );
        widget.teamController.updateActorPermissions(
          widget.authController.isAuthenticated
              ? currentUser!.permissions
              : const {},
        );
        return switch (widget.authController.status) {
          AuthStatus.initial || AuthStatus.checkingSession => const Scaffold(
            body: AppLoading(message: 'Oturum kontrol ediliyor...'),
          ),
          AuthStatus.unauthenticated || AuthStatus.authenticating => LoginPage(
            authController: widget.authController,
          ),
          AuthStatus.passwordChangeRequired => ChangePasswordPage(
            controller: widget.authController,
          ),
          AuthStatus.authenticated => _authenticatedDashboard(),
        };
      },
    );
  }

  Widget _authenticatedDashboard() {
    final dashboard = RoleDashboardResolver(
      currentUser: widget.authController.currentUser!,
      onLogout: widget.authController.logout,
      technicalWorkController: widget.technicalWorkController,
      technicalWorkDetailController: widget.technicalWorkDetailController,
      technicalWorkCompletionController:
          widget.technicalWorkCompletionController,
      technicalWorkHoldController: widget.technicalWorkHoldController,
      fieldReportController: widget.fieldReportController,
      teamController: widget.teamController,
      vehicleController: widget.vehicleController,
      vehicleDetailController: widget.vehicleDetailController,
      userManagementController: widget.userManagementController,
    );
    if (!widget.demoBusinessData) return dashboard;
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Giriş, kullanıcılar ve ekipler gerçek sunucu kayıtlarıdır. İş ve araç verileri geçici demodur.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        Expanded(child: dashboard),
      ],
    );
  }
}
