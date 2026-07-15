import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import '../enums/app_snackbar_type.dart';
import 'app_colors.dart';

class AppSnackbarTheme {
  AppSnackbarTheme._();

  static const BorderRadius borderRadius = AppRadius.md;

  static const EdgeInsets margin = EdgeInsets.all(AppSpacing.md);

  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.md,
  );

  static const double elevation = 6;

  static Color backgroundColor(AppSnackbarType type) {
    return switch (type) {
      AppSnackbarType.success => AppColors.success,
      AppSnackbarType.error => AppColors.error,
      AppSnackbarType.warning => AppColors.warning,
      AppSnackbarType.info => AppColors.info,
    };
  }

  static Color foregroundColor(AppSnackbarType type) {
    return switch (type) {
      AppSnackbarType.success => AppColors.textOnPrimary,
      AppSnackbarType.error => AppColors.textOnPrimary,
      AppSnackbarType.warning => AppColors.textPrimary,
      AppSnackbarType.info => AppColors.textOnPrimary,
    };
  }

  static IconData icon(AppSnackbarType type) {
    return switch (type) {
      AppSnackbarType.success => Icons.check_circle_outline_rounded,
      AppSnackbarType.error => Icons.error_outline_rounded,
      AppSnackbarType.warning => Icons.warning_amber_rounded,
      AppSnackbarType.info => Icons.info_outline_rounded,
    };
  }

  static Duration duration(AppSnackbarType type) {
    return switch (type) {
      AppSnackbarType.success => const Duration(seconds: 3),
      AppSnackbarType.error => const Duration(seconds: 5),
      AppSnackbarType.warning => const Duration(seconds: 4),
      AppSnackbarType.info => const Duration(seconds: 3),
    };
  }
}
