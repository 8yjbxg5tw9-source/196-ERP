import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/financial_ratio_entity.dart';

/// One executive KPI card: current value, benchmark target, status badge, and
/// an optional period-over-period delta.
class KpiMetricCard extends StatelessWidget {
  const KpiMetricCard({
    required this.benchmark,
    this.deltaPercent,
    super.key,
  });

  final RatioBenchmark benchmark;
  final double? deltaPercent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color statusColor = _statusColor(benchmark.status, theme);
    final String valueText = _formatValue(benchmark);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  benchmark.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(status: benchmark.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valueText,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                'Target ${benchmark.target}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (deltaPercent != null) ...<Widget>[
                const Spacer(),
                _DeltaBadge(deltaPercent: deltaPercent!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _formatValue(RatioBenchmark benchmark) {
    final double value = benchmark.value;
    if (benchmark.status == RatioStatus.notApplicable) {
      return 'n/a';
    }
    if (benchmark.unit == '%') {
      return '${value.toStringAsFixed(1)}%';
    }
    if (benchmark.unit == 'days') {
      return '${value.toStringAsFixed(0)} days';
    }
    return value.toStringAsFixed(2);
  }

  static Color _statusColor(RatioStatus status, ThemeData theme) {
    return switch (status) {
      RatioStatus.optimal => AppColors.success,
      RatioStatus.caution => AppColors.warning,
      RatioStatus.critical => AppColors.error,
      RatioStatus.notApplicable => theme.colorScheme.onSurfaceVariant,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RatioStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = KpiMetricCard._statusColor(status, theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.deltaPercent});

  final double deltaPercent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool positive = deltaPercent >= 0;
    final Color color = positive ? AppColors.success : AppColors.error;
    final String text =
        '${positive ? '+' : ''}${deltaPercent.toStringAsFixed(1)}% vs prev.';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
