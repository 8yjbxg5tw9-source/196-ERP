import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../../document_ocr/domain/entities/document_entity.dart';
import '../../domain/entities/bank_transaction_entity.dart';
import '../../domain/entities/split_allocation.dart';
import '../../domain/services/matching_engine.dart';
import '../bloc/reconciliation_bloc.dart';
import '../bloc/reconciliation_event.dart';
import '../bloc/reconciliation_state.dart';
import '../widgets/bank_transactions_table.dart';
import '../widgets/ledger_candidate_table.dart';
import '../widgets/split_transaction_dialog.dart';
import 'anomaly_inspector_page.dart';
import 'rules_builder_page.dart';

/// Dual-pane desktop reconciliation workspace: bank statement lines on the
/// left, approved invoices on the right, with AI suggestions and one-click or
/// drag-and-drop manual matching.
class ReconciliationPage extends StatelessWidget {
  const ReconciliationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<ReconciliationBloc>(
          create: (_) => sl<ReconciliationBloc>(),
          child: _ReconciliationWorkspace(
            companyId: activeCompany?.id,
            companyName: activeCompany?.name,
          ),
        );
      },
    );
  }
}

class _ReconciliationWorkspace extends StatefulWidget {
  const _ReconciliationWorkspace({
    required this.companyId,
    required this.companyName,
  });

  final String? companyId;
  final String? companyName;

  @override
  State<_ReconciliationWorkspace> createState() =>
      _ReconciliationWorkspaceState();
}

class _ReconciliationWorkspaceState extends State<_ReconciliationWorkspace> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  String? _selectedTransactionId;
  String? _selectedDocumentId;

  @override
  void initState() {
    super.initState();
    _dispatchLoadIfReady();
  }

  @override
  void didUpdateWidget(covariant _ReconciliationWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _selectedTransactionId = null;
      _selectedDocumentId = null;
      _resetFilterInputs();
      _dispatchLoadIfReady();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _dispatchLoadIfReady() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      return;
    }
    context.read<ReconciliationBloc>().add(LoadWorkspaceEvent(companyId));
  }

  void _resetFilterInputs() {
    _searchController.clear();
    _minAmountController.clear();
    _maxAmountController.clear();
  }

  Future<void> _importStatement() async {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      _showSnack('Select an active company before importing.');
      return;
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['csv', 'xlsx', 'xls', 'txt'],
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final String? path = result.files.single.path;
    if (path == null) {
      _showSnack('The selected file could not be read.');
      return;
    }
    context.read<ReconciliationBloc>().add(
          ImportStatementEvent(file: File(path), companyId: companyId),
        );
  }

  void _runAutoMatch() {
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      _showSnack('Select an active company before matching.');
      return;
    }
    context.read<ReconciliationBloc>().add(TriggerAutoMatchEvent(companyId));
  }

  Future<void> _pickDateRange(ReconciliationFilter current) async {
    final DateTimeRange? selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: current.dateRange,
    );
    if (selected == null) {
      return;
    }
    context.read<ReconciliationBloc>().add(
          FilterTransactionsEvent(current.copyWith(dateRange: selected)),
        );
  }

  void _clearDateRange(ReconciliationFilter current) {
    context.read<ReconciliationBloc>().add(
          FilterTransactionsEvent(current.copyWith(dateRange: null)),
        );
  }

  void _updateFilter(ReconciliationFilter next) {
    context.read<ReconciliationBloc>().add(FilterTransactionsEvent(next));
  }

  void _selectTransaction(
    BankTransactionEntity transaction,
    List<DocumentEntity> documents,
  ) {
    final List<DocumentMatch> ranked =
        sl<MatchingEngine>().rankCandidates(transaction, documents);
    setState(() {
      _selectedTransactionId = transaction.id;
      _selectedDocumentId =
          ranked.isEmpty ? null : ranked.first.document.id;
    });
  }

  void _confirmMatch(BankTransactionEntity transaction) {
    final String? documentId = transaction.matchedDocumentId;
    if (documentId == null) {
      return;
    }
    context.read<ReconciliationBloc>().add(
          ConfirmMatchEvent(
            transactionId: transaction.id,
            documentId: documentId,
          ),
        );
  }

  void _unlink(BankTransactionEntity transaction) {
    context.read<ReconciliationBloc>().add(
          UnlinkTransactionEvent(transaction.id),
        );
  }

  Future<void> _split(
    BankTransactionEntity transaction,
    List<DocumentEntity> documents,
  ) async {
    final List<SplitAllocation>? allocations = await showSplitTransactionDialog(
      context,
      transaction: transaction,
      documents: documents,
    );
    if (allocations == null || !mounted) {
      return;
    }
    context.read<ReconciliationBloc>().add(
          SplitTransactionEvent(
            transactionId: transaction.id,
            allocations: allocations,
          ),
        );
  }

  void _manualLink(BankTransactionEntity transaction, DocumentEntity document) {
    context.read<ReconciliationBloc>().add(
          ManualLinkEvent(
            transactionId: transaction.id,
            documentId: document.id,
          ),
        );
  }

  void _linkSelected(BankTransactionEntity? transaction, String? documentId) {
    if (transaction == null || documentId == null) {
      _showSnack('Select a transaction and an invoice before linking.');
      return;
    }
    _manualLink(transaction, _documentById(documentId));
  }

  DocumentEntity _documentById(String documentId) {
    final ReconciliationBloc bloc = context.read<ReconciliationBloc>();
    final ReconciliationState state = bloc.state;
    final List<DocumentEntity> documents = _documentsOf(state);
    return documents.firstWhere(
      (DocumentEntity document) => document.id == documentId,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Reconciliation'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reconciliation rules',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RulesBuilderPage(),
              ),
            ),
            icon: const Icon(Icons.rule_rounded, size: 19),
          ),
          IconButton(
            tooltip: 'Fraud & anomaly inspector',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const AnomalyInspectorPage(),
              ),
            ),
            icon: const Icon(Icons.shield_outlined, size: 19),
          ),
          const SizedBox(width: 4),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'AI matching engine',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (widget.companyName != null)
            Padding(
              padding: const EdgeInsets.only(right: 18),
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
      body: BlocConsumer<ReconciliationBloc, ReconciliationState>(
        listenWhen: (ReconciliationState previous, ReconciliationState current) =>
            current is ReconciliationError,
        listener: (BuildContext context, ReconciliationState state) {
          if (state is ReconciliationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, ReconciliationState state) {
          if (widget.companyId == null) {
            return const _WorkspaceMessage(
              icon: Icons.business_outlined,
              title: 'Select an active company',
              message: 'Bank reconciliation is scoped to the active company.',
            );
          }
          if (state is ReconciliationInitial || state is ReconciliationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final _WorkspaceData? workspace = _workspaceOf(state);
          if (workspace == null) {
            if (state is ReconciliationError) {
              return _WorkspaceMessage(
                icon: Icons.error_outline_rounded,
                title: 'Reconciliation workspace unavailable',
                message: state.message,
                action: FilledButton.icon(
                  onPressed: _dispatchLoadIfReady,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Retry'),
                ),
              );
            }
            return const _WorkspaceMessage(
              icon: Icons.compare_arrows_rounded,
              title: 'No bank data yet',
              message: 'Import a bank statement to begin reconciling.',
            );
          }

          final bool processing = state is ReconciliationProcessing;
          final double? progress = processing
              ? (state as ReconciliationProcessing).progress
              : null;
          final String? progressMessage = processing
              ? (state as ReconciliationProcessing).message
              : null;

          return _buildWorkspace(
            context,
            workspace,
            processing: processing,
            progress: progress,
            progressMessage: progressMessage,
          );
        },
      ),
    );
  }

  Widget _buildWorkspace(
    BuildContext context,
    _WorkspaceData workspace, {
    required bool processing,
    required double? progress,
    required String? progressMessage,
  }) {
    BankTransactionEntity? selectedTransaction;
    for (final BankTransactionEntity transaction in workspace.transactions) {
      if (transaction.id == _selectedTransactionId) {
        selectedTransaction = transaction;
        break;
      }
    }
    final List<DocumentMatch> ranked = selectedTransaction == null
        ? const <DocumentMatch>[]
        : sl<MatchingEngine>()
            .rankCandidates(selectedTransaction, workspace.documents);
    final Map<String, double> candidateConfidence = <String, double>{
      for (final DocumentMatch match in ranked)
        match.document.id: match.confidence,
    };
    final String? topCandidateId =
        ranked.isEmpty ? null : ranked.first.document.id;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: _TopControlBar(
            processing: processing,
            progress: progress,
            progressMessage: progressMessage,
            onImport: _importStatement,
            onAutoMatch: _runAutoMatch,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: _FilterBar(
            filter: workspace.filter,
            searchController: _searchController,
            minAmountController: _minAmountController,
            maxAmountController: _maxAmountController,
            onDateRange: () => _pickDateRange(workspace.filter),
            onClearDateRange: () => _clearDateRange(workspace.filter),
            onStatusChanged: (ReconciliationMatchFilter status) => _updateFilter(
              workspace.filter.copyWith(status: status),
            ),
            onQueryChanged: (String value) => _updateFilter(
              workspace.filter.copyWith(query: value),
            ),
            onMinChanged: (String value) => _updateFilter(
              workspace.filter.copyWith(minAmount: _parseNullable(value)),
            ),
            onMaxChanged: (String value) => _updateFilter(
              workspace.filter.copyWith(maxAmount: _parseNullable(value)),
            ),
            onReset: () {
              _resetFilterInputs();
              _updateFilter(const ReconciliationFilter());
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: _KpiRow(
            transactions: workspace.transactions,
            canLink: selectedTransaction != null &&
                _selectedDocumentId != null &&
                selectedTransaction.status != MatchStatus.reconciled,
            onLinkSelected: () => _linkSelected(
              selectedTransaction,
              _selectedDocumentId,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget bankPane = BankTransactionsTable(
                  transactions: workspace.filteredTransactions,
                  selectedTransactionId: _selectedTransactionId,
                  busy: processing,
                  onSelect: (BankTransactionEntity transaction) =>
                      _selectTransaction(transaction, workspace.documents),
                  onApprove: _confirmMatch,
                  onUnlink: _unlink,
                  onSplit: (BankTransactionEntity transaction) =>
                      _split(transaction, workspace.documents),
                );
                final Widget ledgerPane = LedgerCandidateTable(
                  documents: workspace.documents,
                  candidateConfidence: candidateConfidence,
                  topCandidateId: topCandidateId,
                  selectedDocumentId: _selectedDocumentId,
                  linkSourceTransaction: selectedTransaction,
                  busy: processing,
                  onSelectDocument: (String documentId) => setState(
                    () => _selectedDocumentId = documentId,
                  ),
                  onManualLink: _manualLink,
                );

                if (constraints.maxWidth < 960) {
                  return Column(
                    children: <Widget>[
                      Expanded(child: bankPane),
                      const SizedBox(height: 12),
                      Expanded(child: ledgerPane),
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: bankPane),
                    const SizedBox(width: 12),
                    Expanded(child: ledgerPane),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static double? _parseNullable(String value) {
    final String normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  static List<BankTransactionEntity> _transactionsOf(ReconciliationState state) {
    switch (state) {
      case ReconciliationLoaded value:
        return value.transactions;
      case ReconciliationProcessing value:
        return value.transactions ?? const <BankTransactionEntity>[];
      case ReconciliationError value:
        return value.transactions ?? const <BankTransactionEntity>[];
      default:
        return const <BankTransactionEntity>[];
    }
  }

  static List<DocumentEntity> _documentsOf(ReconciliationState state) {
    switch (state) {
      case ReconciliationLoaded value:
        return value.candidateDocuments;
      case ReconciliationProcessing value:
        return value.candidateDocuments ?? const <DocumentEntity>[];
      case ReconciliationError value:
        return value.candidateDocuments ?? const <DocumentEntity>[];
      default:
        return const <DocumentEntity>[];
    }
  }

  _WorkspaceData? _workspaceOf(ReconciliationState state) {
    final List<BankTransactionEntity> transactions = _transactionsOf(state);
    final List<DocumentEntity> documents = _documentsOf(state);
    ReconciliationFilter filter = const ReconciliationFilter();
    switch (state) {
      case ReconciliationLoaded value:
        filter = value.filter;
        break;
      case ReconciliationProcessing value:
        filter = value.filter ?? const ReconciliationFilter();
        break;
      case ReconciliationError value:
        filter = value.filter ?? const ReconciliationFilter();
        break;
      default:
        return null;
    }
    return _WorkspaceData(
      transactions: transactions,
      documents: documents,
      filter: filter,
    );
  }
}

class _WorkspaceData {
  const _WorkspaceData({
    required this.transactions,
    required this.documents,
    required this.filter,
  });

  final List<BankTransactionEntity> transactions;
  final List<DocumentEntity> documents;
  final ReconciliationFilter filter;
}

class _TopControlBar extends StatelessWidget {
  const _TopControlBar({
    required this.processing,
    required this.progress,
    required this.progressMessage,
    required this.onImport,
    required this.onAutoMatch,
  });

  final bool processing;
  final double? progress;
  final String? progressMessage;
  final VoidCallback onImport;
  final VoidCallback onAutoMatch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: processing ? null : onImport,
              icon: const Icon(Icons.upload_file_rounded, size: 17),
              label: const Text('Import Bank Statement'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: processing ? null : onAutoMatch,
              icon: processing
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 17),
              label: Text(processing ? 'Matching…' : 'Run AI Auto-Match'),
            ),
            const Spacer(),
            Text(
              'CSV · XLSX · MT940',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (processing && progress != null) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                progressMessage ?? 'Processing…',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.searchController,
    required this.minAmountController,
    required this.maxAmountController,
    required this.onDateRange,
    required this.onClearDateRange,
    required this.onStatusChanged,
    required this.onQueryChanged,
    required this.onMinChanged,
    required this.onMaxChanged,
    required this.onReset,
  });

  final ReconciliationFilter filter;
  final TextEditingController searchController;
  final TextEditingController minAmountController;
  final TextEditingController maxAmountController;
  final VoidCallback onDateRange;
  final VoidCallback onClearDateRange;
  final ValueChanged<ReconciliationMatchFilter> onStatusChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onMinChanged;
  final ValueChanged<String> onMaxChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTimeRange? range = filter.dateRange;
    final String rangeLabel = range == null
        ? 'All dates'
        : '${AppFormatters.date(range.start)} – '
            '${AppFormatters.date(range.end)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: onDateRange,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(rangeLabel),
          ),
          if (range != null)
            IconButton(
              tooltip: 'Clear date range',
              onPressed: onClearDateRange,
              icon: const Icon(Icons.close_rounded, size: 16),
              visualDensity: VisualDensity.compact,
            ),
          DropdownButton<ReconciliationMatchFilter>(
            value: filter.status,
            underline: const SizedBox.shrink(),
            items: const <DropdownMenuItem<ReconciliationMatchFilter>>[
              DropdownMenuItem<ReconciliationMatchFilter>(
                value: ReconciliationMatchFilter.all,
                child: Text('All statuses'),
              ),
              DropdownMenuItem<ReconciliationMatchFilter>(
                value: ReconciliationMatchFilter.reconciled,
                child: Text('Reconciled'),
              ),
              DropdownMenuItem<ReconciliationMatchFilter>(
                value: ReconciliationMatchFilter.suggested,
                child: Text('Suggested'),
              ),
              DropdownMenuItem<ReconciliationMatchFilter>(
                value: ReconciliationMatchFilter.unmatched,
                child: Text('Unmatched'),
              ),
            ],
            onChanged: (ReconciliationMatchFilter? value) {
              if (value != null) {
                onStatusChanged(value);
              }
            },
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: minAmountController,
              onChanged: onMinChanged,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Min amount',
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: maxAmountController,
              onChanged: onMaxChanged,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Max amount',
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Search',
                prefixIcon: Icon(Icons.search_rounded, size: 17),
              ),
            ),
          ),
          TextButton(
            onPressed: filter.isDefault ? null : onReset,
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.transactions,
    required this.canLink,
    required this.onLinkSelected,
  });

  final List<BankTransactionEntity> transactions;
  final bool canLink;
  final VoidCallback onLinkSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    double inflow = 0;
    double outflow = 0;
    int reconciled = 0;
    for (final BankTransactionEntity transaction in transactions) {
      if (transaction.type == BankTransactionType.credit) {
        inflow += transaction.amount;
      } else {
        outflow += transaction.amount;
      }
      if (transaction.status == MatchStatus.reconciled) {
        reconciled += 1;
      }
    }
    final double reconciledFraction = transactions.isEmpty
        ? 0
        : reconciled / transactions.length;

    return Row(
      children: <Widget>[
        _KpiCard(
          label: 'Total Inflow',
          value: AppFormatters.decimal(inflow),
          icon: Icons.south_west_rounded,
          color: AppColors.success,
          expanded: true,
        ),
        const SizedBox(width: 10),
        _KpiCard(
          label: 'Total Outflow',
          value: AppFormatters.decimal(outflow),
          icon: Icons.north_east_rounded,
          color: AppColors.error,
          expanded: true,
        ),
        const SizedBox(width: 10),
        _ReconciledCard(
          fraction: reconciledFraction,
          reconciled: reconciled,
          total: transactions.length,
        ),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: canLink ? onLinkSelected : null,
          icon: const Icon(Icons.link_rounded, size: 17),
          label: const Text('Link Selected'),
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
    this.expanded = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
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
    return expanded ? Expanded(child: card) : card;
  }
}

class _ReconciledCard extends StatelessWidget {
  const _ReconciledCard({
    required this.fraction,
    required this.reconciled,
    required this.total,
  });

  final double fraction;
  final int reconciled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int percent = (fraction * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: fraction.clamp(0.0, 1.0).toDouble(),
              strokeWidth: 3,
              backgroundColor: theme.colorScheme.outline.withAlpha(60),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Reconciled $percent%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$reconciled of $total matched',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
