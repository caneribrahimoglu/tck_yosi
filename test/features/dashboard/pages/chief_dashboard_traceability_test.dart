import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/dashboard/pages/chief_dashboard_page.dart';
import 'package:tck_yosi/features/teams/data/adapters/technical_work_participant_name_adapter.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';

void main() {
  testWidgets(
    'şef iş kartı ve son operasyonlarda atama ve başlangıç adlarını görür',
    (tester) async {
      final teamRepository = FakeTeamRepository(delay: Duration.zero);
      final controller = TechnicalWorkController(
        repository: FakeTechnicalWorkRepository(
          works: [_startedTeamWork, _directlyAssignedWork],
          delay: Duration.zero,
        ),
        participantNameSource: TechnicalWorkParticipantNameAdapter(
          teamRepository: teamRepository,
          userDirectory: FakeAuthService(),
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ChiefDashboardPage(
            currentUser: _chief,
            onLogout: () async {},
            technicalWorkController: controller,
            onCreateFieldReport: () async {},
            onManageTeams: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atanan: Teknik Ekip'), findsNWidgets(2));
      expect(find.text('Atanan: Zeynep Demir'), findsNWidgets(2));
      expect(find.text('Başlatan: Zeynep Demir'), findsNWidgets(2));
      expect(find.text('Başlangıç: 16.08.2026 14:05'), findsNWidgets(2));
      expect(find.textContaining('team-technical'), findsNothing);
      expect(find.textContaining('user-engineer-001'), findsNothing);
    },
  );
}

const _chief = AppUser(
  id: 'user-chief-001',
  fullName: 'Ahmet Dulkadir',
  username: 'sef',
  role: UserRole.chief,
  permissions: {AppPermission.assignTechnicalWork, AppPermission.viewReports},
);

final _startedTeamWork = TechnicalWork(
  id: 'work-team-trace',
  title: 'Ekip operasyonu',
  description: 'Teknik ekip tarafından başlatılan kritik iş.',
  location: 'D-100 / Km 14+200',
  category: TechnicalWorkCategory.lighting,
  priority: TechnicalWorkPriority.critical,
  status: TechnicalWorkStatus.inProgress,
  createdByUserId: 'user-chief-001',
  assignedToTeamId: 'team-technical',
  startedByUserId: 'user-engineer-001',
  startedAt: DateTime(2026, 8, 16, 14, 5),
  createdAt: DateTime(2026, 8, 16, 13),
);

final _directlyAssignedWork = TechnicalWork(
  id: 'work-user-trace',
  title: 'Bireysel operasyon',
  description: 'Doğrudan mühendise atanan kritik iş.',
  location: 'D-100 / Km 18+300',
  category: TechnicalWorkCategory.trafficSign,
  priority: TechnicalWorkPriority.critical,
  status: TechnicalWorkStatus.assigned,
  createdByUserId: 'user-chief-001',
  assignedToUserId: 'user-engineer-001',
  createdAt: DateTime(2026, 8, 16, 12),
);
