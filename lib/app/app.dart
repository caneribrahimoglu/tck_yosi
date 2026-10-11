import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/theme/app_theme.dart';
import '../features/auth/data/services/fake_auth_service.dart';
import '../features/auth/data/services/api_auth_service.dart';
import '../features/auth/data/services/session_user_directory.dart';
import '../features/auth/data/services/api_user_directory.dart';
import '../features/teams/data/repositories/api_team_repository.dart';
import '../features/users/data/api_user_management_repository.dart';
import '../features/users/presentation/user_management_controller.dart';
import '../features/technical_operations/data/repositories/api_technical_work_repository.dart';
import '../features/auth/data/session/session_store.dart';
import '../features/auth/data/session/secure_session_store.dart';
import '../features/auth/data/api_configuration.dart';
import '../features/auth/domain/services/auth_service.dart';
import '../features/auth/domain/services/app_user_directory.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/widgets/auth_gate.dart';
import '../features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import '../features/technical_operations/domain/repositories/technical_work_repository.dart';
import '../features/technical_operations/presentation/controllers/field_report_controller.dart';
import '../features/technical_operations/presentation/controllers/technical_work_controller.dart';
import '../features/technical_operations/presentation/controllers/technical_work_detail_controller.dart';
import '../features/technical_operations/presentation/controllers/technical_work_completion_controller.dart';
import '../features/technical_operations/presentation/controllers/technical_work_hold_controller.dart';
import '../features/vehicles/data/repositories/fake_vehicle_repository.dart';
import '../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../features/vehicles/presentation/controllers/vehicle_controller.dart';
import '../features/vehicles/presentation/controllers/vehicle_detail_controller.dart';
import '../features/teams/data/repositories/fake_team_repository.dart';
import '../features/teams/domain/repositories/team_repository.dart';
import '../features/teams/presentation/controllers/team_controller.dart';
import '../features/teams/data/adapters/team_assignment_target_adapter.dart';
import '../features/technical_operations/data/adapters/technical_work_team_archive_guard.dart';
import '../features/teams/data/adapters/team_technical_work_access_adapter.dart';
import '../features/teams/data/adapters/technical_work_participant_name_adapter.dart';

class TckYosiApp extends StatefulWidget {
  final AuthService? authService;
  const TckYosiApp({super.key, this.authService});

  @override
  State<TckYosiApp> createState() => _TckYosiAppState();
}

class _TckYosiAppState extends State<TckYosiApp> {
  late final AuthService _authService;
  late final AppUserDirectory _userDirectory;
  late final AuthController _authController;
  late final TechnicalWorkRepository _technicalWorkRepository;
  late final TechnicalWorkController _technicalWorkController;
  late final TechnicalWorkDetailController _technicalWorkDetailController;
  late final TechnicalWorkCompletionController
  _technicalWorkCompletionController;
  late final TechnicalWorkHoldController _technicalWorkHoldController;
  late final FieldReportController _fieldReportController;
  late final TeamRepository _teamRepository;
  late final TeamController _teamController;
  late final VehicleController _vehicleController;
  late final VehicleDetailController _vehicleDetailController;
  late final VehicleRepository _vehicleRepository;
  UserManagementController? _userManagementController;

  @override
  void initState() {
    super.initState();

    _authService =
        widget.authService ??
        ApiAuthService(
          client: http.Client(),
          sessionStore: kIsWeb
              ? MemorySessionStore()
              : const SecureSessionStore(),
          baseUrl: ApiConfiguration.baseUrl,
        );
    final service = _authService;
    _userDirectory = service is AppUserDirectory
        ? service as AppUserDirectory
        : service is ApiAuthService
        ? ApiUserDirectory(api: service, legacyNames: FakeAuthService())
        : SessionUserDirectory(
            authService: service,
            demoDirectory: FakeAuthService(),
          );
    _authController = AuthController(authService: _authService);

    final archiveGuard = TechnicalWorkTeamArchiveGuard(
      repositoryProvider: () => _technicalWorkRepository,
    );
    _teamRepository = service is ApiAuthService
        ? ApiTeamRepository(api: service, archiveGuard: archiveGuard)
        : FakeTeamRepository(archiveGuard: archiveGuard);
    if (service is ApiAuthService) {
      _userManagementController = UserManagementController(
        repository: ApiUserManagementRepository(service),
      );
    }

    _technicalWorkRepository = service is ApiAuthService
        ? ApiTechnicalWorkRepository(api: service)
        : FakeTechnicalWorkRepository(
            teamAssignmentTargetSource: TeamAssignmentTargetAdapter(
              repository: _teamRepository,
            ),
            technicalWorkAccessSource: TeamTechnicalWorkAccessAdapter(
              teamRepository: _teamRepository,
              userDirectory: _userDirectory,
            ),
          );

    final participantNameSource = TechnicalWorkParticipantNameAdapter(
      teamRepository: _teamRepository,
      userDirectory: _userDirectory,
    );
    _technicalWorkController = TechnicalWorkController(
      repository: _technicalWorkRepository,
      participantNameSource: participantNameSource,
    );
    _technicalWorkDetailController = TechnicalWorkDetailController(
      repository: _technicalWorkRepository,
      participantNameSource: participantNameSource,
    );
    _technicalWorkCompletionController = TechnicalWorkCompletionController(
      repository: _technicalWorkRepository,
      participantNameSource: participantNameSource,
    );
    _technicalWorkHoldController = TechnicalWorkHoldController(
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
    _vehicleRepository = FakeVehicleRepository();
    _vehicleController = VehicleController(
      repository: _vehicleRepository,
      userDirectory: _userDirectory,
    );
    _vehicleDetailController = VehicleDetailController(
      repository: _vehicleRepository,
    );
  }

  @override
  void dispose() {
    _authController.dispose();
    _technicalWorkController.dispose();
    _technicalWorkDetailController.dispose();
    _technicalWorkCompletionController.dispose();
    _technicalWorkHoldController.dispose();
    _fieldReportController.dispose();
    _teamController.dispose();
    _vehicleController.dispose();
    _vehicleDetailController.dispose();
    _userManagementController?.dispose();
    if (widget.authService == null && _authService is ApiAuthService) {
      _authService.dispose();
    }

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
        technicalWorkCompletionController: _technicalWorkCompletionController,
        technicalWorkHoldController: _technicalWorkHoldController,
        fieldReportController: _fieldReportController,
        teamController: _teamController,
        vehicleController: _vehicleController,
        vehicleDetailController: _vehicleDetailController,
        demoBusinessData: widget.authService == null,
        userManagementController: _userManagementController,
      ),
    );
  }
}
