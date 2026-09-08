import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/consolidated_report_entity.dart';

/// One bar (member or consolidated group) rendered in the stacked chart.
class ConsolidationBarEntry {
  const ConsolidationBarEntry({
    required this.label,
    required this.revenue,
    required this.expenses,
    this.highlight = false,
  });

  final String label;
  final double revenue;
  final double expenses;
  final bool highlight;
}

/// Stacked revenue/expense bar chart comparing each group member against the
/// consolidated group totals.
class ConsolidationStackedBarChart extends StatelessWidget {
  const ConsolidationStackedBarChart({
    required this.report,
    required this.formatter,
    super.key,
  });

  final ConsolidatedReportEntity report;
  final String Function(double value) formatter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ConsolidationBarEntry> entries = <ConsolidationBarEntry>[
      for (final ConsolidatedMemberSummary summary in report.memberSummaries)
        ConsolidationBarEntry(
          label: summary.companyName,
          revenue: summary.revenue,
          expenses: summary.expenses,
        ),
      ConsolidationBarEntry(
        label: 'Consolidated',
        revenue: report.consolidatedRevenue,
        expenses: report.consolidatedExpenses,
        highlight: true,
      ),
    ];
    if (entries.isEmpty) {
      return const _EmptyChart(message: 'No group members to compare.');
    }

    double maxStack = 0;
    for (final ConsolidationBarEntry entry in entries) {
      final double stack = entry.revenue + entry.expenses;
      if (stack > maxStack) {
        maxStack = stack;
      }
    }
    final double upperBound = maxStack <= 0 ? 1 : maxStack * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Legend(color: AppColors.success, label: 'Revenue'),
            const SizedBox(width: 16),
            _Legend(color: AppColors.rose, label: 'Expenses'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: upperBound,
              barGroups: <BarChartGroupData>[
                for (int index = 0; index < entries.length; index++)
                  _group(index, entries[index]),
              ],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        _axisLabel(value),
                        style: _axisStyle(theme),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          entries[index].label,
                          overflow: TextOverflow.ellipsis,
                          style: _axisStyle(theme).copyWith(
                            fontWeight: entries[index].highlight
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (double value) => FlLine(
                  color: theme.colorScheme.outline.withAlpha(36),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (BarChartGroupData group) =>
                      theme.colorScheme.inverseSurface,
                  getTooltipItem: (
                    BarChartGroupData group,
                    int groupIndex,
                    BarChartRodData rod,
                    int rodIndex,
                  ) {
                    final ConsolidationBarEntry entry =
                        entries[groupIndex];
                    return BarTooltipItem(
                      '${entry.label}\n'
                      'Revenue · ${formatter(entry.revenue)}\n'
                      'Expenses · ${formatter(entry.expenses)}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _group(int index, ConsolidationBarEntry entry) {
    final double revenue = entry.revenue < 0 ? 0 : entry.revenue;
    final double expenses = entry.expenses < 0 ? 0 : entry.expenses;
    return BarChartGroupData(
      x: index,
      barsSpace: 6,
      barRods: <BarChartRodData>[
        BarChartRodData(
          toY: revenue + expenses,
          width: entry.highlight ? 18 : 14,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(3),
          ),
          rodStackItems: <BarChartRodStackItem>[
            BarChartRodStackItem(
              0,
              revenue,
              entry.highlight
                  ? AppColors.success.withAlpha(220)
                  : AppColors.success,
            ),
            BarChartRodStackItem(
              revenue,
              revenue + expenses,
              entry.highlight
                  ? AppColors.rose.withAlpha(220)
                  : AppColors.rose,
            ),
          ],
        ),
      ],
    );
  }

  static TextStyle _axisStyle(ThemeData theme) {
    return theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        const TextStyle(fontSize: 10);
  }

  static String _axisLabel(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
