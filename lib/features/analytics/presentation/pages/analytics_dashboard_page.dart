import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/export_models.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/permission_guard.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/widgets/permission_gate.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/analytics_dashboard_entity.dart';
import '../bloc/financial_report_bloc.dart';
import '../bloc/financial_report_event.dart';
import '../bloc/financial_report_state.dart';
import '../widgets/cash_crunch_warning_card.dart';
import '../widgets/cash_flow_trend_line_chart.dart';
import '../widgets/dashboard_kpi_card.dart';
import '../widgets/expense_category_donut_chart.dart';
import '../widgets/revenue_vs_expense_bar_chart.dart';

enum _DashboardPeriod { thisMonth, quarterToDate, yearToDate, custom }

enum _DashboardCurrency {
  azn('AZN', '₼', 1),
  usd('USD', r'$', 1.7),
  eur('EUR', '€', 1.8);

  const _DashboardCurrency(this.code, this.symbol, this.aznPerUnit);

  final String code;
  final String symbol;
  final double aznPerUnit;
}

/// Executive analytics command center: interactive charts, financial health
/// widgets, and a cash-crunch predictor.
class AnalyticsDashboardPage extends StatelessWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<FinancialReportBloc>(
          create: (_) => sl<FinancialReportBloc>(),
          child: _DashboardWorkspace(company: activeCompany),
        );
      },
    );
  }
}

class _DashboardWorkspace extends StatefulWidget {
  const _DashboardWorkspace({required this.company});

  final CompanyEntity? company;

  @override
  State<_DashboardWorkspace> createState() => _DashboardWorkspaceState();
}

class _DashboardWorkspaceState extends State<_DashboardWorkspace> {
  _DashboardPeriod _period = _DashboardPeriod.thisMonth;
  _DashboardCurrency _currency = _DashboardCurrency.azn;
  DateTimeRange _range = _thisMonth();

  @override
  void initState() {
    super.initState();
    _requestFetch();
  }

  @override
  void didUpdateWidget(covariant _DashboardWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.company?.id != widget.company?.id) {
      _requestFetch();
    }
  }

  void _requestFetch() {
    final CompanyEntity? company = widget.company;
    if (company == null) {
      return;
    }
    context.read<FinancialReportBloc>().add(
          FetchDashboardAnalyticsEvent(companyId: company.id, range: _range),
        );
  }

  Future<void> _selectPeriod(_DashboardPeriod period) async {
    DateTimeRange? nextRange;
    switch (period) {
      case _DashboardPeriod.thisMonth:
        nextRange = _thisMonth();
        break;
      case _DashboardPeriod.quarterToDate:
        nextRange = _quarterToDate();
        break;
      case _DashboardPeriod.yearToDate:
        nextRange = _yearToDate();
        break;
      case _DashboardPeriod.custom:
        nextRange = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDateRange: _range,
        );
        if (nextRange == null) {
          return;
        }
        break;
    }
    setState(() {
      _period = period;
      _range = nextRange!;
    });
    _requestFetch();
  }

  String _money(double value) {
    final double converted = value / _currency.aznPerUnit;
    return '${_currency.symbol} ${AppFormatters.decimal(converted)}';
  }

  String _rangeLabel() {
    return '${AppFormatters.date(_range.start)} – '
        '${AppFormatters.date(_range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive Analytics'),
        actions: <Widget>[
          _PeriodSelector(period: _period, onSelected: _selectPeriod),
          const SizedBox(width: 8),
          _CurrencySelector(currency: _currency, onSelected: _setCurrency),
          const SizedBox(width: 8),
          PermissionGate(
            permission: AppPermission.exportReports,
            fallback: const SizedBox.shrink(),
            child: BlocBuilder<FinancialReportBloc, FinancialReportState>(
              builder: (BuildContext context, FinancialReportState state) {
                final bool enabled = state is DashboardAnalyticsLoaded;
                return OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _exportPdf(state.dashboard)
                      : null,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Export Dashboard PDF'),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: BlocBuilder<FinancialReportBloc, FinancialReportState>(
        builder: (BuildContext context, FinancialReportState state) {
          if (widget.company == null) {
            return _WorkspaceMessage(
              icon: Icons.business_outlined,
              title: 'Select an active company',
              message: 'Dashboard analytics are scoped to the active company.',
            );
          }
          if (state is ReportLoading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(state.label ?? 'Computing…'),
                ],
              ),
            );
          }
          if (state is ReportError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Dashboard could not be generated',
              message: state.message,
              action: FilledButton.icon(
                onPressed: _requestFetch,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }
          if (state is DashboardAnalyticsLoaded) {
            return _buildDashboard(context, state.dashboard, theme);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  void _setCurrency(_DashboardCurrency currency) {
    setState(() => _currency = currency);
  }

  Widget _buildDashboard(
    BuildContext context,
    DashboardAnalyticsEntity dashboard,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildKpiRow(dashboard),
          const SizedBox(height: 16),
          _buildChartsRow(dashboard, theme),
          const SizedBox(height: 16),
          _Panel(
            title: 'Cash flow & forecast',
            height: 240,
            child: CashFlowTrendLineChart(
              trend: dashboard.cashFlowTrend,
              forecast: dashboard.cashFlowForecast,
              formatter: _money,
            ),
          ),
          const SizedBox(height: 16),
          CashCrunchWarningCard(prediction: dashboard.cashCrunch),
        ],
      ),
    );
  }

  Widget _buildKpiRow(DashboardAnalyticsEntity dashboard) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = constraints.maxWidth >= 1000
            ? (constraints.maxWidth - 36) / 4
            : constraints.maxWidth >= 600
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            DashboardKpiCard(
              width: cardWidth,
              label: 'Gross Revenue',
              value: _money(dashboard.grossRevenue),
              icon: Icons.trending_up_rounded,
              color: AppColors.success,
              badge: KpiDeltaBadge(
                deltaPercent: dashboard.grossRevenueChangePercent,
              ),
            ),
            DashboardKpiCard(
              width: cardWidth,
              label: 'Net Operating Expenses',
              value: _money(dashboard.netOperatingExpenses),
              icon: Icons.account_balance_outlined,
              color: AppColors.primary,
              footer: TextButton.icon(
                onPressed: () => _showExpenseBreakdown(dashboard),
                icon: const Icon(Icons.donut_small_rounded, size: 15),
                label: const Text('Breakdown'),
              ),
            ),
            DashboardKpiCard(
              width: cardWidth,
              label: 'Net Profit Margin',
              value: '${dashboard.netProfitMargin.toStringAsFixed(2)}%',
              icon: Icons.percent_rounded,
              color: AppColors.secondary,
              badge: MarginHealthBadge(
                marginPercent: dashboard.netProfitMargin,
              ),
            ),
            DashboardKpiCard(
              width: cardWidth,
              label: 'Cash Balance & Runway',
              value: _money(dashboard.cashBalance),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.warning,
              footer: Text(
                '${dashboard.runwayMonths.toStringAsFixed(1)} months runway',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartsRow(
    DashboardAnalyticsEntity dashboard,
    ThemeData theme,
  ) {
    final Widget barPanel = _Panel(
      title: 'Revenue vs expenses',
      height: 300,
      child: RevenueVsExpenseBarChart(
        monthly: dashboard.monthlyTrend,
        formatter: _money,
      ),
    );
    final Widget donutPanel = _Panel(
      title: 'Expense categories',
      height: 300,
      child: ExpenseCategoryDonutChart(
        categories: dashboard.expenseBreakdown,
        formatter: _money,
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: <Widget>[
              barPanel,
              const SizedBox(height: 16),
              donutPanel,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 3, child: barPanel),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: donutPanel),
          ],
        );
      },
    );
  }

  Future<void> _showExpenseBreakdown(DashboardAnalyticsEntity dashboard) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Operating expense breakdown'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final ExpenseCategoryBreakdown category
                    in dashboard.expenseBreakdown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          _money(category.amount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportPdf(DashboardAnalyticsEntity dashboard) async {
    final ReportData data = ReportData(
      company: widget.company,
      title: 'Executive Analytics Dashboard',
      periodLabel: _rangeLabel(),
      currency: _currency.code,
      metrics: <ReportMetric>[
        ReportMetric(
          label: 'Gross revenue',
          value: _money(dashboard.grossRevenue),
        ),
        ReportMetric(
          label: 'Net operating expenses',
          value: _money(dashboard.netOperatingExpenses),
        ),
        ReportMetric(
          label: 'Net profit margin',
          value: '${dashboard.netProfitMargin.toStringAsFixed(2)}%',
        ),
        ReportMetric(
          label: 'Cash balance',
          value: _money(dashboard.cashBalance),
        ),
      ],
      sections: <ReportSection>[
        ReportSection(
          title: 'Liquidity & runway',
          rows: <ReportRow>[
            ReportRow(
              'Cash runway',
              '${dashboard.runwayMonths.toStringAsFixed(1)} months',
            ),
            ReportRow(
              'Debt-to-asset ratio',
              dashboard.debtToAssetRatio.toStringAsFixed(2),
            ),
            ReportRow(
              'Current ratio',
              dashboard.currentRatio.toStringAsFixed(2),
            ),
          ],
        ),
        ReportSection(
          title: 'Expense breakdown',
          rows: <ReportRow>[
            for (final ExpenseCategoryBreakdown category
                in dashboard.expenseBreakdown)
              ReportRow(category.name, _money(category.amount)),
          ],
        ),
      ],
    );

    try {
      final File file = await sl<ExportService>().generatePdfReport(
        data,
        'dashboard',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard exported to ${file.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard export failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static DateTimeRange _thisMonth() {
    final DateTime now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  static DateTimeRange _quarterToDate() {
    final DateTime now = DateTime.now();
    final int quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    return DateTimeRange(
      start: DateTime(now.year, quarterStartMonth, 1),
      end: now,
    );
  }

  static DateTimeRange _yearToDate() {
    final DateTime now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onSelected});

  final _DashboardPeriod period;
  final ValueChanged<_DashboardPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DashboardPeriod>(
      tooltip: 'Reporting period',
      initialValue: period,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_DashboardPeriod>>[
        const PopupMenuItem<_DashboardPeriod>(
          value: _DashboardPeriod.thisMonth,
          child: Text('This Month'),
        ),
        const PopupMenuItem<_DashboardPeriod>(
          value: _DashboardPeriod.quarterToDate,
          child: Text('Quarter-to-Date'),
        ),
        const PopupMenuItem<_DashboardPeriod>(
          value: _DashboardPeriod.yearToDate,
          child: Text('Year-to-Date'),
        ),
        const PopupMenuItem<_DashboardPeriod>(
          value: _DashboardPeriod.custom,
          child: Text('Custom Range'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withAlpha(90),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(100),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.date_range_outlined, size: 16),
            const SizedBox(width: 8),
            Text(_labelOf(period)),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  static String _labelOf(_DashboardPeriod period) {
    return switch (period) {
      _DashboardPeriod.thisMonth => 'This Month',
      _DashboardPeriod.quarterToDate => 'Quarter-to-Date',
      _DashboardPeriod.yearToDate => 'Year-to-Date',
      _DashboardPeriod.custom => 'Custom Range',
    };
  }
}

class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({required this.currency, required this.onSelected});

  final _DashboardCurrency currency;
  final ValueChanged<_DashboardCurrency> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DashboardCurrency>(
      tooltip: 'Display currency',
      initialValue: currency,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<_DashboardCurrency>>[
            for (final _DashboardCurrency value in _DashboardCurrency.values)
              PopupMenuItem<_DashboardCurrency>(
                value: value,
                child: Text('${value.code} (${value.symbol})'),
              ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withAlpha(90),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(100),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              currency.code,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.height,
    required this.child,
  });

  final String title;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
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
