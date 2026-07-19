import 'package:flutter/material.dart';

import '../../auth/domain/enums/user_role.dart';
import '../../auth/domain/models/app_user.dart';
import '../../technical_operations/presentation/controllers/technical_work_controller.dart';
import '../pages/chief_dashboard_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/driver_dashboard_page.dart';
import '../pages/engineer_dashboard_page.dart';

class RoleDashboardResolver extends StatelessWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final TechnicalWorkController technicalWorkController;

  const RoleDashboardResolver({
    super.key,
    required this.currentUser,
    required this.onLogout,
    required this.technicalWorkController,
  });

  @override
  Widget build(BuildContext context) {
    return switch (currentUser.role) {
      UserRole.driver => DriverDashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
      ),
      UserRole.engineer => EngineerDashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
        technicalWorkController: technicalWorkController,
      ),
      UserRole.chief => ChiefDashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
        technicalWorkController: technicalWorkController,
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
