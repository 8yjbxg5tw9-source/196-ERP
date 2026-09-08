import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../domain/entities/bank_transaction_entity.dart';
import '../../domain/entities/split_allocation.dart';

/// Opens a modal that divides one lump-sum bank entry across multiple
/// invoices. Returns the confirmed allocations, or `null` when cancelled.
Future<List<SplitAllocation>?> showSplitTransactionDialog(
  BuildContext context, {
  required BankTransactionEntity transaction,
  required List<DocumentEntity> documents,
}) {
  return showDialog<List<SplitAllocation>>(
    context: context,
    builder: (BuildContext context) {
      return _SplitTransactionDialog(
        transaction: transaction,
        documents: documents,
      );
    },
  );
}

class _SplitTransactionDialog extends StatefulWidget {
  const _SplitTransactionDialog({
    required this.transaction,
    required this.documents,
  });

  final BankTransactionEntity transaction;
  final List<DocumentEntity> documents;

  @override
  State<_SplitTransactionDialog> createState() =>
      _SplitTransactionDialogState();
}

class _SplitTransactionDialogState extends State<_SplitTransactionDialog> {
  static const double _tolerance = 0.01;
  final Set<String> _selectedIds = <String>{};
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  String? _errorMessage;

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _allocatedTotal {
    double total = 0;
    for (final String documentId in _selectedIds) {
      final double value = _parseAmount(documentId);
      total += value;
    }
    return total;
  }

  double _parseAmount(String documentId) {
    final String text = _controllers[documentId]?.text.trim() ?? '';
    return double.tryParse(text.replaceAll(',', '.')) ?? 0;
  }

  TextEditingController _controllerFor(String documentId) {
    return _controllers.putIfAbsent(
      documentId,
      () => TextEditingController(),
    );
  }

  void _toggleDocument(String documentId) {
    setState(() {
      if (!_selectedIds.add(documentId)) {
        _selectedIds.remove(documentId);
      }
      _errorMessage = null;
    });
  }

  void _confirm() {
    final List<SplitAllocation> allocations = <SplitAllocation>[];
    for (final String documentId in _selectedIds) {
      final double amount = _parseAmount(documentId);
      if (amount <= 0) {
        setState(() {
          _errorMessage = 'Every selected invoice needs an amount greater '
              'than zero.';
        });
        return;
      }
      allocations.add(SplitAllocation(documentId: documentId, amount: amount));
    }

    if (allocations.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one invoice to split this payment.';
      });
      return;
    }

    final double total = allocations.fold<double>(
      0,
      (double sum, SplitAllocation allocation) => sum + allocation.amount,
    );
    if (total > widget.transaction.amount + _tolerance) {
      setState(() {
        _errorMessage = 'Allocated ${AppFormatters.decimal(total)} exceeds '
            'the transaction total of '
            '${AppFormatters.decimal(widget.transaction.amount)}.';
      });
      return;
    }

    Navigator.of(context).pop(allocations);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double remaining = widget.transaction.amount - _allocatedTotal;
    return AlertDialog(
      title: const Text('Split transaction across invoices'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${widget.transaction.counterpartyName ?? widget.transaction.description} '
              '· ${AppFormatters.decimal(widget.transaction.amount)} '
              '${widget.transaction.type == BankTransactionType.credit ? 'credit' : 'debit'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: widget.documents.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No approved invoices are available.'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.documents.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final DocumentEntity document =
                            widget.documents[index];
                        return _SplitRow(
                          document: document,
                          selected: _selectedIds.contains(document.id),
                          controller: _controllerFor(document.id),
                          enabled: _selectedIds.contains(document.id),
                          onToggle: () => _toggleDocument(document.id),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  remaining < -_tolerance
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: remaining < -_tolerance
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Remaining: ${AppFormatters.decimal(remaining < 0 ? 0 : remaining)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.call_split_rounded, size: 17),
          label: const Text('Split transaction'),
        ),
      ],
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.document,
    required this.selected,
    required this.controller,
    required this.enabled,
    required this.onToggle,
  });

  final DocumentEntity document;
  final bool selected;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Checkbox(value: selected, onChanged: (_) => onToggle()),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                document.invoiceNumber ?? 'Invoice',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                document.vendorName ?? 'Unknown vendor',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Amount',
              suffixText: document.currency,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
