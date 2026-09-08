import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/revaluation/fx_balance_entity.dart';
import '../../domain/revaluation/fx_revaluation_entity.dart';
import '../bloc/revaluation_bloc.dart';
import '../bloc/revaluation_event.dart';
import '../bloc/revaluation_state.dart';

/// Period-end FX revaluation workspace: mark foreign balances to market,
/// preview gains/losses, and post (optionally reversing) journals.
class FxRevaluationPage extends StatelessWidget {
  const FxRevaluationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<FxRevaluationBloc>(
          create: (_) => sl<FxRevaluationBloc>(),
          child: _FxRevaluationWorkspace(companyId: activeCompany?.id),
        );
      },
    );
  }
}

class _FxRevaluationWorkspace extends StatefulWidget {
  const _FxRevaluationWorkspace({required this.companyId});

  final String? companyId;

  @override
  State<_FxRevaluationWorkspace> createState() =>
      _FxRevaluationWorkspaceState();
}

class _FxRevaluationWorkspaceState extends State<_FxRevaluationWorkspace> {
  DateTime _date = DateTime.now();
  bool _withReversal = false;

  @override
  void initState() {
    super.initState();
    _dispatchLoad();
  }

  @override
  void didUpdateWidget(covariant _FxRevaluationWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _dispatchLoad();
    }
  }

  void _dispatchLoad() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    context
        .read<FxRevaluationBloc>()
        .add(FetchFxHistoryEvent(companyId));
  }

  String get _companyId => widget.companyId ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FX Revaluation'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: _openNewBalance,
            icon: const Icon(Icons.add_card_outlined, size: 17),
            label: const Text('Add FX Balance'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _execute,
            icon: const Icon(Icons.currency_exchange_rounded, size: 17),
            label: const Text('Execute FX Revaluation'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<FxRevaluationBloc, FxRevaluationState>(
        listener: (BuildContext context, FxRevaluationState state) {
          if (state is FxRevaluationPostedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('FX revaluation journal posted.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is FxRevaluationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, FxRevaluationState state) {
          if (widget.companyId == null) {
            return const _WorkspaceMessage(
              icon: Icons.currency_exchange_rounded,
              title: 'Select an active company',
              message: 'FX revaluation is scoped to the active company.',
            );
          }
          if (state is FxRevaluationLoading || state is FxRevaluationInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is FxRevaluationError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'FX revaluation unavailable',
              message: state.message,
              action: FilledButton.icon(
                onPressed: _dispatchLoad,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            );
          }

          final List<FxBalanceEntity> balances =
              state is FxRevaluationCalculated
                  ? state.balances
                  : state is FxRevaluationPostedSuccess
                        ? state.balances
                        : const <FxBalanceEntity>[];
          final FxRevaluationEntity? revaluation =
              state is FxRevaluationCalculated
                  ? state.revaluation
                  : state is FxRevaluationPostedSuccess
                        ? state.revaluation
                        : null;
          final List<FxRevaluationEntity> history =
              state is FxRevaluationCalculated
                  ? state.history
                  : state is FxRevaluationPostedSuccess
                        ? state.history
                        : const <FxRevaluationEntity>[];

          return _buildContent(
            context,
            balances,
            revaluation,
            history,
            state is FxRevaluationPostedSuccess,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<FxBalanceEntity> balances,
    FxRevaluationEntity? revaluation,
    List<FxRevaluationEntity> history,
    bool isPosted,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Toolbar(
            date: _date,
            withReversal: _withReversal,
            onPickDate: _pickDate,
            onToggleReversal: (bool value) =>
                setState(() => _withReversal = value),
          ),
          const SizedBox(height: 14),
          if (revaluation != null && revaluation.id.isNotEmpty) ...<Widget>[
            _SummaryCards(revaluation: revaluation),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (!isPosted)
                  FilledButton.icon(
                    onPressed: _post,
                    icon: const Icon(Icons.post_add_rounded, size: 17),
                    label: const Text('Post Journal'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _postReversal,
                    icon: const Icon(Icons.undo_rounded, size: 17),
                    label: const Text('Post Reversal'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          _BalancesGrid(balances: balances),
          const SizedBox(height: 16),
          _HistoryList(history: history),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  void _execute() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    context
        .read<FxRevaluationBloc>()
        .add(CalculateFxRevaluationEvent(_companyId, _date));
  }

  void _post() {
    context.read<FxRevaluationBloc>().add(
          PostFxRevaluationJournalEvent(withReversal: _withReversal),
        );
  }

  void _postReversal() {
    context.read<FxRevaluationBloc>().add(const PostFxReversalEvent());
  }

  void _openNewBalance() {
    if (_companyId.isEmpty) {
      _showSnack('Select a company first.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext _) => _NewBalanceDialog(companyId: _companyId),
    ).then((_) {
      if (mounted) {
        _dispatchLoad();
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.date,
    required this.withReversal,
    required this.onPickDate,
    required this.onToggleReversal,
  });

  final DateTime date;
  final bool withReversal;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onToggleReversal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text('Revaluation date: ${AppFormatters.date(date)}'),
          ),
          const Spacer(),
          Checkbox(
            value: withReversal,
            onChanged: (bool? value) => onToggleReversal(value ?? false),
          ),
          Text(
            'Auto-reversal next period',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.revaluation});

  final FxRevaluationEntity revaluation;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _SummaryCard(
          label: 'Total Gains',
          value: AppFormatters.decimal(revaluation.totalUnrealizedGain),
          icon: Icons.trending_up_rounded,
          color: AppColors.success,
        ),
        _SummaryCard(
          label: 'Total Losses',
          value: AppFormatters.decimal(revaluation.totalUnrealizedLoss),
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
        ),
        _SummaryCard(
          label: 'Net P&L Impact',
          value: AppFormatters.decimal(revaluation.netFxImpact),
          icon: Icons.balance_rounded,
          color: revaluation.netFxImpact >= 0 ? AppColors.success : AppColors.error,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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

class _BalancesGrid extends StatelessWidget {
  const _BalancesGrid({required this.balances});

  final List<FxBalanceEntity> balances;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: 'Open Foreign Balances',
      icon: Icons.account_balance_wallet_outlined,
      child: balances.isEmpty
          ? Text(
              'No open foreign balances. Add one to begin revaluation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll<Color>(
                  theme.colorScheme.surfaceContainerHighest.withAlpha(70),
                ),
                columns: const <DataColumn>[
                  DataColumn(label: Text('Account')),
                  DataColumn(label: Text('Currency')),
                  DataColumn(label: Text('Foreign Amount'), numeric: true),
                  DataColumn(label: Text('Booking Rate'), numeric: true),
                  DataColumn(label: Text('Closing Rate'), numeric: true),
                  DataColumn(label: Text('Gain / Loss'), numeric: true),
                ],
                rows: <DataRow>[
                  for (final FxBalanceEntity balance in balances)
                    _balanceRow(context, balance),
                ],
              ),
            ),
    );
  }

  DataRow _balanceRow(BuildContext context, FxBalanceEntity balance) {
    final ThemeData theme = Theme.of(context);
    final bool isGain = balance.unrealizedGainLoss > 0;
    final Color color = isGain
        ? AppColors.success
        : balance.unrealizedGainLoss < 0
              ? AppColors.error
              : theme.colorScheme.onSurfaceVariant;
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(balance.accountId)),
        DataCell(Text(balance.foreignCurrency)),
        DataCell(Text(AppFormatters.decimal(balance.foreignAmount))),
        DataCell(
          Text(
            (balance.bookValueBaseCurrency /
                    (balance.foreignAmount == 0 ? 1 : balance.foreignAmount))
                .toStringAsFixed(4),
          ),
        ),
        DataCell(Text(balance.currentExchangeRate.toStringAsFixed(4))),
        DataCell(
          Text(
            AppFormatters.decimal(balance.unrealizedGainLoss),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.history});

  final List<FxRevaluationEntity> history;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _SectionCard(
      title: 'Revaluation History',
      icon: Icons.history_rounded,
      child: history.isEmpty
          ? Text(
              'No revaluation runs yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll<Color>(
                  theme.colorScheme.surfaceContainerHighest.withAlpha(70),
                ),
                columns: const <DataColumn>[
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Period')),
                  DataColumn(label: Text('Gains'), numeric: true),
                  DataColumn(label: Text('Losses'), numeric: true),
                  DataColumn(label: Text('Net'), numeric: true),
                  DataColumn(label: Text('Posted')),
                ],
                rows: <DataRow>[
                  for (final FxRevaluationEntity run in history)
                    DataRow(
                      cells: <DataCell>[
                        DataCell(Text(AppFormatters.date(run.revaluationDate))),
                        DataCell(Text('${run.periodYear}-${run.periodMonth}')),
                        DataCell(Text(AppFormatters.decimal(run.totalUnrealizedGain))),
                        DataCell(Text(AppFormatters.decimal(run.totalUnrealizedLoss))),
                        DataCell(Text(AppFormatters.decimal(run.netFxImpact))),
                        DataCell(Text(run.isPosted ? 'Yes' : 'No')),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NewBalanceDialog extends StatefulWidget {
  const _NewBalanceDialog({required this.companyId});

  final String companyId;

  @override
  State<_NewBalanceDialog> createState() => _NewBalanceDialogState();
}

class _NewBalanceDialogState extends State<_NewBalanceDialog> {
  final TextEditingController _accountId = TextEditingController();
  final TextEditingController _foreignAmount = TextEditingController();
  final TextEditingController _bookValue = TextEditingController();
  String _currency = 'USD';
  FxBalanceType _type = FxBalanceType.liability;

  @override
  void dispose() {
    _accountId.dispose();
    _foreignAmount.dispose();
    _bookValue.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _accountId.text.trim().isNotEmpty &&
      (double.tryParse(_foreignAmount.text.trim()) ?? 0) > 0 &&
      (double.tryParse(_bookValue.text.trim()) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add FX balance'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _accountId,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Account (e.g. USD Bank, Vendor A/P)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _currency,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Foreign currency',
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'USD', child: Text('USD')),
                  DropdownMenuItem<String>(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem<String>(value: 'GBP', child: Text('GBP')),
                  DropdownMenuItem<String>(value: 'TRY', child: Text('TRY')),
                  DropdownMenuItem<String>(value: 'RUB', child: Text('RUB')),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _currency = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _foreignAmount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Foreign amount',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bookValue,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Book value (base currency)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<FxBalanceType>(
                value: _type,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Balance type',
                ),
                items: <DropdownMenuItem<FxBalanceType>>[
                  for (final FxBalanceType type in FxBalanceType.values)
                    DropdownMenuItem<FxBalanceType>(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (FxBalanceType? value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () {
                  context.read<FxRevaluationBloc>().add(
                        UpsertFxBalanceEvent(
                          FxBalanceEntity(
                            id: '',
                            companyId: widget.companyId,
                            accountId: _accountId.text.trim(),
                            foreignCurrency: _currency,
                            foreignAmount:
                                double.tryParse(_foreignAmount.text.trim()) ?? 0,
                            bookValueBaseCurrency:
                                double.tryParse(_bookValue.text.trim()) ?? 0,
                            balanceType: _type,
                          ),
                        ),
                      );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Add'),
        ),
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
