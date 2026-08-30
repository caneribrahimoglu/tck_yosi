import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import 'app_card.dart';

class AppMetric {
  final String label;
  final String? compactLabel;
  final String value;
  final IconData icon;
  final Color color;
  final Key? itemKey;

  const AppMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.compactLabel,
    this.itemKey,
  });
}

class ResponsiveMetricStrip extends StatelessWidget {
  final List<AppMetric> metrics;
  final double narrowBreakpoint;

  const ResponsiveMetricStrip({
    super.key,
    required this.metrics,
    this.narrowBreakpoint = 320,
  }) : assert(metrics.length > 0);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnCount = constraints.maxWidth < narrowBreakpoint
              ? math.min(2, metrics.length)
              : metrics.length;
          final rowCount = (metrics.length / columnCount).ceil();
          final itemWidth = constraints.maxWidth / columnCount;

          return Wrap(
            children: [
              for (var index = 0; index < metrics.length; index++)
                SizedBox(
                  key: metrics[index].itemKey,
                  width: itemWidth,
                  height: 76,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: index % columnCount == columnCount - 1
                            ? BorderSide.none
                            : BorderSide(color: Theme.of(context).dividerColor),
                        bottom: index ~/ columnCount == rowCount - 1
                            ? BorderSide.none
                            : BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: _MetricItem(
                      metric: metrics[index],
                      useCompactLabel: itemWidth < 140,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final AppMetric metric;
  final bool useCompactLabel;

  const _MetricItem({required this.metric, required this.useCompactLabel});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(metric.icon, size: 18, color: metric.color),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            useCompactLabel
                ? metric.compactLabel ?? metric.label
                : metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
