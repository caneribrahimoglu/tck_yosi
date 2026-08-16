import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/submit_technical_work_completion_request.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_actor_access.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_participant_names.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_access_source.dart';
import 'package:tck_yosi/features/technical_operations/domain/repositories/technical_work_participant_name_source.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/pages/technical_work_completion_queue_page.dart';
import 'package:tck_yosi/features/technical_operations/presentation/pages/technical_work_detail_page.dart';
import 'package:tck_yosi/features/dashboard/pages/chief_dashboard_page.dart';
import 'package:tck_yosi/features/dashboard/widgets/role_dashboard_resolver.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/field_report_controller.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_controller.dart';
import 'package:tck_yosi/shared/widgets/app_text_field.dart';

void main() {
  testWidgets(
    'mühendis detaydan talep gönderir ve pending durumda formlar kapanır',
    (tester) async {
      final repository = _repository();
      final completionController = _completionController(repository);
      final detailController = TechnicalWorkDetailController(
        repository: repository,
        participantNameSource: const _NameSource(),
      );
      tester.view.physicalSize = const Size(400, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: TechnicalWorkDetailPage(
            workId: 'work-1',
            currentUser: _engineer,
            controller: detailController,
            completionController: completionController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final summaryField = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is AppTextField && widget.label == 'Tamamlama özeti',
        ),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(summaryField);
      await tester.enterText(summaryField, 'Armatürler yenilendi.');
      final submitButton = find.text('Tamamlanmak Üzere Gönder');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Tamamlama Onayı Bekliyor'), findsOneWidget);
      expect(find.text('Armatürler yenilendi.'), findsOneWidget);
      expect(find.text('Zeynep Demir'), findsWidgets);
      expect(find.text('Tamamlanmak Üzere Gönder'), findsNothing);
      expect(find.text('İlerleme Kaydı Ekle'), findsNothing);
      expect(find.textContaining('engineer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('şef kuyruğu isim ve zamanı gösterir, onayla boşalır', (
    tester,
  ) async {
    final repository = _repository();
    await repository.submitCompletionRequest(
      request: const SubmitTechnicalWorkCompletionRequest(
        workId: 'work-1',
        summary: 'Saha kontrolleri tamamlandı.',
      ),
      actorUserId: 'engineer',
    );
    final controller = _completionController(repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: TechnicalWorkCompletionQueuePage(
          currentUser: _chief,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aydınlatma işi'), findsOneWidget);
    expect(find.textContaining('Zeynep Demir'), findsOneWidget);
    expect(find.textContaining('16.08.2026 12:30'), findsOneWidget);
    expect(find.textContaining('engineer'), findsNothing);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla').last);
    await tester.pumpAndSettle();
    expect(find.text('Bekleyen iş tamamlama onayı yok.'), findsOneWidget);
  });

  testWidgets(
    'şef dashboard gerçek pending sayısını gösterir ve kuyruğu açar',
    (tester) async {
      final repository = _repository();
      await repository.submitCompletionRequest(
        request: const SubmitTechnicalWorkCompletionRequest(
          workId: 'work-1',
          summary: 'Tamamlandı.',
        ),
        actorUserId: 'engineer',
      );
      final completionController = _completionController(repository);
      await completionController.loadPending('chief');
      var queueOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ChiefDashboardPage(
            currentUser: _chief,
            onLogout: () async {},
            technicalWorkController: TechnicalWorkController(
              repository: repository,
              participantNameSource: const _NameSource(),
            ),
            onCreateFieldReport: () async {},
            onManageTeams: () async {},
            completionController: completionController,
            onOpenCompletionQueue: () async => queueOpened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('İş tamamlama onayı'),
        matching: find.byType(InkWell),
      );
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('1')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('İş tamamlama onayı'));
      await tester.tap(find.text('İş tamamlama onayı'));
      await tester.pump();
      expect(queueOpened, isTrue);
    },
  );

  testWidgets('Onay Kuyruğu hızlı aksiyonu gerçek pending kuyruğunu açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    await repository.submitCompletionRequest(
      request: const SubmitTechnicalWorkCompletionRequest(
        workId: 'work-1',
        summary: 'Hızlı aksiyon testi tamamlandı.',
      ),
      actorUserId: 'engineer',
    );
    final technicalController = TechnicalWorkController(
      repository: repository,
      participantNameSource: const _NameSource(),
    );
    final detailController = TechnicalWorkDetailController(
      repository: repository,
      participantNameSource: const _NameSource(),
    );
    final completionController = _completionController(repository);
    final fieldReportController = FieldReportController(repository: repository);
    final teamController = TeamController(
      repository: FakeTeamRepository(delay: Duration.zero),
      actorPermissions: _chief.permissions,
    );
    addTearDown(technicalController.dispose);
    addTearDown(detailController.dispose);
    addTearDown(completionController.dispose);
    addTearDown(fieldReportController.dispose);
    addTearDown(teamController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: RoleDashboardResolver(
          currentUser: _chief,
          onLogout: () async {},
          technicalWorkController: technicalController,
          technicalWorkDetailController: detailController,
          technicalWorkCompletionController: completionController,
          fieldReportController: fieldReportController,
          teamController: teamController,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Onay Kuyruğu'));
    await tester.tap(find.text('Onay Kuyruğu'));
    await tester.pumpAndSettle();

    expect(find.text('İş Tamamlama Onayları'), findsOneWidget);
    expect(find.text('Hızlı aksiyon testi tamamlandı.'), findsOneWidget);
    expect(find.textContaining('Zeynep Demir'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final approvalRow = find.ancestor(
      of: find.text('İş tamamlama onayı'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(of: approvalRow, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('şef ret nedeni girerek talebi reddeder', (tester) async {
    final repository = _repository();
    await repository.submitCompletionRequest(
      request: const SubmitTechnicalWorkCompletionRequest(
        workId: 'work-1',
        summary: 'Tamamlandı.',
      ),
      actorUserId: 'engineer',
    );
    final controller = _completionController(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: TechnicalWorkCompletionQueuePage(
          currentUser: _chief,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reddet'));
    await tester.pumpAndSettle();
    final reasonField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is AppTextField && widget.label == 'Ret nedeni',
      ),
      matching: find.byType(EditableText),
    );
    await tester.enterText(reasonField, 'Son ölçüm eksik.');
    await tester.tap(find.text('Reddet').last);
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen iş tamamlama onayı yok.'), findsOneWidget);
    final work = await repository.getWorkById(
      workId: 'work-1',
      actorUserId: 'engineer',
    );
    expect(work.status, TechnicalWorkStatus.inProgress);
  });
}

const _engineer = AppUser(
  id: 'engineer',
  fullName: 'Zeynep Demir',
  username: 'muhendis',
  role: UserRole.engineer,
  permissions: {AppPermission.requestTechnicalWorkCompletion},
);

const _chief = AppUser(
  id: 'chief',
  fullName: 'Ahmet Dulkadir',
  username: 'sef',
  role: UserRole.chief,
  permissions: {
    AppPermission.reviewTechnicalWorkCompletion,
    AppPermission.viewAllTechnicalWork,
  },
);

FakeTechnicalWorkRepository _repository() {
  return FakeTechnicalWorkRepository(
    works: [
      TechnicalWork(
        id: 'work-1',
        title: 'Aydınlatma işi',
        description: 'Armatür değişimi yapıldı.',
        location: 'D-100 / Km 12+000',
        category: TechnicalWorkCategory.lighting,
        priority: TechnicalWorkPriority.high,
        status: TechnicalWorkStatus.inProgress,
        createdByUserId: 'chief',
        assignedToUserId: 'engineer',
        createdAt: DateTime(2026, 8, 15, 9),
        startedByUserId: 'engineer',
        startedAt: DateTime(2026, 8, 15, 10),
      ),
    ],
    delay: Duration.zero,
    now: () => DateTime(2026, 8, 16, 12, 30),
    technicalWorkAccessSource: const _AccessSource(),
  );
}

TechnicalWorkCompletionController _completionController(
  FakeTechnicalWorkRepository repository,
) {
  return TechnicalWorkCompletionController(
    repository: repository,
    participantNameSource: const _NameSource(),
  );
}

class _AccessSource implements TechnicalWorkAccessSource {
  const _AccessSource();

  @override
  Future<TechnicalWorkActorAccess> getActorAccess(String userId) async {
    if (userId == 'chief') {
      return const TechnicalWorkActorAccess(
        activeTeamIds: {},
        canStartTechnicalWork: false,
        canViewAllTechnicalWork: true,
        canReviewTechnicalWorkCompletion: true,
      );
    }
    return const TechnicalWorkActorAccess(
      activeTeamIds: {},
      canStartTechnicalWork: false,
      canAddTechnicalWorkProgress: true,
      canRequestTechnicalWorkCompletion: true,
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
