import 'package:flutter/material.dart';

import '../../auth/domain/enums/user_role.dart';
import '../../auth/domain/models/app_user.dart';
import '../pages/dashboard_page.dart';
import '../pages/driver_dashboard_page.dart';

class RoleDashboardResolver extends StatelessWidget {
  final AppUser currentUser;
  final Future<void> Function() onLogout;

  const RoleDashboardResolver({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return switch (currentUser.role) {
      UserRole.driver => DriverDashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
      ),

      UserRole.cleaningStaff ||
      UserRole.technician ||
      UserRole.chief ||
      UserRole.engineer ||
      UserRole.director ||
      UserRole.admin => DashboardPage(
        currentUser: currentUser,
        onLogout: onLogout,
      ),
    };
  }
}
