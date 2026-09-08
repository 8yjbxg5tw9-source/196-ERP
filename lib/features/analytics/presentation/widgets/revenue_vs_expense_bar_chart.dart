import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';

/// Dual-bar monthly P&L trend: green revenue versus rose expenses, with hover
/// tooltips showing exact formatted amounts.
class RevenueVsExpenseBarChart extends StatelessWidget {
  const RevenueVsExpenseBarChart({
    required this.monthly,
    required this.formatter,
    super.key,
  });

  final List<MonthlyProfitTrend> monthly;
  final String Function(double value) formatter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (monthly.isEmpty) {
      return const _EmptyChart(message: 'No monthly activity yet.');
    }

    final double maxValue = _maxValue();
    final double upperBound = maxValue <= 0 ? 1 : maxValue * 1.25;

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
                for (int index = 0; index < monthly.length; index++)
                  BarChartGroupData(
                    x: index,
                    barsSpace: 3,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: monthly[index].revenue,
                        color: AppColors.success,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                      BarChartRodData(
                        toY: monthly[index].expenses,
                        color: AppColors.rose,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
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
                    reservedSize: 24,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= monthly.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          monthly[index].monthLabel,
                          style: _axisStyle(theme),
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
                    final String label =
                        rodIndex == 0 ? 'Revenue' : 'Expenses';
                    return BarTooltipItem(
                      '$label · ${formatter(rod.toY)}',
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

  double _maxValue() {
    double maxValue = 0;
    for (final MonthlyProfitTrend point in monthly) {
      if (point.revenue > maxValue) {
        maxValue = point.revenue;
      }
      if (point.expenses > maxValue) {
        maxValue = point.expenses;
      }
    }
    return maxValue;
  }

  static TextStyle _axisStyle(ThemeData theme) {
    return theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
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
