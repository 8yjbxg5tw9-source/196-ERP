import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';

const List<Color> _palette = <Color>[
  AppColors.success,
  AppColors.primary,
  AppColors.warning,
  AppColors.rose,
  AppColors.secondary,
  AppColors.slate,
];

/// Interactive donut of the top expense categories (plus "Others"). Tapping a
/// slice highlights its legend row and percentage.
class ExpenseCategoryDonutChart extends StatefulWidget {
  const ExpenseCategoryDonutChart({
    required this.categories,
    required this.formatter,
    super.key,
  });

  final List<ExpenseCategoryBreakdown> categories;
  final String Function(double value) formatter;

  @override
  State<ExpenseCategoryDonutChart> createState() =>
      _ExpenseCategoryDonutChartState();
}

class _ExpenseCategoryDonutChartState
    extends State<ExpenseCategoryDonutChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (widget.categories.isEmpty) {
      return Center(
        child: Text(
          'No expense categories recorded.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final double total = _total();

    return Column(
      children: <Widget>[
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: <PieChartSectionData>[
                for (int index = 0; index < widget.categories.length; index++)
                  PieChartSectionData(
                    value: widget.categories[index].amount,
                    color: _palette[index % _palette.length],
                    radius: _touchedIndex == index ? 50 : 40,
                    title: _percentLabel(index, total),
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
              ],
              pieTouchData: PieTouchData(
                touchCallback:
                    (FlTouchEvent event, PieTouchResponse? response) {
                  setState(() {
                    final PieTouchedSection? touched =
                        response?.touchedSection;
                    _touchedIndex = touched == null
                        ? null
                        : touched.touchedSectionIndex;
                  });
                },
              ),
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),
        const SizedBox(height: 12),
        for (int index = 0; index < widget.categories.length; index++)
          _LegendRow(
            color: _palette[index % _palette.length],
            name: widget.categories[index].name,
            amount: widget.categories[index].amount,
            percent: _percent(index, total),
            highlighted: _touchedIndex == index,
            formatter: widget.formatter,
          ),
      ],
    );
  }

  double _total() {
    double total = 0;
    for (final ExpenseCategoryBreakdown category in widget.categories) {
      total += category.amount;
    }
    return total;
  }

  double _percent(int index, double total) {
    if (total <= 0) {
      return 0;
    }
    return widget.categories[index].amount / total * 100;
  }

  String _percentLabel(int index, double total) {
    final double percent = _percent(index, total);
    if (percent < 6) {
      return '';
    }
    return '${percent.toStringAsFixed(0)}%';
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.name,
    required this.amount,
    required this.percent,
    required this.highlighted,
    required this.formatter,
  });

  final Color color;
  final String name;
  final double amount;
  final double percent;
  final bool highlighted;
  final String Function(double value) formatter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withAlpha(20)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: highlighted ? Border.all(color: color.withAlpha(120)) : null,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            formatter(amount),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
