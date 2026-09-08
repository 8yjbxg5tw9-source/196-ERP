import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Multi-period line chart for a single ratio series, with hover tooltips.
class RatioTrendLineChart extends StatelessWidget {
  const RatioTrendLineChart({
    required this.series,
    required this.labels,
    required this.unit,
    super.key,
  });

  final List<double> series;
  final List<String> labels;

  /// `x`, `%`, or `days`.
  final String unit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (series.isEmpty) {
      return Center(
        child: Text(
          'No trend data yet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final List<FlSpot> spots = <FlSpot>[
      for (int index = 0; index < series.length; index++)
        FlSpot(index.toDouble(), series[index]),
    ];
    final _Bounds bounds = _computeBounds(series);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        minY: bounds.minY,
        maxY: bounds.maxY,
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.secondary,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.secondary.withAlpha(18),
            ),
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
                  _format(value),
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
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[index], style: _axisStyle(theme)),
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
            getTooltipColor: (TouchedSpot spot) =>
                theme.colorScheme.inverseSurface,
            getTooltipItems: (List<TouchedSpot> touchedSpots) {
              return touchedSpots
                  .map(
                    (TouchedSpot spot) => LineTooltipItem(
                      '${_format(spot.y)} $unit',
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

  String _format(double value) {
    if (unit == '%') {
      return '${value.toStringAsFixed(1)}%';
    }
    if (unit == 'days') {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static TextStyle _axisStyle(ThemeData theme) {
    return theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(fontSize: 10);
  }

  static _Bounds _computeBounds(List<double> values) {
    double minY = 0;
    double maxY = 0;
    for (final double value in values) {
      if (value < minY) {
        minY = value;
      }
      if (value > maxY) {
        maxY = value;
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
