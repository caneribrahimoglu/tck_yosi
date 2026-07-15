import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import '../enums/app_dialog_type.dart';
import 'app_colors.dart';

class AppDialogTheme {
  AppDialogTheme._();

  static const BorderRadius borderRadius = AppRadius.lg;

  static const EdgeInsets insetPadding = EdgeInsets.all(AppSpacing.lg);

  static const EdgeInsets titlePadding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg,
    0,
  );

  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.md,
    AppSpacing.lg,
    AppSpacing.lg,
  );

  static const EdgeInsets actionsPadding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    0,
    AppSpacing.lg,
    AppSpacing.lg,
  );

  static const Color backgroundColor = AppColors.surface;

  static const TextStyle titleStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle messageStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    height: 1.5,
  );

  static const double iconSize = 32;

  static IconData iconFor(AppDialogType type) {
    return switch (type) {
      AppDialogType.info => Icons.info_outline_rounded,
      AppDialogType.success => Icons.check_circle_outline_rounded,
      AppDialogType.warning => Icons.warning_amber_rounded,
      AppDialogType.error => Icons.error_outline_rounded,
      AppDialogType.confirm => Icons.help_outline_rounded,
    };
  }

  static Color iconColorFor(AppDialogType type) {
    return switch (type) {
      AppDialogType.info => AppColors.info,
      AppDialogType.success => AppColors.success,
      AppDialogType.warning => AppColors.warning,
      AppDialogType.error => AppColors.error,
      AppDialogType.confirm => AppColors.primary,
    };
  }
}
