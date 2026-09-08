import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';

/// Smooth cash-balance line chart over the last 12 months with a dotted
/// predictive trend for the upcoming 60 days.
class CashFlowTrendLineChart extends StatelessWidget {
  const CashFlowTrendLineChart({
    required this.trend,
    required this.forecast,
    required this.formatter,
    super.key,
  });

  final List<CashFlowPoint> trend;
  final List<CashFlowPoint> forecast;
  final String Function(double value) formatter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (trend.isEmpty) {
      return Center(
        child: Text(
          'No cash flow history yet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final List<FlSpot> actualSpots = <FlSpot>[
      for (int index = 0; index < trend.length; index++)
        FlSpot(index.toDouble(), trend[index].balance),
    ];
    final List<FlSpot> forecastSpots = <FlSpot>[
      for (int index = 0; index < forecast.length; index++)
        FlSpot(
          (trend.length - 1 + index).toDouble(),
          forecast[index].balance,
        ),
    ];

    final _Bounds bounds = _computeBounds(actualSpots, forecastSpots);
    final double maxX = (trend.length - 1 + forecast.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: bounds.minY,
        maxY: bounds.maxY,
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: actualSpots,
            isCurved: true,
            color: AppColors.success,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.success.withAlpha(18),
            ),
          ),
          LineChartBarData(
            spots: forecastSpots,
            isCurved: true,
            color: AppColors.warning,
            barWidth: 2,
            dashArray: const <int>[6, 4],
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
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
              reservedSize: 24,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_xLabel(value), style: _axisStyle(theme)),
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (TouchedSpot spot) => theme.colorScheme.inverseSurface,
            getTooltipItems: (List<TouchedSpot> spots) {
              return spots
                  .map(
                    (TouchedSpot spot) => LineTooltipItem(
                      formatter(spot.y),
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(growable: false);
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  String _xLabel(double value) {
    final int index = value.toInt();
    if (index < trend.length) {
      if (index < 0) {
        return '';
      }
      final DateTime date = trend[index].date;
      return DateFormat('MMM').format(date);
    }
    final int forecastIndex = index - trend.length + 1;
    if (forecastIndex == 1) {
      return '+30d';
    }
    if (forecastIndex == 2) {
      return '+60d';
    }
    return '';
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

  static _Bounds _computeBounds(List<FlSpot> actual, List<FlSpot> forecast) {
    double minY = 0;
    double maxY = 0;
    for (final FlSpot spot in <FlSpot>[...actual, ...forecast]) {
      if (spot.y < minY) {
        minY = spot.y;
      }
      if (spot.y > maxY) {
        maxY = spot.y;
      }
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    } else {
      final double padding = (maxY - minY) * 0.15;
      minY -= padding;
      maxY += padding;
    }
    return _Bounds(minY, maxY);
  }
}

class _Bounds {
  const _Bounds(this.minY, this.maxY);

  final double minY;
  final double maxY;
}
