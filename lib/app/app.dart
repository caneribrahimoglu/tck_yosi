import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/services/fake_auth_service.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/widgets/auth_gate.dart';
import '../features/technical_operations/data/repositories/fake_technical_work_repository.dart';
import '../features/technical_operations/domain/repositories/technical_work_repository.dart';
import '../features/technical_operations/presentation/controllers/field_report_controller.dart';
import '../features/technical_operations/presentation/controllers/technical_work_controller.dart';

class TckYosiApp extends StatefulWidget {
  const TckYosiApp({super.key});

  @override
  State<TckYosiApp> createState() => _TckYosiAppState();
}

class _TckYosiAppState extends State<TckYosiApp> {
  late final AuthController _authController;
  late final TechnicalWorkRepository _technicalWorkRepository;
  late final TechnicalWorkController _technicalWorkController;
  late final FieldReportController _fieldReportController;

  @override
  void initState() {
    super.initState();

    _authController = AuthController(authService: FakeAuthService());

    _technicalWorkRepository = FakeTechnicalWorkRepository();

    _technicalWorkController = TechnicalWorkController(
      repository: _technicalWorkRepository,
    );

    _fieldReportController = FieldReportController(
      repository: _technicalWorkRepository,
    );
  }

  @override
  void dispose() {
    _authController.dispose();
    _technicalWorkController.dispose();
    _fieldReportController.dispose();

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
        fieldReportController: _fieldReportController,
      ),
    );
  }
}
