import 'package:flutter/material.dart';

/// One of the four executive KPI cards rendered in the dashboard header row.
class DashboardKpiCard extends StatelessWidget {
  const DashboardKpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.badge,
    this.footer,
    super.key,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Optional top-right element (e.g. a growth or health badge).
  final Widget? badge;

  /// Optional bottom element (e.g. runway text or a category popover).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const Spacer(),
              if (badge != null) badge!,
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (footer != null) ...<Widget>[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Small percentage-delta badge used on KPI cards.
class KpiDeltaBadge extends StatelessWidget {
  const KpiDeltaBadge({required this.deltaPercent, super.key});

  final double deltaPercent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool positive = deltaPercent >= 0;
    final Color color = positive
        ? theme.colorScheme.secondary
        : theme.colorScheme.error;
    final String sign = positive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '$sign${deltaPercent.toStringAsFixed(1)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Color-coded net-margin health badge: green > 15%, amber 5–15%, red < 5%.
class MarginHealthBadge extends StatelessWidget {
  const MarginHealthBadge({required this.marginPercent, super.key});

  final double marginPercent;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (marginPercent > 15) {
      color = const Color(0xFF059669);
      label = 'Healthy';
    } else if (marginPercent >= 5) {
      color = const Color(0xFFD97706);
      label = 'Watch';
    } else {
      color = const Color(0xFFE11D48);
      label = 'At risk';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
