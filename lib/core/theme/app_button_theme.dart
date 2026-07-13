import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import '../enums/app_button_size.dart';
import '../enums/app_button_variant.dart';
import 'app_colors.dart';

class AppButtonTheme {
  AppButtonTheme._();

  static const BorderRadius borderRadius = AppRadius.md;

  static double height(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.small => 40,
      AppButtonSize.medium => 48,
      AppButtonSize.large => 56,
    };
  }

  static Color backgroundColor(AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.secondary => AppColors.surface,
      AppButtonVariant.danger => AppColors.error,
    };
  }

  static Color foregroundColor(AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => AppColors.textOnPrimary,
      AppButtonVariant.secondary => AppColors.primary,
      AppButtonVariant.danger => AppColors.textOnPrimary,
    };
  }

  static Color borderColor(AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.secondary => AppColors.primary,
      AppButtonVariant.danger => AppColors.error,
    };
  }

  static EdgeInsetsGeometry padding(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.small => const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      AppButtonSize.medium => const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
      ),
      AppButtonSize.large => const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
      ),
    };
  }

  static double iconSize(AppButtonSize size) {
    return switch (size) {
      AppButtonSize.small => 18,
      AppButtonSize.medium => 20,
      AppButtonSize.large => 22,
    };
  }
}
