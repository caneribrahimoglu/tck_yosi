import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import 'app_colors.dart';

class AppInputTheme {
  AppInputTheme._();

  static const BorderRadius borderRadius = AppRadius.md;

  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.md,
  );

  static Color fillColor({required bool enabled}) {
    return enabled ? AppColors.surface : AppColors.disabledBackground;
  }

  static Color iconColor({required bool enabled}) {
    return enabled ? AppColors.textSecondary : AppColors.disabledForeground;
  }

  static TextStyle labelStyle({required bool enabled}) {
    return TextStyle(
      color: enabled ? AppColors.textPrimary : AppColors.disabledForeground,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
  }

  static const TextStyle hintStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
  );

  static const TextStyle inputStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
  );

  static const TextStyle helperStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
  );

  static const TextStyle errorStyle = TextStyle(
    color: AppColors.error,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static OutlineInputBorder enabledBorder() {
    return const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.border),
    );
  }

  static OutlineInputBorder focusedBorder() {
    return const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    );
  }

  static OutlineInputBorder errorBorder() {
    return const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.error),
    );
  }

  static OutlineInputBorder focusedErrorBorder() {
    return const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.error, width: 2),
    );
  }

  static OutlineInputBorder disabledBorder() {
    return const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.disabledBorder),
    );
  }
}
