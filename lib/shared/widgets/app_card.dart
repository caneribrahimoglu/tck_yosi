import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_shadows.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.md,
        boxShadow: AppShadows.md,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
