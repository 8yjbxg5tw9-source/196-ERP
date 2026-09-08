import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/cash_flow_monthly_point.dart';

/// Waterfall-style monthly net cash movement bars (green inflows, rose
/// outflows) with a runway projection strip computed from the average burn
/// rate against the ending cash balance.
class CashRunwayWaterfallChart extends StatelessWidget {
  const CashRunwayWaterfallChart({
    required this.monthly,
    required this.endingCashBalance,
    required this.formatter,
    super.key,
  });

  final List<CashFlowMonthlyPoint> monthly;
  final double endingCashBalance;
  final String Function(double value) formatter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (monthly.isEmpty) {
      return Center(
        child: Text(
          'No monthly cash activity in the selected period.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final double averageMonthlyNet = _totalNet() / monthly.length;
    final double averageBurn = averageMonthlyNet < 0 ? -averageMonthlyNet : 0;
    final bool draining = averageBurn > 0;
    final double runwayMonths = draining ? endingCashBalance / averageBurn : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Legend(color: AppColors.success, label: 'Net inflow'),
            const SizedBox(width: 16),
            _Legend(color: AppColors.rose, label: 'Net outflow'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildChart(context)),
        const SizedBox(height: 10),
        _runwayStrip(context, draining, runwayMonths, averageBurn),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    double minNet = 0;
    double maxNet = 0;
    for (final CashFlowMonthlyPoint point in monthly) {
      if (point.netMovement < minNet) {
        minNet = point.netMovement;
      }
      if (point.netMovement > maxNet) {
        maxNet = point.netMovement;
      }
    }
    final double padding = (maxNet - minNet).abs() * 0.2;
    final double minY = minNet < 0 ? minNet - padding : -(padding.abs());
    final double maxY = maxNet > 0 ? maxNet + padding : padding.abs();
    final double safeMaxY = maxY <= minY ? minY + 1 : maxY;
    final double safeMinY = minY >= safeMaxY ? safeMaxY - 1 : minY;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: safeMinY,
        maxY: safeMaxY,
        barGroups: <BarChartGroupData>[
          for (int index = 0; index < monthly.length; index++)
            BarChartGroupData(
              x: index,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: monthly[index].netMovement,
                  color: monthly[index].netMovement >= 0
                      ? AppColors.success
                      : AppColors.rose,
                  width: 18,
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
                return Text(_axisLabel(value), style: _axisStyle(theme));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= monthly.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(monthly[index].label, style: _axisStyle(theme)),
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
              return BarTooltipItem(
                formatter(rod.toY),
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
    );
  }

  Widget _runwayStrip(
    BuildContext context,
    bool draining,
    double runwayMonths,
    double averageBurn,
  ) {
    final ThemeData theme = Theme.of(context);
    final String runwayLabel = !draining
        ? 'No burn — net cash positive'
        : 'Cash runway ≈ ${runwayMonths.toStringAsFixed(1)} months';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(60)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            draining ? Icons.hourglass_bottom_rounded : Icons.trending_up_rounded,
            size: 18,
            color: draining ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  runwayLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: draining ? AppColors.warning : AppColors.success,
                  ),
                ),
                Text(
                  draining
                      ? 'Average burn ${formatter(averageBurn)} / month · '
                          'Ending cash ${formatter(endingCashBalance)}'
                      : 'Ending cash ${formatter(endingCashBalance)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _totalNet() {
    double total = 0;
    for (final CashFlowMonthlyPoint point in monthly) {
      total += point.netMovement;
    }
    return total;
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
