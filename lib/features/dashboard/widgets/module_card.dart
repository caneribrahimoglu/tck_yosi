import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';

class ModuleSummary {
  final String label;
  final String value;

  const ModuleSummary({required this.label, required this.value});
}

class ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String statusLabel;
  final List<ModuleSummary> summaries;
  final VoidCallback onTap;

  const ModuleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.statusLabel,
    this.summaries = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;
        return Semantics(
          button: true,
          label: '$title modülünü aç',
          child: AppCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: EdgeInsets.all(
                  isCompact ? AppSpacing.md : AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: colorScheme.primary),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(description),
                    if (summaries.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final summary in summaries)
                            _SummaryItem(summary: summary),
                        ],
                      ),
                    ],
                    if (isCompact)
                      const SizedBox(height: AppSpacing.lg)
                    else
                      const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Modülü aç',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final ModuleSummary summary;

  const _SummaryItem({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(summary.label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
