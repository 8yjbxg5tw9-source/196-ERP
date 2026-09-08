import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../domain/entities/bank_transaction_entity.dart';

/// Right pane: approved invoices / ledger records with drop targets and
/// one-click link actions that reconcile the selected bank transaction.
class LedgerCandidateTable extends StatelessWidget {
  const LedgerCandidateTable({
    required this.documents,
    required this.candidateConfidence,
    required this.topCandidateId,
    required this.selectedDocumentId,
    required this.linkSourceTransaction,
    required this.busy,
    required this.onSelectDocument,
    required this.onManualLink,
    super.key,
  });

  final List<DocumentEntity> documents;
  final Map<String, double> candidateConfidence;
  final String? topCandidateId;
  final String? selectedDocumentId;
  final BankTransactionEntity? linkSourceTransaction;
  final bool busy;
  final ValueChanged<String> onSelectDocument;
  final void Function(BankTransactionEntity transaction, DocumentEntity document)
      onManualLink;

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
            icon: Icons.receipt_long_outlined,
            title: 'Approved Invoices / Ledger',
            subtitle: linkSourceTransaction == null
                ? 'Select or drag a transaction to highlight candidates'
                : 'Drop a transaction here to link it',
            accent: theme.colorScheme.secondary,
          ),
          const _LedgerHeaderRow(),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withAlpha(60),
          ),
          Expanded(
            child: documents.isEmpty
                ? const _EmptyTable(
                    message: 'No approved invoices yet. Approve an OCR invoice '
                        'to make it available for matching.',
                  )
                : ListView.separated(
                    itemCount: documents.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withAlpha(40),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final DocumentEntity document = documents[index];
                      return _LedgerRow(
                        document: document,
                        confidence: candidateConfidence[document.id],
                        isTopCandidate: document.id == topCandidateId,
                        selected: document.id == selectedDocumentId,
                        busy: busy,
                        linkSourceTransaction: linkSourceTransaction,
                        onSelect: () => onSelectDocument(document.id),
                        onManualLink: onManualLink,
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

class _LedgerHeaderRow extends StatelessWidget {
  const _LedgerHeaderRow();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(55),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Row(
        children: <Widget>[
          SizedBox(width: 96, child: Text('Invoice #', style: _cellStyle)),
          SizedBox(width: 150, child: Text('Vendor', style: _cellStyle)),
          SizedBox(width: 92, child: Text('Date', style: _cellStyle)),
          SizedBox(width: 92, child: Text('Amount', style: _cellStyle)),
          SizedBox(width: 78, child: Text('VAT', style: _cellStyle)),
          SizedBox(width: 86, child: Text('Status', style: _cellStyle)),
          SizedBox(width: 62, child: Text('Link', style: _cellStyle)),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.document,
    required this.confidence,
    required this.isTopCandidate,
    required this.selected,
    required this.busy,
    required this.linkSourceTransaction,
    required this.onSelect,
    required this.onManualLink,
  });

  final DocumentEntity document;
  final double? confidence;
  final bool isTopCandidate;
  final bool selected;
  final bool busy;
  final BankTransactionEntity? linkSourceTransaction;
  final VoidCallback onSelect;
  final void Function(BankTransactionEntity transaction, DocumentEntity document)
      onManualLink;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color highlight = theme.colorScheme.secondary.withAlpha(14);
    return DragTarget<BankTransactionEntity>(
      onWillAcceptWithDetails: (_) => !busy,
      onAcceptWithDetails: (DragTargetDetails<BankTransactionEntity> details) {
        onManualLink(details.data, document);
      },
      builder:
          (BuildContext context, List<BankTransactionEntity?> _, List<dynamic> __) {
        return Material(
          color: selected || isTopCandidate ? highlight : Colors.transparent,
          child: InkWell(
            onTap: onSelect,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 96,
                    child: Text(
                      document.invoiceNumber ?? '—',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: Text(
                      document.vendorName ?? 'Unknown vendor',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: Text(
                      _dateOf(document),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: Text(
                      AppFormatters.decimal(document.totalAmount ?? 0),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      AppFormatters.decimal(document.vatAmount ?? 0),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 86,
                    child: _StatusChip(confidence: confidence),
                  ),
                  SizedBox(width: 62, child: _linkButton(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _dateOf(DocumentEntity document) {
    final DateTime? date = document.issueDate ?? document.createdAt;
    return date == null ? '—' : AppFormatters.date(date);
  }

  Widget _linkButton(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BankTransactionEntity? transaction = linkSourceTransaction;
    final bool isTop = isTopCandidate;
    if (transaction == null) {
      return Icon(
        isTop ? Icons.arrow_back_rounded : Icons.link_off_rounded,
        size: 16,
        color: isTop
            ? theme.colorScheme.secondary
            : theme.colorScheme.onSurfaceVariant.withAlpha(120),
      );
    }

    return SizedBox(
      height: 26,
      child: IconButton(
        tooltip: isTop ? 'Link selected transaction' : 'Link transaction',
        onPressed: busy ? null : () => onManualLink(transaction, document),
        padding: EdgeInsets.zero,
        iconSize: 16,
        color: isTop
            ? theme.colorScheme.secondary
            : theme.colorScheme.onSurfaceVariant,
        icon: const Icon(Icons.link_rounded),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.confidence});

  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (confidence == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Approved',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final double value = confidence!;
    final Color color = value >= 0.9
        ? AppColors.success
        : value >= 0.6
            ? AppColors.warning
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        border: Border.all(color: color.withAlpha(140)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(value * 100).round()}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
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
              Icons.description_outlined,
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

const TextStyle _cellStyle = TextStyle(fontSize: 11);
