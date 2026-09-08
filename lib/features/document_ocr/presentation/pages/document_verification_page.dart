import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../currency/presentation/widgets/base_currency_equivalent.dart';
import '../../../currency/presentation/widgets/currency_amount_field.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/invoice_item_entity.dart';
import '../../domain/repositories/document_repository.dart';
import '../bloc/document_ocr_bloc.dart';
import '../bloc/document_ocr_event.dart';
import '../bloc/document_ocr_state.dart';
import '../company_context.dart';
import '../widgets/document_viewer.dart';

/// Desktop review workspace for correcting and approving OCR output.
class DocumentVerificationPage extends StatelessWidget {
  const DocumentVerificationPage({
    this.documentId,
    super.key,
  });

  final String? documentId;

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, activeCompany) {
        return BlocProvider<DocumentOcrBloc>(
          create: (_) => sl<DocumentOcrBloc>(),
          child: _DocumentVerificationScaffold(
            documentId: documentId,
            companyId: activeCompany?.id,
          ),
        );
      },
    );
  }
}

class _DocumentVerificationScaffold extends StatefulWidget {
  const _DocumentVerificationScaffold({
    required this.documentId,
    required this.companyId,
  });

  final String? documentId;
  final String? companyId;

  @override
  State<_DocumentVerificationScaffold> createState() =>
      _DocumentVerificationScaffoldState();
}

class _DocumentVerificationScaffoldState
    extends State<_DocumentVerificationScaffold> {
  String? _selectedDocumentId;
  String? _requestedDocumentId;
  String? _documentsCompanyId;
  Future<Either<Failure, List<DocumentEntity>>>? _documentsFuture;

  @override
  void initState() {
    super.initState();
    _selectedDocumentId = widget.documentId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronizeSelection();
  }

  @override
  void didUpdateWidget(covariant _DocumentVerificationScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _selectedDocumentId = widget.documentId;
      _requestedDocumentId = null;
    }
    if (oldWidget.companyId != widget.companyId) {
      _documentsCompanyId = null;
      _documentsFuture = null;
      _selectedDocumentId = widget.documentId;
      _requestedDocumentId = null;
    }
    _synchronizeSelection();
  }

  void _synchronizeSelection() {
    final String? documentId = _selectedDocumentId;
    if (documentId != null && documentId != _requestedDocumentId) {
      _requestedDocumentId = documentId;
      context.read<DocumentOcrBloc>().add(LoadDocumentDetails(documentId));
    }

    if (documentId == null &&
        widget.companyId != null &&
        widget.companyId != _documentsCompanyId) {
      _documentsCompanyId = widget.companyId;
      _documentsFuture = context
          .read<DocumentRepository>()
          .getDocuments(widget.companyId!);
    }
  }

  void _selectDocument(String documentId) {
    setState(() {
      _selectedDocumentId = documentId;
      _requestedDocumentId = documentId;
    });
    context.read<DocumentOcrBloc>().add(LoadDocumentDetails(documentId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR verification workspace'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        actions: <Widget>[
          if (_selectedDocumentId != null)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Text(
                  'Review before posting',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
        ],
      ),
      body: BlocConsumer<DocumentOcrBloc, DocumentOcrState>(
        listenWhen: (DocumentOcrState previous, DocumentOcrState current) =>
            current is DocumentSavedSuccess || current is DocumentError,
        listener: (BuildContext context, DocumentOcrState state) {
          if (state is DocumentSavedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document approved and audit trail recorded.'),
              ),
            );
          } else if (state is DocumentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (BuildContext context, DocumentOcrState state) {
          final DocumentEntity? document = _documentFromState(state);
          if (document == null) {
            return _buildDocumentPicker(context, state);
          }
          return _buildSplitWorkspace(context, state, document);
        },
      ),
    );
  }

  Widget _buildDocumentPicker(
    BuildContext context,
    DocumentOcrState state,
  ) {
    if (state is DocumentLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is DocumentError && state.document == null) {
      return _WorkspaceMessage(
        icon: Icons.error_outline_rounded,
        title: 'Document could not be opened',
        message: state.message,
      );
    }
    if (widget.companyId == null) {
      return const _WorkspaceMessage(
        icon: Icons.business_outlined,
        title: 'Select an active company',
        message: 'Document verification is scoped to the active company.',
      );
    }

    final Future<Either<Failure, List<DocumentEntity>>>? future =
        _documentsFuture;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<Either<Failure, List<DocumentEntity>>>(
      future: future,
      builder: (
        BuildContext context,
        AsyncSnapshot<Either<Failure, List<DocumentEntity>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _WorkspaceMessage(
            icon: Icons.error_outline_rounded,
            title: 'Documents could not be loaded',
            message: snapshot.error.toString(),
          );
        }
        final Either<Failure, List<DocumentEntity>>? result = snapshot.data;
        if (result == null) {
          return const _WorkspaceMessage(
            icon: Icons.description_outlined,
            title: 'No document selected',
            message: 'Import a document or select one from the list.',
          );
        }
        return result.fold<Widget>(
          (Failure failure) => _WorkspaceMessage(
            icon: Icons.error_outline_rounded,
            title: 'Documents could not be loaded',
            message: failure.message,
          ),
          (List<DocumentEntity> documents) {
            final List<DocumentEntity> processedDocuments = documents
                .where(
                  (DocumentEntity document) =>
                      document.status == DocumentStatus.completed,
                )
                .toList(growable: false);
            if (processedDocuments.isEmpty) {
              return const _WorkspaceMessage(
                icon: Icons.description_outlined,
                title: 'No processed documents yet',
                message: 'Import a PDF or image from the dashboard first.',
              );
            }
            return _DocumentSelectionList(
              documents: processedDocuments,
              onSelected: _selectDocument,
            );
          },
        );
      },
    );
  }

  Widget _buildSplitWorkspace(
    BuildContext context,
    DocumentOcrState state,
    DocumentEntity document,
  ) {
    final bool saving = state is DocumentSaving;
    final Widget viewer = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: DocumentViewer(document: document),
    );
    final Widget form = Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
      child: _VerificationForm(
        document: document,
        saving: saving,
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: <Widget>[
              Expanded(child: viewer),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outline.withAlpha(90),
              ),
              Expanded(child: form),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(flex: 1, child: viewer),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outline.withAlpha(90),
            ),
            Expanded(flex: 1, child: form),
          ],
        );
      },
    );
  }

  DocumentEntity? _documentFromState(DocumentOcrState state) {
    switch (state) {
      case DocumentLoaded value:
        return value.document;
      case DocumentSaving value:
        return value.document;
      case DocumentSavedSuccess value:
        return value.document;
      case DocumentError value:
        return value.document;
      default:
        return null;
    }
  }
}

class _DocumentSelectionList extends StatelessWidget {
  const _DocumentSelectionList({
    required this.documents,
    required this.onSelected,
  });

  final List<DocumentEntity> documents;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          margin: const EdgeInsets.all(28),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Processed documents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a document to verify its OCR fields before posting.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: documents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final DocumentEntity document = documents[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          document.fileName.toLowerCase().endsWith('.pdf')
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                        ),
                        title: Text(
                          document.fileName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${document.invoiceNumber ?? 'No invoice number'} · '
                          '${document.status.name}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => onSelected(document.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationForm extends StatefulWidget {
  const _VerificationForm({
    required this.document,
    required this.saving,
  });

  final DocumentEntity document;
  final bool saving;

  @override
  State<_VerificationForm> createState() => _VerificationFormState();
}

class _VerificationFormState extends State<_VerificationForm> {
  late final TextEditingController _invoiceController;
  late final TextEditingController _vendorController;
  late final TextEditingController _voenController;
  late final TextEditingController _currencyController;
  late final TextEditingController _issueDateController;
  late final TextEditingController _dueDateController;

  @override
  void initState() {
    super.initState();
    _invoiceController = TextEditingController();
    _vendorController = TextEditingController();
    _voenController = TextEditingController();
    _currencyController = TextEditingController();
    _issueDateController = TextEditingController();
    _dueDateController = TextEditingController();
    _syncControllers(widget.document);
  }

  @override
  void didUpdateWidget(covariant _VerificationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers(widget.document);
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _vendorController.dispose();
    _voenController.dispose();
    _currencyController.dispose();
    _issueDateController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DocumentEntity document = widget.document;
    final DocumentOcrBloc bloc = context.read<DocumentOcrBloc>();

    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SectionHeading(
                  title: 'Header details',
                  subtitle: 'Correct fields before the ledger entry is created.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ConfidenceTextField(
                        controller: _invoiceController,
                        label: 'Document number',
                        confidence: _confidence(document.invoiceNumber),
                        enabled: !widget.saving,
                        onChanged: (String value) => bloc.add(
                          UpdateDocumentField(
                            field: DocumentField.invoiceNumber,
                            value: value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ConfidenceTextField(
                        controller: _currencyController,
                        label: 'Currency',
                        confidence: _confidence(document.currency),
                        enabled: !widget.saving,
                        onChanged: (String value) => bloc.add(
                          UpdateDocumentField(
                            field: DocumentField.currency,
                            value: value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ConfidenceTextField(
                  controller: _vendorController,
                  label: 'Vendor name',
                  confidence: _confidence(document.vendorName),
                  enabled: !widget.saving,
                  onChanged: (String value) => bloc.add(
                    UpdateDocumentField(
                      field: DocumentField.vendorName,
                      value: value,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ConfidenceTextField(
                        controller: _voenController,
                        label: 'Vendor VÖEN / TIN',
                        confidence: _confidence(document.vendorVoen),
                        enabled: !widget.saving,
                        onChanged: (String value) => bloc.add(
                          UpdateDocumentField(
                            field: DocumentField.vendorVoen,
                            value: value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateConfidenceField(
                        controller: _issueDateController,
                        label: 'Issue date',
                        confidence: _confidence(document.issueDate),
                        value: document.issueDate,
                        enabled: !widget.saving,
                        onChanged: (DateTime? value) => bloc.add(
                          UpdateDocumentField(
                            field: DocumentField.issueDate,
                            value: value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DateConfidenceField(
                  controller: _dueDateController,
                  label: 'Due date',
                  confidence: _confidence(document.dueDate),
                  value: document.dueDate,
                  enabled: !widget.saving,
                  onChanged: (DateTime? value) => bloc.add(
                    UpdateDocumentField(
                      field: DocumentField.dueDate,
                      value: value,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _SectionHeading(
                  title: 'Line items',
                  subtitle: 'Edit quantities, prices, and VAT rates; totals update instantly.',
                  action: OutlinedButton.icon(
                    onPressed: widget.saving ? null : () => bloc.add(const AddLineItem()),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add row'),
                  ),
                ),
                const SizedBox(height: 10),
                _LineItemsGrid(
                  items: document.lineItems,
                  currency: document.currency,
                  enabled: !widget.saving,
                  onChanged: (int index, InvoiceItemEntity item) => bloc.add(
                    UpdateLineItem(index: index, item: item),
                  ),
                  onRemove: (int index) => bloc.add(RemoveLineItem(index)),
                ),
                const SizedBox(height: 22),
                _SummaryCard(document: document),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Approval writes the corrected data and an audit event atomically.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: widget.saving
                  ? null
                  : () => bloc.add(const SaveAndApproveDocument()),
              icon: widget.saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_rounded, size: 17),
              label: Text(
                widget.saving ? 'Saving…' : 'Approve & post to ledger',
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _syncControllers(DocumentEntity document) {
    _setController(_invoiceController, document.invoiceNumber ?? '');
    _setController(_vendorController, document.vendorName ?? '');
    _setController(_voenController, document.vendorVoen ?? '');
    _setController(_currencyController, document.currency);
    _setController(
      _issueDateController,
      document.issueDate == null ? '' : _formatDate(document.issueDate!),
    );
    _setController(
      _dueDateController,
      document.dueDate == null ? '' : _formatDate(document.dueDate!),
    );
  }

  void _setController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }
}

class _LineItemsGrid extends StatelessWidget {
  const _LineItemsGrid({
    required this.items,
    required this.currency,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final List<InvoiceItemEntity> items;
  final String currency;
  final bool enabled;
  final void Function(int index, InvoiceItemEntity item) onChanged;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: <Widget>[
          _LineItemHeader(),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No line items. Add a row to calculate totals.'),
            )
          else
            ...List<Widget>.generate(
              items.length,
              (int index) => _LineItemRow(
                key: ValueKey<String>(
                  items[index].id.isEmpty ? 'row-$index' : items[index].id,
                ),
                item: items[index],
                currency: currency,
                index: index,
                enabled: enabled,
                onChanged: onChanged,
                onRemove: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

class _LineItemHeader extends StatelessWidget {
  const _LineItemHeader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(55),
      child: Row(
        children: <Widget>[
          Expanded(flex: 6, child: Text('Description', style: style)),
          const SizedBox(width: 7),
          SizedBox(width: 66, child: Text('Qty', style: style)),
          const SizedBox(width: 7),
          SizedBox(width: 186, child: Text('Unit price', style: style)),
          const SizedBox(width: 7),
          SizedBox(width: 72, child: Text('VAT %', style: style)),
          const SizedBox(width: 7),
          SizedBox(width: 88, child: Text('Line total', style: style)),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatefulWidget {
  const _LineItemRow({
    required this.item,
    required this.currency,
    required this.index,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final InvoiceItemEntity item;
  final String currency;
  final int index;
  final bool enabled;
  final void Function(int index, InvoiceItemEntity item) onChanged;
  final ValueChanged<int> onRemove;

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;
  late final TextEditingController _vatController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.item.description);
    _quantityController = TextEditingController(text: _number(widget.item.quantity));
    _vatController = TextEditingController(text: _number(widget.item.vatRate));
  }

  @override
  void didUpdateWidget(covariant _LineItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _descriptionController.text = widget.item.description;
      _quantityController.text = _number(widget.item.quantity);
      _vatController.text = _number(widget.item.vatRate);
    } else {
      _syncNumeric(_quantityController, widget.item.quantity);
      _syncNumeric(_vatController, widget.item.vatRate);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withAlpha(45)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _cellField(
                controller: _descriptionController,
                enabled: widget.enabled,
                onChanged: (String value) => widget.onChanged(
                  widget.index,
                  widget.item.copyWith(description: value),
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 66,
            child: _cellField(
              controller: _quantityController,
              enabled: widget.enabled,
              numeric: true,
              onChanged: (String value) {
                final double parsed = _parseNumber(value) ?? 0;
                widget.onChanged(
                  widget.index,
                  widget.item.copyWith(quantity: parsed),
                );
              },
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 186,
            child: CurrencyAmountField(
              label: 'Unit price',
              initialAmount: widget.item.unitPrice,
              initialCurrency: widget.item.currency.isEmpty
                  ? widget.currency
                  : widget.item.currency,
              enabled: widget.enabled,
              onAmountChanged: (double value) => widget.onChanged(
                widget.index,
                widget.item.copyWith(unitPrice: value),
              ),
              onCurrencyChanged: (String value) => widget.onChanged(
                widget.index,
                widget.item.copyWith(currency: value),
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 72,
            child: _cellField(
              controller: _vatController,
              enabled: widget.enabled,
              numeric: true,
              onChanged: (String value) {
                final double parsed = _parseNumber(value) ?? 0;
                widget.onChanged(
                  widget.index,
                  widget.item.copyWith(vatRate: parsed),
                );
              },
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 88,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppFormatters.decimal(widget.item.lineTotal),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              tooltip: 'Remove line',
              onPressed: widget.enabled ? () => widget.onRemove(widget.index) : null,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: theme.colorScheme.error,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellField({
    required TextEditingController controller,
    required bool enabled,
    required ValueChanged<String> onChanged,
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(fontSize: 12),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      ),
    );
  }

  void _syncNumeric(TextEditingController controller, double value) {
    final double? current = _parseNumber(controller.text);
    if (current == null || (current - value).abs() > 0.000001) {
      if (controller.text.isNotEmpty) {
        controller.text = _number(value);
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.document});

  final DocumentEntity document;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withAlpha(14),
        border: Border.all(color: theme.colorScheme.secondary.withAlpha(80)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryValue(
                  label: 'Subtotal',
                  value: document.subtotal ?? 0,
                  currency: document.currency,
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Total VAT',
                  value: document.vatAmount ?? 0,
                  currency: document.currency,
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Grand total',
                  value: document.totalAmount ?? 0,
                  currency: document.currency,
                  emphasized: true,
                ),
              ),
            ],
          ),
          if (document.currency.toUpperCase() != 'AZN')
            BaseCurrencyEquivalent(
              amount: document.totalAmount ?? 0,
              currency: document.currency,
            ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.currency,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final String currency;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
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
          '$currency ${AppFormatters.decimal(value)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            color: emphasized ? theme.colorScheme.secondary : null,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...<Widget>[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class _ConfidenceTextField extends StatelessWidget {
  const _ConfidenceTextField({
    required this.controller,
    required this.label,
    required this.confidence,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final _FieldConfidence confidence;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      decoration: _confidenceDecoration(context, label, confidence),
    );
  }
}

class _DateConfidenceField extends StatelessWidget {
  const _DateConfidenceField({
    required this.controller,
    required this.label,
    required this.confidence,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final _FieldConfidence confidence;
  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
      onTap: enabled
          ? () => unawaited(_selectDate(context))
          : null,
      decoration: _confidenceDecoration(
        context,
        label,
        confidence,
      ).copyWith(
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (value != null && enabled)
              IconButton(
                tooltip: 'Clear date',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.clear_rounded, size: 16),
              ),
            const Icon(Icons.calendar_today_outlined, size: 16),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      onChanged(selected);
    }
  }
}

enum _FieldConfidence { high, review }

_FieldConfidence _confidence(Object? value) {
  if (value == null) {
    return _FieldConfidence.review;
  }
  if (value is String && value.trim().isEmpty) {
    return _FieldConfidence.review;
  }
  return _FieldConfidence.high;
}

InputDecoration _confidenceDecoration(
  BuildContext context,
  String label,
  _FieldConfidence confidence,
) {
  final ThemeData theme = Theme.of(context);
  final bool high = confidence == _FieldConfidence.high;
  final Color color = high ? theme.colorScheme.secondary : Colors.amber.shade700;
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: color.withAlpha(12),
    suffixIcon: Tooltip(
      message: high ? 'OCR confidence: high' : 'Needs accountant review',
      child: Icon(
        high ? Icons.check_circle_outline_rounded : Icons.priority_high_rounded,
        color: color,
        size: 18,
      ),
    ),
  );
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) => DateFormat('dd.MM.yyyy').format(value);

String _number(double value) => value.toStringAsFixed(2);

double? _parseNumber(String value) {
  final String normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}
