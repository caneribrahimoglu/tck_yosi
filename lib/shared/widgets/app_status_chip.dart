import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/enums/app_status_type.dart';
import '../../core/theme/app_status_chip_theme.dart';

class AppStatusChip extends StatelessWidget {
  final String label;
  final AppStatusType type;
  final IconData? icon;
  final bool showIcon;

  const AppStatusChip({
    super.key,
    required this.label,
    required this.type,
    this.icon,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppStatusChipTheme.backgroundColor(type);

    final foregroundColor = AppStatusChipTheme.foregroundColor(type);

    final resolvedIcon = icon ?? AppStatusChipTheme.icon(type);

    return Container(
      padding: AppStatusChipTheme.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppStatusChipTheme.borderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(resolvedIcon, size: 16, color: foregroundColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
