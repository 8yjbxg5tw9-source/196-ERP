import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/cash_flow_entity.dart';
import '../../domain/entities/chart_of_accounts.dart';
import '../../domain/entities/profit_and_loss_entity.dart';
import '../bloc/financial_report_bloc.dart';
import '../bloc/financial_report_event.dart';
import '../bloc/financial_report_state.dart';

/// Real-time financial reporting workspace: P&L, cash flow, and the
/// hierarchical chart of accounts with computed balances.
class FinancialReportsPage extends StatelessWidget {
  const FinancialReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<FinancialReportBloc>(
          create: (_) => sl<FinancialReportBloc>(),
          child: _FinancialReportsWorkspace(
            companyId: activeCompany?.id,
            companyName: activeCompany?.name,
          ),
        );
      },
    );
  }
}

class _FinancialReportsWorkspace extends StatefulWidget {
  const _FinancialReportsWorkspace({
    required this.companyId,
    required this.companyName,
  });

  final String? companyId;
  final String? companyName;

  @override
  State<_FinancialReportsWorkspace> createState() =>
      _FinancialReportsWorkspaceState();
}

class _FinancialReportsWorkspaceState
    extends State<_FinancialReportsWorkspace> {
  int _tab = 0;
  DateTimeRange _range = _currentMonthRange();

  @override
  void initState() {
    super.initState();
    _requestFetch();
  }

  @override
  void didUpdateWidget(covariant _FinancialReportsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _requestFetch();
    }
  }

  static DateTimeRange _currentMonthRange() {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, 1);
    final DateTime end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  void _requestFetch() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    final FinancialReportBloc bloc = context.read<FinancialReportBloc>();
    switch (_tab) {
      case 0:
        bloc.add(
          FetchProfitAndLossEvent(companyId: companyId, range: _range),
        );
        break;
      case 1:
        bloc.add(FetchCashFlowEvent(companyId: companyId, range: _range));
        break;
      case 2:
        bloc.add(FetchChartOfAccountsEvent(companyId));
        break;
    }
  }

  void _selectTab(int index) {
    if (index == _tab) {
      return;
    }
    setState(() => _tab = index);
    _requestFetch();
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
    _requestFetch();
  }

  void _export() {
    context.read<FinancialReportBloc>().add(const ExportReportPdfEvent());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasCompany = widget.companyId != null;
    final String rangeLabel =
        '${AppFormatters.date(_range.start)} – '
        '${AppFormatters.date(_range.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: hasCompany ? _pickRange : null,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(rangeLabel),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: hasCompany ? _export : null,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
            label: const Text('Export PDF'),
          ),
          if (widget.companyName != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 18),
              child: Center(
                child: Text(
                  widget.companyName!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: BlocConsumer<FinancialReportBloc, FinancialReportState>(
        listenWhen: (FinancialReportState previous, FinancialReportState current) =>
            current is ReportError || current is ReportExported,
        listener: (BuildContext context, FinancialReportState state) {
          if (state is ReportError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ReportExported) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Report saved to ${state.filePath}'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _requestFetch();
          }
        },
        builder: (BuildContext context, FinancialReportState state) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Row(
                  children: <Widget>[
                    SegmentedButton<int>(
                      segments: const <ButtonSegment<int>>[
                        ButtonSegment<int>(
                          value: 0,
                          icon: Icon(Icons.trending_up_rounded, size: 16),
                          label: Text('Profit & Loss'),
                        ),
                        ButtonSegment<int>(
                          value: 1,
                          icon: Icon(Icons.swap_vert_rounded, size: 16),
                          label: Text('Cash Flow'),
                        ),
                        ButtonSegment<int>(
                          value: 2,
                          icon: Icon(Icons.account_tree_outlined, size: 16),
                          label: Text('Chart of Accounts'),
                        ),
                      ],
                      selected: <int>{_tab},
                      onSelectionChanged: (Set<int> selection) =>
                          _selectTab(selection.first),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withAlpha(18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.speed_rounded,
                            size: 15,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Real-time ledger',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _buildContent(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, FinancialReportState state) {
    if (widget.companyId == null) {
      return const _WorkspaceMessage(
        icon: Icons.business_outlined,
        title: 'Select an active company',
        message: 'Financial reports are scoped to the active company.',
      );
    }

    if (state is FinancialReportInitial) {
      return const _WorkspaceMessage(
        icon: Icons.bar_chart_rounded,
        title: 'Generate a report',
        message: 'Choose a statement above and set the reporting period.',
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
        title: 'Report could not be generated',
        message: state.message,
        action: FilledButton.icon(
          onPressed: _requestFetch,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Retry'),
        ),
      );
    }

    switch (_tab) {
      case 0:
        if (state is ProfitAndLossLoaded) {
          return _ProfitAndLossView(report: state.report);
        }
        break;
      case 1:
        if (state is CashFlowLoaded) {
          return _CashFlowView(report: state.report);
        }
        break;
      case 2:
        if (state is ChartOfAccountsLoaded) {
          return _ChartOfAccountsView(balances: state.balances);
        }
        break;
    }
    return const Center(child: CircularProgressIndicator());
  }
}

class _ProfitAndLossView extends StatelessWidget {
  const _ProfitAndLossView({required this.report});

  final ProfitAndLossEntity report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cardWidth = _metricCardWidth(
                constraints.maxWidth,
                _columnsFor(constraints.maxWidth),
              );
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _MetricCard(
                    width: cardWidth,
                    label: 'Total Revenue',
                    value: _money(report.totalRevenue),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                  ),
                  _MetricCard(
                    width: cardWidth,
                    label: 'Gross Profit',
                    value: _money(report.grossProfit),
                    icon: Icons.stacked_bar_chart_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  _MetricCard(
                    width: cardWidth,
                    label: 'Net Profit',
                    value: _money(report.netProfit),
                    icon: Icons.verified_outlined,
                    color: report.netProfit >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  _MetricCard(
                    width: cardWidth,
                    label: 'Net Margin',
                    value:
                        '${report.profitMarginPercentage.toStringAsFixed(2)}%',
                    icon: Icons.percent_rounded,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _SectionPanel(
            title: 'Profit & Loss',
            rows: <_ReportRow>[
              _ReportRow('Total revenue', _money(report.totalRevenue)),
              _ReportRow('Cost of goods sold', _money(report.cogs)),
              _ReportRow(
                'Gross profit',
                _money(report.grossProfit),
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionPanel(
            title: 'Operating expenses',
            rows: <_ReportRow>[
              ...report.operatingExpenses.entries.map(
                (MapEntry<String, double> entry) =>
                    _ReportRow(entry.key, _money(entry.value)),
              ),
              _ReportRow(
                'Total expenses',
                _money(report.totalExpenses),
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionPanel(
            title: 'VAT balances',
            rows: <_ReportRow>[
              _ReportRow('Output VAT', _money(report.outputVat)),
              _ReportRow('Input VAT', _money(report.inputVat)),
              _ReportRow(
                'Net payable VAT',
                _money(report.netPayableVat),
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionPanel(
            title: 'Performance',
            rows: <_ReportRow>[
              _ReportRow('EBITDA', _money(report.ebitda)),
              _ReportRow(
                'Net profit',
                _money(report.netProfit),
                emphasized: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashFlowView extends StatelessWidget {
  const _CashFlowView({required this.report});

  final CashFlowEntity report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cardWidth = _metricCardWidth(
                constraints.maxWidth,
                _columnsFor(constraints.maxWidth),
              );
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _MetricCard(
                    width: cardWidth,
                    label: 'Operating',
                    value: _money(report.operatingCashFlow),
                    icon: Icons.business_center_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  _MetricCard(
                    width: cardWidth,
                    label: 'Investing',
                    value: _money(report.investingCashFlow),
                    icon: Icons.domain_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                  _MetricCard(
                    width: cardWidth,
                    label: 'Financing',
                    value: _money(report.financingCashFlow),
                    icon: Icons.account_balance_outlined,
                    color: AppColors.warning,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _SectionPanel(
            title: 'Cash Flow Statement',
            rows: <_ReportRow>[
              _ReportRow(
                'Operating cash flow',
                _money(report.operatingCashFlow),
              ),
              _ReportRow(
                'Investing cash flow',
                _money(report.investingCashFlow),
              ),
              _ReportRow(
                'Financing cash flow',
                _money(report.financingCashFlow),
              ),
              _ReportRow(
                'Net cash change',
                _money(report.netCashChange),
                emphasized: true,
              ),
              _ReportRow(
                'Ending cash balance',
                _money(report.endingCashBalance),
                emphasized: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartOfAccountsView extends StatelessWidget {
  const _ChartOfAccountsView({required this.balances});

  final List<AccountBalanceEntity> balances;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, AccountBalanceEntity> byCode = <String, AccountBalanceEntity>{
      for (final AccountBalanceEntity balance in balances)
        balance.account.code: balance,
    };
    final Map<String, int> depths = <String, int>{};
    for (final AccountBalanceEntity balance in balances) {
      depths[balance.account.code] = _depthOf(balance.account, byCode);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(55),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Account',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'Type',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      'Balance',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withAlpha(60),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: balances.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: theme.colorScheme.outline.withAlpha(40),
                ),
                itemBuilder: (BuildContext context, int index) {
                  final AccountBalanceEntity balance = balances[index];
                  final int depth = depths[balance.account.code] ?? 0;
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 14.0 + depth * 18,
                      right: 14,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 52,
                                child: Text(
                                  balance.account.code,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  balance.account.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: depth == 0
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            balance.account.type.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text(
                            _money(balance.balance),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: balance.balance >= 0
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _depthOf(
    AccountEntity account,
    Map<String, AccountBalanceEntity> byCode,
  ) {
    int depth = 0;
    String? parentCode = account.parentCode;
    final Set<String> visited = <String>{account.code};
    while (parentCode != null &&
        visited.add(parentCode) &&
        depth < 20 &&
        byCode.containsKey(parentCode)) {
      depth += 1;
      parentCode = byCode[parentCode]!.account.parentCode;
    }
    return depth;
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.title, required this.rows});

  final String title;
  final List<_ReportRow> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final _ReportRow row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      row.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: row.emphasized
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    row.value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: row.emphasized
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportRow {
  const _ReportRow(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

int _columnsFor(double maxWidth) {
  if (maxWidth >= 1000) {
    return 4;
  }
  if (maxWidth >= 640) {
    return 2;
  }
  return 1;
}

double _metricCardWidth(double maxWidth, int columns) {
  const double spacing = 12.0;
  return (maxWidth - spacing * (columns - 1)) / columns;
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

String _money(double value) => AppFormatters.decimal(value);
