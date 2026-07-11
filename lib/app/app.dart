import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/dashboard/pages/dashboard_page.dart';

class TckYosiApp extends StatelessWidget {
  const TckYosiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCK YÖSİ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const DashboardPage(),
    );
  }
}