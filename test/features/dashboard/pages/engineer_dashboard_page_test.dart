import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/dashboard/pages/engineer_dashboard_page.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_technical_work_access_adapter.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/errors/technical_work_start_exception.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/shared/widgets/app_button.dart';

void main() {
  const engineer = AppUser(
    id: 'user-engineer-001',
    fullName: 'Zeynep Demir',
    username: 'muhendis',
    role: UserRole.engineer,
    permissions: {AppPermission.startTechnicalWork},
  );

  testWidgets(
    'ekip işi görünür ve başlatılınca kart aynı state ile güncellenir',
    (tester) async {
      final repository = _createRepository(
        delay: const Duration(milliseconds: 30),
      );
      final controller = TechnicalWorkController(repository: repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: EngineerDashboardPage(
            currentUser: engineer,
            onLogout: () async {},
            technicalWorkController: controller,
            onCreateFieldReport: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teknik Ekibe atanan iş'), findsOneWidget);
      expect(find.text('İşi Başlat'), findsOneWidget);

      await tester.ensureVisible(find.text('İşi Başlat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İşi Başlat'));
      await tester.pump();

      expect(find.text('Başlatılıyor...'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(
              find.widgetWithText(AppButton, 'Başlatılıyor...'),
            )
            .onPressed,
        isNull,
      );

      await tester.pumpAndSettle();

      expect(find.text('Devam Ediyor'), findsOneWidget);
      expect(find.text('İşi Başlat'), findsNothing);
      expect(find.textContaining('Başlatan: Zeynep Demir'), findsOneWidget);
      expect(controller.inProgressWorkCount, 1);
    },
  );

  testWidgets('zaten başlatılmış uyarısı altı saniye gösterilir', (
    tester,
  ) async {
    final accessSource = _createAccessSource();
    final controller = TechnicalWorkController(
      repository: _AlreadyStartedRepository(
        works: [_teamWork],
        technicalWorkAccessSource: accessSource,
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: EngineerDashboardPage(
          currentUser: engineer,
          onLogout: () async {},
          technicalWorkController: controller,
          onCreateFieldReport: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('İşi Başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşi Başlat'));
    await tester.pump();
    await tester.pump();

    expect(find.text('İş zaten başlatıldı.'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 6),
    );
  });
}

final _teamWork = TechnicalWork(
  id: 'work-team-ui',
  title: 'Teknik Ekibe atanan iş',
  description: 'Ekip üyesi tarafından başlatılacak.',
  location: 'D-100 / Km 42+000',
  category: TechnicalWorkCategory.roadSurface,
  priority: TechnicalWorkPriority.high,
  status: TechnicalWorkStatus.assigned,
  createdByUserId: 'user-chief-001',
  assignedToTeamId: 'team-technical',
  createdAt: DateTime(2026, 8, 16),
);

TechnicalWorkAccessSource _createAccessSource() {
  return TeamTechnicalWorkAccessAdapter(
    teamRepository: FakeTeamRepository(delay: Duration.zero),
    userDirectory: FakeAuthService(),
  );
}

FakeTechnicalWorkRepository _createRepository({
  Duration delay = Duration.zero,
}) {
  return FakeTechnicalWorkRepository(
    works: [_teamWork],
    delay: delay,
    technicalWorkAccessSource: _createAccessSource(),
    now: () => DateTime(2026, 8, 16, 12, 5),
  );
}

class _AlreadyStartedRepository extends FakeTechnicalWorkRepository {
  _AlreadyStartedRepository({
    required super.works,
    required super.technicalWorkAccessSource,
  }) : super(delay: Duration.zero);

  @override
  Future<TechnicalWork> startWork({
    required String workId,
    required String actorUserId,
  }) {
    throw const TechnicalWorkAlreadyStartedException();
  }
}
