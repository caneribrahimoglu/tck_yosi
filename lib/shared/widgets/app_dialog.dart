import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/enums/app_dialog_type.dart';
import '../../core/theme/app_dialog_theme.dart';
import 'app_button.dart';

class AppDialog extends StatelessWidget {
  final AppDialogType type;
  final String title;
  final String message;
  final Widget? content;
  final String primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  const AppDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.content,
    required this.primaryButtonText,
    this.secondaryButtonText,
    required this.onPrimaryPressed,
    this.onSecondaryPressed,
  });

  static Future<bool> show({
    required BuildContext context,
    required AppDialogType type,
    required String title,
    required String message,
    String primaryButtonText = 'Tamam',
    String? secondaryButtonText,
    Widget? content,
    bool barrierDismissible = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return AppDialog(
          type: type,
          title: title,
          message: message,
          content: content,
          primaryButtonText: primaryButtonText,
          secondaryButtonText: secondaryButtonText,
          onPrimaryPressed: () {
            Navigator.of(dialogContext).pop(true);
          },
          onSecondaryPressed: secondaryButtonText == null
              ? null
              : () {
                  Navigator.of(dialogContext).pop(false);
                },
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final icon = AppDialogTheme.iconFor(type);
    final iconColor = AppDialogTheme.iconColorFor(type);

    return AlertDialog(
      backgroundColor: AppDialogTheme.backgroundColor,
      insetPadding: AppDialogTheme.insetPadding,
      titlePadding: AppDialogTheme.titlePadding,
      contentPadding: AppDialogTheme.contentPadding,
      actionsPadding: AppDialogTheme.actionsPadding,
      shape: RoundedRectangleBorder(borderRadius: AppDialogTheme.borderRadius),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDialogTheme.iconSize, color: iconColor),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppDialogTheme.titleStyle,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppDialogTheme.messageStyle,
            ),
            if (content != null) ...[
              const SizedBox(height: AppSpacing.lg),
              content!,
            ],
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            if (secondaryButtonText != null) ...[
              Expanded(
                child: AppButton.secondary(
                  label: secondaryButtonText!,
                  onPressed: onSecondaryPressed,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: _buildPrimaryButton()),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    if (type == AppDialogType.error) {
      return AppButton.danger(
        label: primaryButtonText,
        onPressed: onPrimaryPressed,
      );
    }

    return AppButton.primary(
      label: primaryButtonText,
      onPressed: onPrimaryPressed,
    );
  }
}
