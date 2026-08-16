import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_loading.dart';
import '../../../dashboard/widgets/role_dashboard_resolver.dart';
import '../../../technical_operations/presentation/controllers/field_report_controller.dart';
import '../../../technical_operations/presentation/controllers/technical_work_controller.dart';
import '../../../technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import '../../../technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import '../../../teams/presentation/controllers/team_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_status.dart';
import '../pages/login_page.dart';

class AuthGate extends StatefulWidget {
  final AuthController authController;
  final TechnicalWorkController technicalWorkController;
  final TechnicalWorkDetailController technicalWorkDetailController;
  final TechnicalWorkCompletionController technicalWorkCompletionController;
  final FieldReportController fieldReportController;
  final TeamController teamController;

  const AuthGate({
    super.key,
    required this.authController,
    required this.technicalWorkController,
    required this.technicalWorkDetailController,
    required this.technicalWorkCompletionController,
    required this.fieldReportController,
    required this.teamController,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();

    widget.authController.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, child) {
        final currentUser = widget.authController.currentUser;
        if (currentUser != null) {
          widget.teamController.updateActorPermissions(currentUser.permissions);
        }
        return switch (widget.authController.status) {
          AuthStatus.initial || AuthStatus.checkingSession => const Scaffold(
            body: AppLoading(message: 'Oturum kontrol ediliyor...'),
          ),
          AuthStatus.unauthenticated || AuthStatus.authenticating => LoginPage(
            authController: widget.authController,
          ),
          AuthStatus.authenticated => RoleDashboardResolver(
            currentUser: widget.authController.currentUser!,
            onLogout: widget.authController.logout,
            technicalWorkController: widget.technicalWorkController,
            technicalWorkDetailController: widget.technicalWorkDetailController,
            technicalWorkCompletionController:
                widget.technicalWorkCompletionController,
            fieldReportController: widget.fieldReportController,
            teamController: widget.teamController,
          ),
        };
      },
    );
  }
}
