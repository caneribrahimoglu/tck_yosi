import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tck_yosi/features/auth/domain/enums/app_permission.dart';
import 'package:tck_yosi/features/teams/data/repositories/fake_team_repository.dart';
import 'package:tck_yosi/features/teams/presentation/controllers/team_controller.dart';
import 'package:tck_yosi/features/teams/presentation/pages/team_management_page.dart';

void main() {
  testWidgets('ekip oluşturma, üye ekleme ve yetki verme akışı çalışır', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = TeamController(
      repository: FakeTeamRepository(delay: Duration.zero),
      actorPermissions: const {
        AppPermission.createFieldReport,
        AppPermission.viewReports,
        AppPermission.manageTeamPermissions,
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: TeamManagementPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teknik Ekip'), findsWidgets);
    expect(find.text('Zeynep Demir'), findsOneWidget);
    expect(find.text('Kullanıcı yönetimi'), findsNothing);
    expect(find.text('Ekip yetkisi yönetimi'), findsNothing);

    await tester.tap(find.text('Yeni Ekip'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Gece Ekibi');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Gece saha operasyonları',
    );
    await tester.tap(find.text('Ekibi Oluştur'));
    await tester.pumpAndSettle();

    expect(find.text('Gece Ekibi'), findsWidgets);
    final team = controller.selectedTeam!;

    await tester.tap(find.byKey(ValueKey('member-${team.id}-user-driver-001')));
    await tester.pumpAndSettle();
    expect(
      controller.isMember(teamId: team.id, userId: 'user-driver-001'),
      isTrue,
    );

    await tester.tap(find.text('Saha bildirimi oluşturma'));
    await tester.tap(find.text('Yetkileri Kaydet'));
    await tester.pumpAndSettle();
    expect(controller.selectedTeam!.permissions, {
      AppPermission.createFieldReport,
    });

    await tester.tap(find.text('Ekibi Sil'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('geçmiş operasyon kayıtları korunacak'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ekibi Sil').last);
    await tester.pumpAndSettle();

    expect(controller.teams.any((item) => item.id == team.id), isFalse);

    await tester.tap(find.text('Arşivlenmiş'));
    await tester.pumpAndSettle();
    expect(find.text('Gece Ekibi'), findsWidgets);
    expect(find.text('Arşivden Geri Getir'), findsOneWidget);
    await tester.tap(find.text('Arşivden Geri Getir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arşivden Geri Getir').last);
    await tester.pumpAndSettle();

    expect(controller.selectedTeam!.id, team.id);
    expect(controller.selectedTeam!.isArchived, isFalse);
    expect(controller.selectedTeam!.isActive, isFalse);
    expect(find.text('Pasif'), findsWidgets);
  });

  testWidgets(
    'aynı isim create akışı arşivlenmiş ekibi geri yüklemeyi önerir',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const manager = {AppPermission.manageTeamPermissions};
      final repository = FakeTeamRepository(delay: Duration.zero);
      await repository.archiveTeam(
        teamId: 'team-technical',
        actorPermissions: manager,
      );
      final controller = TeamController(
        repository: repository,
        actorPermissions: manager,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: TeamManagementPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni Ekip'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), ' teknik ekip ');
      await tester.tap(find.text('Ekibi Oluştur'));
      await tester.pumpAndSettle();

      expect(find.text('Arşivlenmiş Ekip Bulundu'), findsOneWidget);
      expect(
        find.textContaining('Yeni ekip yerine bu ekibi arşivden geri getirmek'),
        findsOneWidget,
      );
      await tester.tap(find.text('Arşivden Geri Getir'));
      await tester.pumpAndSettle();

      expect(controller.selectedTeam!.id, 'team-technical');
      expect(controller.selectedTeam!.isArchived, isFalse);
      expect(controller.selectedTeam!.isActive, isFalse);
      expect(
        find.textContaining('Üyeleri ve yetkileri kontrol edip'),
        findsOneWidget,
      );
    },
  );
}
