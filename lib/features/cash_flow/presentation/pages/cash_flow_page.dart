import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/cash_flow_line_item.dart';
import '../../domain/entities/cash_flow_monthly_point.dart';
import '../../domain/entities/cash_flow_statement_entity.dart';
import '../bloc/cash_flow_bloc.dart';
import '../bloc/cash_flow_event.dart';
import '../bloc/cash_flow_state.dart';
import '../widgets/cash_runway_waterfall_chart.dart';

/// IAS 7 cash flow workspace: direct / indirect method toggle, categorized
/// statement drill-downs, and a liquidity waterfall with runway projection.
class CashFlowPage extends StatelessWidget {
  const CashFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<CashFlowBloc>(
          create: (_) => sl<CashFlowBloc>(),
          child: _CashFlowWorkspace(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _CashFlowWorkspace extends StatefulWidget {
  const _CashFlowWorkspace({required this.companyId});

  final String? companyId;

  @override
  State<_CashFlowWorkspace> createState() => _CashFlowWorkspaceState();
}

class _CashFlowWorkspaceState extends State<_CashFlowWorkspace> {
  CashFlowMethod _method = CashFlowMethod.direct;
  DateTimeRange _range = _currentMonthRange();

  @override
  void initState() {
    super.initState();
    _dispatchGenerate();
  }

  @override
  void didUpdateWidget(covariant _CashFlowWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _dispatchGenerate();
    }
  }

  static DateTimeRange _currentMonthRange() {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, 1);
    final DateTime end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  void _dispatchGenerate() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    context.read<CashFlowBloc>().add(
          GenerateCashFlowReportEvent(
            companyId: companyId,
            range: _range,
            method: _method,
          ),
        );
  }

  void _toggleMethod(CashFlowMethod method) {
    if (method == _method) {
      return;
    }
    setState(() => _method = method);
    _dispatchGenerate();
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
    _dispatchGenerate();
  }

  void _export() {
    context.read<CashFlowBloc>().add(const ExportCashFlowPdfEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Flow Statement'),
        actions: <Widget>[
          SegmentedButton<CashFlowMethod>(
            segments: const <ButtonSegment<CashFlowMethod>>[
              ButtonSegment<CashFlowMethod>(
                value: CashFlowMethod.direct,
                label: Text('Direct · İstiqamətlər üzrə'),
                icon: Icon(Icons.east_rounded, size: 16),
              ),
              ButtonSegment<CashFlowMethod>(
                value: CashFlowMethod.indirect,
                label: Text('Indirect · Dolayı üsul'),
                icon: Icon(Icons.loop_rounded, size: 16),
              ),
            ],
            selected: <CashFlowMethod>{_method},
            onSelectionChanged: (Set<CashFlowMethod> selection) {
              if (selection.isNotEmpty) {
                _toggleMethod(selection.first);
              }
            },
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_outlined, size: 17),
            label: Text(
              '${AppFormatters.date(_range.start)} – '
              '${AppFormatters.date(_range.end)}',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
            label: const Text('Export PDF'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<CashFlowBloc, CashFlowState>(
        listener: (BuildContext context, CashFlowState state) {
          if (state is CashFlowError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is CashFlowLoaded && state.exportedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Report exported to ${state.exportedPath}'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, CashFlowState state) {
          if (widget.companyId == null) {
            return const _WorkspaceMessage(
              icon: Icons.swap_vert_rounded,
              title: 'Select an active company',
              message: 'Cash flow is scoped to the active company.',
            );
          }
          if (state is CashFlowLoading || state is CashFlowInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CashFlowError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Cash flow unavailable',
              message: state.message,
              action: FilledButton.icon(
                onPressed: _dispatchGenerate,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }
          final CashFlowStatementEntity statement = state is CashFlowLoaded
              ? state.statement
              : _emptyStatement();
          final List<CashFlowMonthlyPoint> monthly = state is CashFlowLoaded
              ? state.monthly
              : const <CashFlowMonthlyPoint>[];
          return _StatementView(
            statement: statement,
            monthly: monthly,
          );
        },
      ),
    );
  }

  CashFlowStatementEntity _emptyStatement() {
    return CashFlowStatementEntity(
      id: '',
      companyId: '',
      dateRange: _range,
      method: _method,
      operatingCashFlow: 0,
      investingCashFlow: 0,
      financingCashFlow: 0,
      beginningCashBalance: 0,
      netCashChange: 0,
      endingCashBalance: 0,
    );
  }
}

class _StatementView extends StatelessWidget {
  const _StatementView({required this.statement, required this.monthly});

  final CashFlowStatementEntity statement;
  final List<CashFlowMonthlyPoint> monthly;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SummaryStrip(statement: statement),
          const SizedBox(height: 14),
          _LiquidityCard(statement: statement, monthly: monthly),
          const SizedBox(height: 14),
          _StatementTree(statement: statement),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.statement});

  final CashFlowStatementEntity statement;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _KpiCard(
          label: 'Operating (Əməliyyat)',
          value: AppFormatters.currency(statement.operatingCashFlow, symbol: '₼'),
          icon: Icons.storefront_outlined,
          color: AppColors.primary,
        ),
        _KpiCard(
          label: 'Investing (İnvestisiya)',
          value:
              AppFormatters.currency(statement.investingCashFlow, symbol: '₼'),
          icon: Icons.domain_add_outlined,
          color: AppColors.accent,
        ),
        _KpiCard(
          label: 'Financing (Maliyyələşmə)',
          value:
              AppFormatters.currency(statement.financingCashFlow, symbol: '₼'),
          icon: Icons.account_balance_outlined,
          color: AppColors.warning,
        ),
        _KpiCard(
          label: 'Net Change',
          value: AppFormatters.currency(statement.netCashChange, symbol: '₼'),
          icon: Icons.swap_vert_rounded,
          color: statement.netCashChange >= 0
              ? AppColors.success
              : AppColors.error,
        ),
        _KpiCard(
          label: 'Ending Cash',
          value:
              AppFormatters.currency(statement.endingCashBalance, symbol: '₼'),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiquidityCard extends StatelessWidget {
  const _LiquidityCard({required this.statement, required this.monthly});

  final CashFlowStatementEntity statement;
  final List<CashFlowMonthlyPoint> monthly;

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Cash Runway & Liquidity',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: CashRunwayWaterfallChart(
                monthly: monthly,
                endingCashBalance: statement.endingCashBalance,
                formatter: (double value) =>
                    AppFormatters.currency(value, symbol: '₼'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementTree extends StatelessWidget {
  const _StatementTree({required this.statement});

  final CashFlowStatementEntity statement;

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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: <Widget>[
            _CategoryTile(
              category: CashFlowCategory.operating,
              subtitle: 'Əməliyyat fəaliyyəti',
              statement: statement,
            ),
            _CategoryTile(
              category: CashFlowCategory.investing,
              subtitle: 'İnvestisiya fəaliyyəti',
              statement: statement,
            ),
            _CategoryTile(
              category: CashFlowCategory.financing,
              subtitle: 'Maliyyələşmə fəaliyyəti',
              statement: statement,
            ),
            const Divider(height: 1),
            _ReconciliationTile(statement: statement),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.subtitle,
    required this.statement,
  });

  final CashFlowCategory category;
  final String subtitle;
  final CashFlowStatementEntity statement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<CashFlowLineItem> items = statement.itemsFor(category);
    final double total = switch (category) {
      CashFlowCategory.operating => statement.operatingCashFlow,
      CashFlowCategory.investing => statement.investingCashFlow,
      CashFlowCategory.financing => statement.financingCashFlow,
    };
    final Color color = total >= 0 ? AppColors.success : AppColors.error;
    return ExpansionTile(
      initiallyExpanded: category == CashFlowCategory.operating,
      leading: Icon(_iconFor(category), color: color),
      title: Text(
        '${category.label} Activities · $subtitle',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        '${items.length} line item(s)',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        AppFormatters.currency(total, symbol: '₼'),
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
      children: <Widget>[
        for (final CashFlowLineItem item in items)
          ListTile(
            dense: true,
            leading: Icon(
              item.activityType == CashFlowActivity.inflow
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 16,
              color: item.activityType == CashFlowActivity.inflow
                  ? AppColors.success
                  : AppColors.error,
            ),
            title: Text(item.description),
            subtitle: Text('Account ${item.accountCode}'),
            trailing: Text(
              '${item.activityType == CashFlowActivity.inflow ? '+' : '−'}'
              '${AppFormatters.currency(item.amount, symbol: '₼')}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: item.activityType == CashFlowActivity.inflow
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(CashFlowCategory category) {
    return switch (category) {
      CashFlowCategory.operating => Icons.storefront_outlined,
      CashFlowCategory.investing => Icons.domain_add_outlined,
      CashFlowCategory.financing => Icons.account_balance_outlined,
    };
  }
}

class _ReconciliationTile extends StatelessWidget {
  const _ReconciliationTile({required this.statement});

  final CashFlowStatementEntity statement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(Icons.balance_rounded, color: theme.colorScheme.primary),
      title: Text(
        'Net Increase / Decrease in Cash',
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        'Opening ${AppFormatters.currency(statement.beginningCashBalance, symbol: '₼')}'
        '  ·  Closing ${AppFormatters.currency(statement.endingCashBalance, symbol: '₼')}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        AppFormatters.currency(statement.netCashChange, symbol: '₼'),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: statement.netCashChange >= 0
              ? AppColors.success
              : AppColors.error,
        ),
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
