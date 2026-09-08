import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/bank_transaction_entity.dart';
import 'match_confidence_badge.dart';

/// Left pane: bank statement line items with selection, drag sources, and
/// per-row approve / unlink / split actions.
class BankTransactionsTable extends StatelessWidget {
  const BankTransactionsTable({
    required this.transactions,
    required this.selectedTransactionId,
    required this.busy,
    required this.onSelect,
    required this.onApprove,
    required this.onUnlink,
    required this.onSplit,
    super.key,
  });

  final List<BankTransactionEntity> transactions;
  final String? selectedTransactionId;
  final bool busy;
  final ValueChanged<BankTransactionEntity> onSelect;
  final ValueChanged<BankTransactionEntity> onApprove;
  final ValueChanged<BankTransactionEntity> onUnlink;
  final ValueChanged<BankTransactionEntity> onSplit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TableHeading(
            icon: Icons.account_balance_outlined,
            title: 'Bank Statement',
            subtitle: '${transactions.length} transactions',
            accent: theme.colorScheme.primary,
          ),
          _HeaderRow(),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withAlpha(60),
          ),
          Expanded(
            child: transactions.isEmpty
                ? const _EmptyTable(
                    message: 'Import a bank statement to start reconciling.',
                  )
                : ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withAlpha(40),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final BankTransactionEntity transaction =
                          transactions[index];
                      return _TransactionRow(
                        transaction: transaction,
                        selected: transaction.id == selectedTransactionId,
                        busy: busy,
                        onSelect: onSelect,
                        onApprove: onApprove,
                        onUnlink: onUnlink,
                        onSplit: onSplit,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  const _TableHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withAlpha(20),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
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
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(55),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Row(
        children: <Widget>[
          SizedBox(width: 92, child: Text('Date', style: _cellStyle)),
          SizedBox(width: 150, child: Text('Counterparty', style: _cellStyle)),
          SizedBox(width: 104, child: Text('VÖEN / TIN', style: _cellStyle)),
          SizedBox(width: 96, child: Text('Amount', style: _cellStyle)),
          SizedBox(width: 118, child: Text('Match', style: _cellStyle)),
          SizedBox(width: 96, child: Text('Action', style: _cellStyle)),
        ],
      ),
    );
  }
}

const TextStyle _cellStyle = TextStyle(fontSize: 11);

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onApprove,
    required this.onUnlink,
    required this.onSplit,
  });

  final BankTransactionEntity transaction;
  final bool selected;
  final bool busy;
  final ValueChanged<BankTransactionEntity> onSelect;
  final ValueChanged<BankTransactionEntity> onApprove;
  final ValueChanged<BankTransactionEntity> onUnlink;
  final ValueChanged<BankTransactionEntity> onSplit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color highlight = theme.colorScheme.primary.withAlpha(14);
    final Widget row = _rowContent(context, theme);
    final Widget wrapped = Material(
      color: selected ? highlight : Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(transaction),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: row,
        ),
      ),
    );

    return Draggable<BankTransactionEntity>(
      data: transaction,
      feedback: _DragFeedback(transaction: transaction),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: wrapped,
      ),
      child: wrapped,
    );
  }

  Widget _rowContent(BuildContext context, ThemeData theme) {
    final bool isCredit = transaction.type == BankTransactionType.credit;
    final Color amountColor =
        isCredit ? AppColors.success : AppColors.error;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(
            AppFormatters.date(transaction.transactionDate),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 150,
          child: Text(
            transaction.counterpartyName ?? transaction.description,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 104,
          child: Text(
            transaction.counterpartyVoen ?? '—',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            '${isCredit ? '+' : '-'}${AppFormatters.decimal(transaction.amount)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          width: 118,
          child: MatchConfidenceBadge(transaction: transaction),
        ),
        SizedBox(width: 96, child: _actionButton(context)),
      ],
    );
  }

  Widget _actionButton(BuildContext context) {
    return switch (transaction.status) {
      MatchStatus.suggested => SizedBox(
        height: 26,
        child: FilledButton(
          onPressed: busy ? null : () => onApprove(transaction),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: const Text('Approve'),
        ),
      ),
      MatchStatus.reconciled => SizedBox(
        height: 26,
        child: OutlinedButton(
          onPressed: busy ? null : () => onUnlink(transaction),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: const Text('Unlink'),
        ),
      ),
      MatchStatus.unmatched => SizedBox(
        height: 26,
        child: TextButton(
          onPressed: busy ? null : () => onSplit(transaction),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: const Text('Split'),
        ),
      ),
    };
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.transaction});

  final BankTransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              transaction.counterpartyName ?? transaction.description,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTable extends StatelessWidget {
  const _EmptyTable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
