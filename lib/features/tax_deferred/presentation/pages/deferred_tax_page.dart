import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/deferred_tax_calculation_entity.dart';
import '../../domain/entities/tax_base_comparison.dart';
import '../../domain/entities/temporary_difference_entity.dart';
import '../../domain/services/deferred_tax_engine.dart';
import '../bloc/deferred_tax_bloc.dart';
import '../bloc/deferred_tax_event.dart';
import '../bloc/deferred_tax_state.dart';

/// IAS 12 deferred tax workspace: book-vs-tax comparison matrix, statutory
/// rate + ETR reconciliation, and period-end deferred tax journal posting.
class DeferredTaxPage extends StatelessWidget {
  const DeferredTaxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<DeferredTaxBloc>(
          create: (_) => sl<DeferredTaxBloc>(),
          child: _DeferredTaxWorkspace(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _DeferredTaxWorkspace extends StatefulWidget {
  const _DeferredTaxWorkspace({required this.companyId});

  final String? companyId;

  @override
  State<_DeferredTaxWorkspace> createState() => _DeferredTaxWorkspaceState();
}

class _DeferredTaxWorkspaceState extends State<_DeferredTaxWorkspace> {
  static const double _defaultTaxRate = 0.20;
  late int _year = DateTime.now().year;
  double _taxRate = _defaultTaxRate;
  String? _fetchedCompanyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? companyId = _companyId;
    if (_fetchedCompanyId != companyId) {
      _fetchedCompanyId = companyId;
      _dispatchFetch();
    }
  }

  String? get _companyId => widget.companyId;

  void _dispatchFetch() {
    final String? companyId = _companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    context.read<DeferredTaxBloc>().add(
          FetchTaxBaseComparisonEvent(companyId: companyId, year: _year),
        );
  }

  void _calculate() {
    final String? companyId = _companyId;
    if (companyId == null) {
      return;
    }
    context.read<DeferredTaxBloc>().add(
          CalculateDeferredTaxEvent(
            companyId: companyId,
            year: _year,
            taxRate: _taxRate,
          ),
        );
  }

  void _post() {
    context.read<DeferredTaxBloc>().add(const PostDeferredTaxJournalEvent());
  }

  Future<void> _addComparison() async {
    final TaxBaseComparison? comparison = await showDialog<TaxBaseComparison>(
      context: context,
      builder: (BuildContext _) => const _ComparisonDialog(),
    );
    if (comparison != null) {
      context.read<DeferredTaxBloc>().add(AddManualComparisonEvent(comparison));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? companyId = _companyId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deferred Tax (IAS 12)'),
        actions: <Widget>[
          _YearPicker(
            value: _year,
            onChanged: (int year) {
              setState(() => _year = year);
              _dispatchFetch();
            },
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: companyId == null ? null : _calculate,
            icon: const Icon(Icons.calculate_outlined, size: 17),
            label: const Text('Calculate Deferred Tax'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<DeferredTaxBloc, DeferredTaxState>(
        listener: (BuildContext context, DeferredTaxState state) {
          if (state is DeferredTaxError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is DeferredTaxPostedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Deferred tax journal posted to the ledger.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, DeferredTaxState state) {
          if (companyId == null) {
            return const _WorkspaceMessage(
              icon: Icons.business_outlined,
              title: 'Select an active company',
              message: 'Deferred tax is scoped to the active company.',
            );
          }
          if (state is DeferredTaxInitial ||
              state is DeferredTaxLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is DeferredTaxError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Deferred tax unavailable',
              message: state.message,
              action: FilledButton.icon(
                onPressed: _dispatchFetch,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (state is DeferredTaxCalculated ||
                    state is DeferredTaxPostedSuccess)
                  _ResultsCard(
                    calculation: state is DeferredTaxCalculated
                        ? state.calculation
                        : (state as DeferredTaxPostedSuccess).calculation,
                    posted: state is DeferredTaxPostedSuccess,
                    onPost: _post,
                  ),
                const SizedBox(height: 12),
                _RateCard(
                  taxRate: _taxRate,
                  onChanged: (double value) => setState(() => _taxRate = value),
                ),
                const SizedBox(height: 12),
                _ComparisonGrid(
                  comparisons: _comparisonsOf(state),
                  items: state is DeferredTaxCalculated ? state.items : null,
                  onAdd: _addComparison,
                  onRemove: (String name) => context
                      .read<DeferredTaxBloc>()
                      .add(RemoveManualComparisonEvent(name)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static List<TaxBaseComparison> _comparisonsOf(DeferredTaxState state) {
    if (state is DeferredTaxComparisonsLoaded) {
      return state.comparisons;
    }
    if (state is DeferredTaxCalculated || state is DeferredTaxPostedSuccess) {
      final List<TemporaryDifferenceEntity> items =
          state is DeferredTaxCalculated
              ? (state as DeferredTaxCalculated).items
              : const <TemporaryDifferenceEntity>[];
      return <TaxBaseComparison>[
        for (final TemporaryDifferenceEntity item in items)
          TaxBaseComparison(
            name: item.assetLiabilityName,
            nature: _natureOf(item),
            accountingValue: item.accountingBookValue,
            taxBase: item.taxCarryingBase,
          ),
      ];
    }
    return const <TaxBaseComparison>[];
  }

  static BalanceSheetNature _natureOf(TemporaryDifferenceEntity item) {
    final bool taxable =
        item.differenceType == TemporaryDifferenceType.taxableTemporary;
    final bool assetExceedsTax = item.accountingBookValue > item.taxCarryingBase;
    if (taxable) {
      return assetExceedsTax
          ? BalanceSheetNature.asset
          : BalanceSheetNature.liability;
    }
    return assetExceedsTax
        ? BalanceSheetNature.liability
        : BalanceSheetNature.asset;
  }
}

class _RateCard extends StatefulWidget {
  const _RateCard({required this.taxRate, required this.onChanged});

  final double taxRate;
  final ValueChanged<double> onChanged;

  @override
  State<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends State<_RateCard> {
  late final TextEditingController _controller = TextEditingController(
    text: (widget.taxRate * 100).toStringAsFixed(0),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
          children: <Widget>[
            Icon(Icons.percent_rounded,
                color: theme.colorScheme.secondary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Statutory profit tax rate',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String value) {
                  final double? parsed = double.tryParse(
                    value.trim().replaceAll(',', '.'),
                  );
                  if (parsed != null) {
                    widget.onChanged(parsed / 100);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Mənfəət vergisi',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.calculation,
    required this.posted,
    required this.onPost,
  });

  final DeferredTaxCalculationEntity calculation;
  final bool posted;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double movement = calculation.periodDeferredTaxExpenseBenefit;
    final bool isExpense = movement > 0;
    final String journalText = movement.abs() <= 0
        ? 'No period movement'
        : isExpense
            ? 'Dr Deferred Tax Expense (602) · Cr Deferred Tax Liability (241)'
            : 'Dr Deferred Tax Asset (143) · Cr Deferred Tax Benefit (404)';

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
                  'Deferred Tax Position — ${calculation.periodYear}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (posted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.check_circle_rounded,
                            size: 15, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          'Posted',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (movement.abs() > 0)
                  FilledButton.icon(
                    onPressed: onPost,
                    icon: const Icon(Icons.post_add_outlined, size: 16),
                    label: const Text('Post Journal'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _Kpi(
                  label: 'Total DTA',
                  value: AppFormatters.currency(calculation.totalDta,
                      symbol: '₼'),
                  color: AppColors.success,
                ),
                _Kpi(
                  label: 'Total DTL',
                  value: AppFormatters.currency(calculation.totalDtl,
                      symbol: '₼'),
                  color: AppColors.error,
                ),
                _Kpi(
                  label: 'Net Position',
                  value: AppFormatters.currency(
                      calculation.netDeferredTaxPosition,
                      symbol: '₼'),
                  color: calculation.netDeferredTaxPosition >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
                _Kpi(
                  label: 'Period Expense / (Benefit)',
                  value: AppFormatters.currency(movement, symbol: '₼'),
                  color: isExpense ? AppColors.error : AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(70),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tax reconciliation (ETR)',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ReconRow(
                    'Accounting net profit',
                    AppFormatters.currency(calculation.accountingNetProfit,
                        symbol: '₼'),
                  ),
                  _ReconRow(
                    'Nominal tax expense '
                    '(${(calculation.statutoryTaxRate * 100).toStringAsFixed(0)}%)',
                    AppFormatters.currency(calculation.nominalTaxExpense,
                        symbol: '₼'),
                  ),
                  _ReconRow(
                    'Deferred tax expense / (benefit)',
                    '${movement >= 0 ? '+' : ''}'
                    '${AppFormatters.currency(movement, symbol: '₼')}',
                  ),
                  const Divider(height: 16),
                  _ReconRow(
                    'Effective tax expense',
                    AppFormatters.currency(calculation.effectiveTaxExpense,
                        symbol: '₼'),
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  isExpense
                      ? Icons.receipt_long_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Journal: $journalText  ·  '
                    '${AppFormatters.currency(movement.abs(), symbol: '₼')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconRow extends StatelessWidget {
  const _ReconRow(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonGrid extends StatelessWidget {
  const _ComparisonGrid({
    required this.comparisons,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final List<TaxBaseComparison> comparisons;
  final List<TemporaryDifferenceEntity>? items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, TemporaryDifferenceEntity> itemsByName =
        <String, TemporaryDifferenceEntity>{
      for (final TemporaryDifferenceEntity item in items ?? const <TemporaryDifferenceEntity>[])
        item.assetLiabilityName: item,
    };

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Book vs. Tax Base Comparison',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add comparison'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (comparisons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No comparisons found. Register fixed assets or add a '
                    'manual comparison.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Accounting BV'), numeric: true),
                    DataColumn(label: Text('Tax Base'), numeric: true),
                    DataColumn(label: Text('Difference'), numeric: true),
                    DataColumn(label: Text('Classification')),
                    DataColumn(label: Text('Deferred'), numeric: true),
                    DataColumn(label: Text('')),
                  ],
                  rows: <DataRow>[
                    for (final TaxBaseComparison comparison in comparisons)
                      _comparisonRow(
                        theme,
                        comparison,
                        itemsByName[comparison.name],
                        onRemove,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  DataRow _comparisonRow(
    ThemeData theme,
    TaxBaseComparison comparison,
    TemporaryDifferenceEntity? item,
    ValueChanged<String> onRemove,
  ) {
    final double difference = comparison.signedDifference;
    final bool isTaxable = item != null
        ? item.differenceType == TemporaryDifferenceType.taxableTemporary
        : (comparison.nature == BalanceSheetNature.asset && difference > 0) ||
            (comparison.nature == BalanceSheetNature.liability &&
                difference < 0);
    final Color diffColor = difference == 0
        ? theme.colorScheme.onSurfaceVariant
        : isTaxable
            ? AppColors.error
            : AppColors.success;

    return DataRow(
      cells: <DataCell>[
        DataCell(Text(comparison.name)),
        DataCell(Text(comparison.nature.label)),
        DataCell(Text(AppFormatters.decimal(comparison.accountingValue))),
        DataCell(Text(AppFormatters.decimal(comparison.taxBase))),
        DataCell(
          Text(
            '${difference >= 0 ? '+' : ''}'
            '${AppFormatters.decimal(difference)}',
            style: TextStyle(color: diffColor, fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(
          Text(
            item == null
                ? (difference == 0 ? '—' : (isTaxable ? 'Taxable' : 'Deductible'))
                : item.differenceType.label,
          ),
        ),
        DataCell(
          Text(
            item == null
                ? '—'
                : '${item.deferredTaxType.shortLabel} '
                    '${AppFormatters.decimal(item.deferredAmount)}',
            style: TextStyle(
              color: item.deferredTaxType == DeferredTaxType.deferredTaxAsset
                  ? AppColors.success
                  : AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => onRemove(comparison.name),
          ),
        ),
      ],
    );
  }
}

class _YearPicker extends StatelessWidget {
  const _YearPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final List<int> years = <int>[
      for (int year = currentYear - 4; year <= currentYear + 1; year++) year,
    ];
    return DropdownButton<int>(
      value: years.contains(value) ? value : currentYear,
      items: <DropdownMenuItem<int>>[
        for (final int year in years)
          DropdownMenuItem<int>(value: year, child: Text('$year')),
      ],
      onChanged: (int? year) {
        if (year != null) {
          onChanged(year);
        }
      },
    );
  }
}

class _ComparisonDialog extends StatefulWidget {
  const _ComparisonDialog();

  @override
  State<_ComparisonDialog> createState() => _ComparisonDialogState();
}

class _ComparisonDialogState extends State<_ComparisonDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountingController = TextEditingController();
  final TextEditingController _taxBaseController = TextEditingController();
  BalanceSheetNature _nature = BalanceSheetNature.asset;

  @override
  void dispose() {
    _nameController.dispose();
    _accountingController.dispose();
    _taxBaseController.dispose();
    super.dispose();
  }

  void _submit() {
    final double accounting =
        double.tryParse(_accountingController.text.trim().replaceAll(',', '.')) ??
            0;
    final double taxBase =
        double.tryParse(_taxBaseController.text.trim().replaceAll(',', '.')) ??
            0;
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      TaxBaseComparison(
        name: name,
        nature: _nature,
        accountingValue: accounting,
        taxBase: taxBase,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add book vs. tax comparison'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item name (e.g. Machinery Depreciation)',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<BalanceSheetNature>(
              initialValue: _nature,
              decoration: const InputDecoration(labelText: 'Nature'),
              items: <DropdownMenuItem<BalanceSheetNature>>[
                for (final BalanceSheetNature nature
                    in BalanceSheetNature.values)
                  DropdownMenuItem<BalanceSheetNature>(
                    value: nature,
                    child: Text(nature.label),
                  ),
              ],
              onChanged: (BalanceSheetNature? value) {
                if (value != null) {
                  setState(() => _nature = value);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountingController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Accounting book value',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _taxBaseController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tax carrying base',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
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
