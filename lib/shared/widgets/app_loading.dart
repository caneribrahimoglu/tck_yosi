import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

class AppLoading extends StatelessWidget {
  final String? message;
  final bool compact;

  const AppLoading({super.key, this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
