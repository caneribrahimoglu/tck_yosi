import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/enums/app_snackbar_type.dart';
import '../../core/theme/app_snackbar_theme.dart';

class AppSnackbar {
  AppSnackbar._();

  static void show({
    required BuildContext context,
    required AppSnackbarType type,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    final backgroundColor = AppSnackbarTheme.backgroundColor(type);
    final foregroundColor = AppSnackbarTheme.foregroundColor(type);
    final icon = AppSnackbarTheme.icon(type);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: AppSnackbarTheme.duration(type),
        backgroundColor: backgroundColor,
        elevation: AppSnackbarTheme.elevation,
        margin: AppSnackbarTheme.margin,
        padding: AppSnackbarTheme.contentPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppSnackbarTheme.borderRadius,
        ),
        content: Row(
          children: [
            Icon(icon, color: foregroundColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel == null || onActionPressed == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: foregroundColor,
                onPressed: onActionPressed,
              ),
      ),
    );
  }
}
