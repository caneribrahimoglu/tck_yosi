import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import '../enums/app_status_type.dart';
import 'app_colors.dart';

class AppStatusChipTheme {
  AppStatusChipTheme._();

  static const BorderRadius borderRadius = AppRadius.xl;

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.xs,
  );

  static Color backgroundColor(AppStatusType type) {
    return switch (type) {
      AppStatusType.success => AppColors.success.withValues(alpha: 0.12),
      AppStatusType.warning => AppColors.warning.withValues(alpha: 0.14),
      AppStatusType.error => AppColors.error.withValues(alpha: 0.12),
      AppStatusType.info => AppColors.info.withValues(alpha: 0.12),
      AppStatusType.neutral => AppColors.disabledBackground,
    };
  }

  static Color foregroundColor(AppStatusType type) {
    return switch (type) {
      AppStatusType.success => AppColors.success,
      AppStatusType.warning => AppColors.warning,
      AppStatusType.error => AppColors.error,
      AppStatusType.info => AppColors.info,
      AppStatusType.neutral => AppColors.textSecondary,
    };
  }

  static IconData icon(AppStatusType type) {
    return switch (type) {
      AppStatusType.success => Icons.check_circle_outline_rounded,
      AppStatusType.warning => Icons.warning_amber_rounded,
      AppStatusType.error => Icons.error_outline_rounded,
      AppStatusType.info => Icons.info_outline_rounded,
      AppStatusType.neutral => Icons.remove_circle_outline_rounded,
    };
  }
}
