import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/dashboard/widgets/role_dashboard_resolver.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_technical_work_access_adapter.dart';
import 'package:tck_yosi/features/teams/data/adapters/technical_work_participant_name_adapter.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_controller.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';

void main() {
  for (final user in [_engineer, _chief]) {
    testWidgets('${user.role.name} dashboardundan teknik iş detayı açılır', (
      tester,
    ) async {
      final fixture = _NavigationFixture();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: RoleDashboardResolver(
            currentUser: user,
            onLogout: () async {},
            technicalWorkController: fixture.dashboardController,
            technicalWorkDetailController: fixture.detailController,
            fieldReportController: fixture.fieldReportController,
            teamController: fixture.teamController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final detailButton = find.text('Detayı Gör').first;
      await tester.ensureVisible(detailButton);
      await tester.pumpAndSettle();
      await tester.tap(detailButton);
      await tester.pumpAndSettle();

      expect(find.text('Teknik İş Detayı'), findsOneWidget);
      expect(find.text('Dashboard detay işi'), findsOneWidget);
    });
  }
}

class _NavigationFixture {
  late final FakeTechnicalWorkRepository repository;
  late final TechnicalWorkController dashboardController;
  late final TechnicalWorkDetailController detailController;
  late final FieldReportController fieldReportController;
  late final TeamController teamController;

  _NavigationFixture() {
    final authService = FakeAuthService();
    final teamRepository = FakeTeamRepository(delay: Duration.zero);
    final accessSource = TeamTechnicalWorkAccessAdapter(
      teamRepository: teamRepository,
      userDirectory: authService,
    );
    final nameSource = TechnicalWorkParticipantNameAdapter(
      teamRepository: teamRepository,
      userDirectory: authService,
    );
    repository = FakeTechnicalWorkRepository(
      works: [_work],
      delay: Duration.zero,
      technicalWorkAccessSource: accessSource,
    );
    dashboardController = TechnicalWorkController(
      repository: repository,
      participantNameSource: nameSource,
    );
    detailController = TechnicalWorkDetailController(
      repository: repository,
      participantNameSource: nameSource,
    );
    fieldReportController = FieldReportController(repository: repository);
    teamController = TeamController(
      repository: teamRepository,
      actorPermissions: _chief.permissions,
    );
  }

  void dispose() {
    dashboardController.dispose();
    detailController.dispose();
    fieldReportController.dispose();
    teamController.dispose();
  }
}

const _engineer = AppUser(
  id: 'user-engineer-001',
  fullName: 'Zeynep Demir',
  username: 'muhendis',
  role: UserRole.engineer,
  permissions: {
    AppPermission.viewReports,
    AppPermission.addTechnicalWorkProgress,
  },
);

const _chief = AppUser(
  id: 'user-chief-001',
  fullName: 'Ahmet Dulkadir',
  username: 'sef',
  role: UserRole.chief,
  permissions: {
    AppPermission.viewReports,
    AppPermission.assignTechnicalWork,
    AppPermission.manageTeamPermissions,
    AppPermission.addTechnicalWorkProgress,
  },
);

final _work = TechnicalWork(
  id: 'work-navigation',
  title: 'Dashboard detay işi',
  description: 'Dashboard üzerinden açılacak kritik iş.',
  location: 'D-100 / Km 20+000',
  category: TechnicalWorkCategory.lighting,
  priority: TechnicalWorkPriority.critical,
  status: TechnicalWorkStatus.inProgress,
  createdByUserId: 'user-chief-001',
  assignedToTeamId: 'team-technical',
  startedByUserId: 'user-engineer-001',
  startedAt: DateTime(2026, 8, 17, 10),
  createdAt: DateTime(2026, 8, 17, 9),
);
