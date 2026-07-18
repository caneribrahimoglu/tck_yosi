import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/services/fake_auth_service.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/widgets/auth_gate.dart';

class TckYosiApp extends StatefulWidget {
  const TckYosiApp({super.key});

  @override
  State<TckYosiApp> createState() => _TckYosiAppState();
}

class _TckYosiAppState extends State<TckYosiApp> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();

    _authController = AuthController(authService: FakeAuthService());
  }

  @override
  void dispose() {
    _authController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCK YÖSİ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(authController: _authController),
    );
  }
}
