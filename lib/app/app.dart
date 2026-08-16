import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/services/fake_auth_service.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/widgets/auth_gate.dart';
import '../features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import '../features/technical_operations/domain/repositories/technical_work_repository.dart';
import '../features/technical_operations/presentation/controllers/field_report_controller.dart';
import '../features/technical_operations/presentation/controllers/technical_work_controller.dart';
import '../features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import '../features/teams/data/repositories/fake_team_repository.dart';
import '../features/teams/domain/repositories/team_repository.dart';
import '../features/teams/presentation/controllers/team_controller.dart';
import '../features/teams/data/adapters/team_assignment_target_adapter.dart';
import '../features/technical_operations/data/adapters/technical_work_team_archive_guard.dart';
import '../features/teams/data/adapters/team_technical_work_access_adapter.dart';
import '../features/teams/data/adapters/technical_work_participant_name_adapter.dart';

class TckYosiApp extends StatefulWidget {
  const TckYosiApp({super.key});

  @override
  State<TckYosiApp> createState() => _TckYosiAppState();
}

class _TckYosiAppState extends State<TckYosiApp> {
  late final FakeAuthService _authService;
  late final AuthController _authController;
  late final TechnicalWorkRepository _technicalWorkRepository;
  late final TechnicalWorkController _technicalWorkController;
  late final TechnicalWorkDetailController _technicalWorkDetailController;
  late final FieldReportController _fieldReportController;
  late final TeamRepository _teamRepository;
  late final TeamController _teamController;

  @override
  void initState() {
    super.initState();

    _authService = FakeAuthService();
    _authController = AuthController(authService: _authService);

    _teamRepository = FakeTeamRepository(
      archiveGuard: TechnicalWorkTeamArchiveGuard(
        repositoryProvider: () => _technicalWorkRepository,
      ),
    );

    _technicalWorkRepository = FakeTechnicalWorkRepository(
      teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
        repository: _teamRepository,
      ),
      technicalWorkAccessSource: TeamTechnicalWorkAccessAdapter(
        teamRepository: _teamRepository,
        userDirectory: _authService,
      ),
    );

    final participantNameSource = TechnicalWorkParticipantNameAdapter(
      teamRepository: _teamRepository,
      userDirectory: _authService,
    );
    _technicalWorkController = TechnicalWorkController(
      repository: _technicalWorkRepository,
      participantNameSource: participantNameSource,
    );
    _technicalWorkDetailController = TechnicalWorkDetailController(
      repository: _technicalWorkRepository,
      participantNameSource: participantNameSource,
    );

    _fieldReportController = FieldReportController(
      repository: _technicalWorkRepository,
    );

    _teamController = TeamController(
      repository: _teamRepository,
      actorPermissions: const {},
    );
  }

  @override
  void dispose() {
    _authController.dispose();
    _technicalWorkController.dispose();
    _technicalWorkDetailController.dispose();
    _fieldReportController.dispose();
    _teamController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCK YÖSİ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(
        authController: _authController,
        technicalWorkController: _technicalWorkController,
        technicalWorkDetailController: _technicalWorkDetailController,
        fieldReportController: _fieldReportController,
        teamController: _teamController,
      ),
    );
  }
}
