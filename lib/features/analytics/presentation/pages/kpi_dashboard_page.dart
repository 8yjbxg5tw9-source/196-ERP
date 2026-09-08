import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/financial_ratio_entity.dart';
import '../../domain/services/ratio_engine.dart';
import '../bloc/analytics_bloc.dart';
import '../bloc/analytics_event.dart';
import '../bloc/analytics_state.dart';
import '../widgets/kpi_metric_card.dart';
import '../widgets/ratio_trend_line_chart.dart';

/// Executive KPI analytics dashboard: ratio summary cards, multi-period trend
/// charts, and a CFO summary of strengths and risks.
class KpiDashboardPage extends StatelessWidget {
  const KpiDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<AnalyticsBloc>(
          create: (_) => sl<AnalyticsBloc>(),
          child: _KpiWorkspace(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _KpiWorkspace extends StatefulWidget {
  const _KpiWorkspace({required this.companyId});

  final String? companyId;

  @override
  State<_KpiWorkspace> createState() => _KpiWorkspaceState();
}

class _KpiWorkspaceState extends State<_KpiWorkspace> {
  DateTimeRange _range = _yearToDate();
  String _trendMetric = 'currentRatio';

  @override
  void initState() {
    super.initState();
    _dispatchCalculate();
  }

  @override
  void didUpdateWidget(covariant _KpiWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _dispatchCalculate();
    }
  }

  static DateTimeRange _yearToDate() {
    final DateTime now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, 1, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  void _dispatchCalculate() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    context.read<AnalyticsBloc>().add(
          CalculateFinancialRatiosEvent(
            companyId: companyId,
            range: _range,
          ),
        );
  }

  Future<void> _pickRange() async {
    final DateTimeRange? selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (selected == null) {
      return;
    }
    setState(() => _range = selected);
    _dispatchCalculate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive KPI Dashboard'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: widget.companyId == null ? null : _pickRange,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(
              '${AppFormatters.date(_range.start)} – '
              '${AppFormatters.date(_range.end)}',
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocBuilder<AnalyticsBloc, AnalyticsState>(
        builder: (BuildContext context, AnalyticsState state) {
          if (widget.companyId == null) {
            return const _WorkspaceMessage(
              icon: Icons.business_outlined,
              title: 'Select an active company',
              message: 'The KPI dashboard is scoped to the active company.',
            );
          }
          if (state is AnalyticsInitial || state is AnalyticsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AnalyticsError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Ratios unavailable',
              message: state.message,
              action: FilledButton.icon(
                onPressed: _dispatchCalculate,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }
          final FinancialRatioEntity metrics =
              (state as RatiosCalculated).metrics;
          final Map<String, List<double>> trendData = state.trendData;
          return _KpiBody(
            metrics: metrics,
            trendData: trendData,
            trendMetric: _trendMetric,
            onTrendMetricChanged: (String value) =>
                setState(() => _trendMetric = value),
          );
        },
      ),
    );
  }
}

class _KpiBody extends StatelessWidget {
  const _KpiBody({
    required this.metrics,
    required this.trendData,
    required this.trendMetric,
    required this.onTrendMetricChanged,
  });

  final FinancialRatioEntity metrics;
  final Map<String, List<double>> trendData;
  final String trendMetric;
  final ValueChanged<String> onTrendMetricChanged;

  static const Map<String, String> _trendDisplayNames = <String, String>{
    'currentRatio': 'Current Ratio',
    'quickRatio': 'Quick Ratio',
    'grossProfitMargin': 'Gross Profit Margin',
    'netProfitMargin': 'Net Profit Margin',
    'daysSalesOutstanding': 'Days Sales Outstanding',
    'daysInventoryOutstanding': 'Days Inventory Outstanding',
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, double?> deltas = _computeDeltas(trendData);
    final String summary = const RatioEngine()
        .buildExecutiveSummary(metrics.benchmarks);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SummaryCard(summary: summary),
          const SizedBox(height: 14),
          for (final KpiCategory category in KpiCategory.values) ...<Widget>[
            _SectionTitle(title: category.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final RatioBenchmark benchmark
                    in metrics.benchmarks.where(
                  (RatioBenchmark benchmark) =>
                      benchmark.category == category,
                ))
                  SizedBox(
                    width: 240,
                    child: KpiMetricCard(
                      benchmark: benchmark,
                      deltaPercent: deltas[benchmark.name],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          _SectionTitle(title: 'Multi-Period Trends'),
          const SizedBox(height: 8),
          _TrendCard(
            trendData: trendData,
            selectedMetric: trendMetric,
            displayNames: _trendDisplayNames,
            onMetricChanged: onTrendMetricChanged,
          ),
        ],
      ),
    );
  }

  static Map<String, double?> _computeDeltas(
    Map<String, List<double>> trendData,
  ) {
    final Map<String, double?> deltas = <String, double?>{};
    final Map<String, String> metricToName = <String, String>{
      'currentRatio': 'Current Ratio',
      'quickRatio': 'Quick Ratio',
      'grossProfitMargin': 'Gross Profit Margin',
      'netProfitMargin': 'Net Profit Margin',
      'daysSalesOutstanding': 'Days Sales Outstanding',
      'daysInventoryOutstanding': 'Days Inventory Outstanding',
    };
    trendData.forEach((String key, List<double> series) {
      if (series.length < 2) {
        return;
      }
      final double previous = series[series.length - 2];
      final double latest = series.last;
      final double delta = previous.abs() <= 0.000001
          ? 0
          : (latest - previous) / previous.abs() * 100;
      deltas[metricToName[key] ?? key] = delta;
    });
    return deltas;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.insights_rounded, color: theme.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'CFO Executive Summary',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.trendData,
    required this.selectedMetric,
    required this.displayNames,
    required this.onMetricChanged,
  });

  final Map<String, List<double>> trendData;
  final String selectedMetric;
  final Map<String, String> displayNames;
  final ValueChanged<String> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<double> series = trendData[selectedMetric] ?? <double>[];
    final List<String> labels = _quarterLabels(series.length);
    final String unit = _unitFor(selectedMetric);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  displayNames[selectedMetric] ?? selectedMetric,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: displayNames.containsKey(selectedMetric)
                      ? selectedMetric
                      : displayNames.keys.first,
                  items: <DropdownMenuItem<String>>[
                    for (final MapEntry<String, String> entry
                        in displayNames.entries)
                      DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      onMetricChanged(value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: RatioTrendLineChart(
                series: series,
                labels: labels,
                unit: unit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _unitFor(String metric) {
    return switch (metric) {
      'grossProfitMargin' || 'netProfitMargin' => '%',
      'daysSalesOutstanding' || 'daysInventoryOutstanding' => 'days',
      _ => 'x',
    };
  }

  static List<String> _quarterLabels(int count) {
    final DateTime now = DateTime.now();
    final int quarterIndex = (now.month - 1) ~/ 3;
    final DateTime currentStart = DateTime(
      now.year,
      quarterIndex * 3 + 1,
      1,
    );
    return <String>[
      for (int offset = count - 1; offset >= 0; offset--)
        _quarterLabel(
          DateTime(currentStart.year, currentStart.month - offset * 3, 1),
        ),
    ];
  }

  static String _quarterLabel(DateTime start) {
    final int quarter = (start.month - 1) ~/ 3 + 1;
    return 'Q$quarter ${start.year}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
