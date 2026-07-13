import 'package:flutter/material.dart';

import '../../core/enums/app_button_size.dart';
import '../../core/enums/app_button_variant.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_button_theme.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonSize size;
  final AppButtonVariant variant;

  const AppButton._({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.size,
    required this.variant,
  });

  const AppButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    AppButtonSize size = AppButtonSize.medium,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         icon: icon,
         size: size,
         variant: AppButtonVariant.primary,
       );
  const AppButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    AppButtonSize size = AppButtonSize.medium,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         icon: icon,
         size: size,
         variant: AppButtonVariant.secondary,
       );

  const AppButton.danger({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    AppButtonSize size = AppButtonSize.medium,
  }) : this._(
         key: key,
         label: label,
         onPressed: onPressed,
         icon: icon,
         size: size,
         variant: AppButtonVariant.danger,
       );

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppButtonTheme.backgroundColor(variant);
    final foregroundColor = AppButtonTheme.foregroundColor(variant);
    final borderColor = AppButtonTheme.borderColor(variant);

    return SizedBox(
      height: AppButtonTheme.height(size),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: AppButtonTheme.padding(size),
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonTheme.borderRadius,
            side: BorderSide(color: borderColor),
          ),
        ),
        child: icon == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: AppButtonTheme.iconSize(size)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label),
                ],
              ),
      ),
    );
  }
}
