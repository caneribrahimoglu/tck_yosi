import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/data/services/fake_auth_service.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/auth/domain/enums/user_role.dart';
import 'package:tck_yosi/features/auth/domain/models/app_user.dart';
import 'package:tck_yosi/features/teams/data/adapters/team_technical_work_access_adapter.dart';
import 'package:tck_yosi/features/teams/data/adapters/technical_work_participant_name_adapter.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_category.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_priority.dart';
import 'package:tck_yosi/features/technical_operations/domain/enums/technical_work_status.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work.dart';
import 'package:tck_yosi/features/technical_operations/domain/models/technical_work_progress_note.dart';
import 'package:tck_yosi/features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import 'package:tck_yosi/features/technical_operations/presentation/pages/technical_work_detail_page.dart';

void main() {
  testWidgets(
    'şef detay metadata ve notları salt okunur görür, raw ID görmez',
    (tester) async {
      final fixture = _DetailFixture();
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: TechnicalWorkDetailPage(
            workId: _work.id,
            currentUser: _chief,
            controller: fixture.controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kritik aydınlatma işi'), findsOneWidget);
      expect(find.text('Aydınlatma'), findsOneWidget);
      expect(find.text('Teknik Ekip'), findsOneWidget);
      expect(find.text('Ahmet Dulkadir'), findsOneWidget);
      expect(find.text('Zeynep Demir'), findsWidgets);
      expect(find.text('16.08.2026 14:05'), findsOneWidget);
      expect(find.text('İlk saha kontrolü tamamlandı.'), findsOneWidget);
      expect(find.text('İlerleme Kaydı Ekle'), findsNothing);
      expect(find.textContaining('team-technical'), findsNothing);
      expect(find.textContaining('user-engineer-001'), findsNothing);
    },
  );

  testWidgets('atanmış mühendis dar ekranda ilerleme notu ekler', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _DetailFixture(
      progressNotes: const [],
      delay: const Duration(milliseconds: 20),
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: TechnicalWorkDetailPage(
          workId: _work.id,
          currentUser: _engineer,
          controller: fixture.controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Henüz ilerleme kaydı yok.'), findsOneWidget);
    await tester.ensureVisible(find.text('İlerleme Kaydı Ekle'));
    await tester.enterText(
      find.byType(TextFormField),
      'Arızalı armatür değiştirildi.',
    );
    await tester.tap(find.text('İlerleme Kaydı Ekle'));
    await tester.pump();

    expect(find.text('Kaydediliyor...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump();

    expect(find.text('Arızalı armatür değiştirildi.'), findsOneWidget);
    expect(find.text('İlerleme kaydı eklendi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DetailFixture {
  late final FakeTeamRepository teamRepository;
  late final FakeTechnicalWorkRepository repository;
  late final TechnicalWorkDetailController controller;

  _DetailFixture({
    List<TechnicalWorkProgressNote>? progressNotes,
    Duration delay = Duration.zero,
  }) {
    final authService = FakeAuthService();
    teamRepository = FakeTeamRepository(delay: Duration.zero);
    repository = FakeTechnicalWorkRepository(
      works: [_work],
      progressNotes: progressNotes ?? [_initialNote],
      delay: delay,
      now: () => DateTime(2026, 8, 17, 9, 30),
      technicalWorkAccessSource: TeamTechnicalWorkAccessAdapter(
        teamRepository: teamRepository,
        userDirectory: authService,
      ),
    );
    controller = TechnicalWorkDetailController(
      repository: repository,
      participantNameSource: TechnicalWorkParticipantNameAdapter(
        teamRepository: teamRepository,
        userDirectory: authService,
      ),
    );
  }

  void dispose() => controller.dispose();
}

const _chief = AppUser(
  id: 'user-chief-001',
  fullName: 'Ahmet Dulkadir',
  username: 'sef',
  role: UserRole.chief,
  permissions: {
    AppPermission.viewReports,
    AppPermission.addTechnicalWorkProgress,
  },
);

const _engineer = AppUser(
  id: 'user-engineer-001',
  fullName: 'Zeynep Demir',
  username: 'muhendis',
  role: UserRole.engineer,
  permissions: {AppPermission.addTechnicalWorkProgress},
);

final _work = TechnicalWork(
  id: 'work-detail-widget',
  title: 'Kritik aydınlatma işi',
  description: 'Aydınlatma hattındaki arıza giderilecek.',
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

final _initialNote = TechnicalWorkProgressNote(
  id: 'progress-initial',
  workId: 'work-detail-widget',
  authorUserId: 'user-engineer-001',
  content: 'İlk saha kontrolü tamamlandı.',
  createdAt: DateTime(2026, 8, 16, 15),
);
