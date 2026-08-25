import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/dashboard/widgets/role_dashboard_resolver.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_controller.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_actor_access.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_participant_names.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_participant_name_source.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_hold_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/pages/technical_work_detail_page.dart';
import 'package:tck_yosi/shared/widgets/app_text_field.dart';

void main() {
  testWidgets(
    'detayda hold nedeni doğrulanır, formlar kapanır ve resume görünür',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: TechnicalWorkDetailPage(
            workId: 'work-1',
            currentUser: _engineer,
            controller: fixture.detailController,
            completionController: fixture.completionController,
            holdController: fixture.holdController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Beklemeye Al'), findsOneWidget);
      expect(find.text('İlerleme Kaydı Ekle'), findsOneWidget);
      expect(find.text('Tamamlanmak Üzere Gönder'), findsOneWidget);

      await tester.ensureVisible(find.text('Beklemeye Al'));
      await tester.tap(find.text('Beklemeye Al'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beklemeye Al').last);
      await tester.pump();
      expect(find.text('Bekleme nedeni boş olamaz.'), findsOneWidget);
      final reasonField = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is AppTextField && widget.label == 'Bekleme nedeni',
        ),
        matching: find.byType(EditableText),
      );
      await tester.enterText(reasonField, 'Yedek parça bekleniyor.');
      await tester.tap(find.text('Beklemeye Al').last);
      await tester.pumpAndSettle();

      expect(find.text('Beklemeye Alındı'), findsOneWidget);
      expect(find.text('Neden: Yedek parça bekleniyor.'), findsOneWidget);
      expect(
        find.textContaining('Beklemeye alan: Zeynep Demir'),
        findsOneWidget,
      );
      expect(find.text('Çalışmaya Devam Et'), findsOneWidget);
      expect(find.text('İlerleme Kaydı Ekle'), findsNothing);
      expect(find.text('Tamamlanmak Üzere Gönder'), findsNothing);
      expect(find.textContaining('engineer'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Çalışmaya Devam Et'));
      await tester.tap(find.text('Çalışmaya Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Devam Ediyor'), findsOneWidget);
      expect(find.textContaining('Devam eden: Zeynep Demir'), findsOneWidget);
      expect(find.text('Beklemeye Al'), findsOneWidget);
    },
  );

  testWidgets('detaydan dönüşte mühendis dashboard durumu yenilenir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final technicalController = TechnicalWorkController(
      repository: fixture.repository,
      participantNameSource: const _NameSource(),
    );
    final fieldController = FieldReportController(
      repository: fixture.repository,
    );
    final teamController = TeamController(
      repository: FakeTeamRepository(delay: Duration.zero),
      actorPermissions: _engineer.permissions,
    );
    addTearDown(technicalController.dispose);
    addTearDown(fieldController.dispose);
    addTearDown(teamController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: RoleDashboardResolver(
          currentUser: _engineer,
          onLogout: () async {},
          technicalWorkController: technicalController,
          technicalWorkDetailController: fixture.detailController,
          technicalWorkCompletionController: fixture.completionController,
          technicalWorkHoldController: fixture.holdController,
          fieldReportController: fieldController,
          teamController: teamController,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detayı Gör'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Beklemeye Al'));
    await tester.tap(find.text('Beklemeye Al'));
    await tester.pumpAndSettle();
    final reasonField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Bekleme nedeni',
      ),
      matching: find.byType(EditableText),
    );
    await tester.enterText(reasonField, 'Hava koşulları.');
    await tester.tap(find.text('Beklemeye Al').last);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Beklemeye Alındı'), findsOneWidget);
    expect(
      technicalController.assignedWorks.single.status,
      TechnicalWorkStatus.onHold,
    );
  });
}

const _engineer = AppUser(
  id: 'engineer',
  fullName: 'Zeynep Demir',
  username: 'muhendis',
  role: UserRole.engineer,
  permissions: {
    AppPermission.addTechnicalWorkProgress,
    AppPermission.requestTechnicalWorkCompletion,
    AppPermission.pauseTechnicalWork,
    AppPermission.resumeTechnicalWork,
  },
);

class _Fixture {
  late final FakeTechnicalWorkRepository repository;
  late final TechnicalWorkDetailController detailController;
  late final TechnicalWorkCompletionController completionController;
  late final TechnicalWorkHoldController holdController;

  _Fixture() {
    var minute = 0;
    repository = FakeTechnicalWorkRepository(
      works: [
        TechnicalWork(
          id: 'work-1',
          title: 'Aydınlatma işi',
          description: 'Armatür değişimi',
          location: 'D-100',
          category: TechnicalWorkCategory.lighting,
          priority: TechnicalWorkPriority.high,
          status: TechnicalWorkStatus.inProgress,
          createdByUserId: 'chief',
          assignedToUserId: 'engineer',
          createdAt: DateTime(2026, 8, 25, 8),
          startedByUserId: 'engineer',
          startedAt: DateTime(2026, 8, 25, 9),
        ),
      ],
      delay: Duration.zero,
      now: () => DateTime(2026, 8, 25, 10, minute++),
      technicalWorkAccessSource: const _AccessSource(),
    );
    detailController = TechnicalWorkDetailController(
      repository: repository,
      participantNameSource: const _NameSource(),
    );
    completionController = TechnicalWorkCompletionController(
      repository: repository,
      participantNameSource: const _NameSource(),
    );
    holdController = TechnicalWorkHoldController(
      repository: repository,
      participantNameSource: const _NameSource(),
    );
  }

  void dispose() {
    detailController.dispose();
    completionController.dispose();
    holdController.dispose();
  }
}

class _AccessSource implements TechnicalWorkAccessSource {
  const _AccessSource();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    return const TechnicalWorkActorAccess(
      activeTeamIds: {},
      canStartTechnicalWork: false,
      canAddTechnicalWorkProgress: true,
      canRequestTechnicalWorkCompletion: true,
      canPauseTechnicalWork: true,
      canResumeTechnicalWork: true,
    );
  }
}

class _NameSource implements TechnicalWorkParticipantNameSource {
  const _NameSource();

  @override
  Future<TechnicalWorkParticipantNames> resolveNames({
    required Set<String> userIds,
    required Set<String> teamIds,
  }) async {
    return TechnicalWorkParticipantNames(
      userNames: {
        if (userIds.contains('engineer')) 'engineer': 'Zeynep Demir',
        if (userIds.contains('chief')) 'chief': 'Ahmet Dulkadir',
      },
      teamNames: const {},
    );
  }
}
