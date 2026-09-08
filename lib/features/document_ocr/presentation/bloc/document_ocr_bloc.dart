import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/document_entity.dart';
import '../../domain/entities/invoice_item_entity.dart';
import '../../domain/repositories/document_repository.dart';
import 'document_ocr_event.dart';
import 'document_ocr_state.dart';

const Object _unsetDocumentField = Object();

/// Owns the editable verification draft and the final approval transaction.
class DocumentOcrBloc extends Bloc<DocumentOcrEvent, DocumentOcrState> {
  DocumentOcrBloc({required DocumentRepository repository})
      : _repository = repository,
        super(const DocumentInitial()) {
    on<LoadDocumentDetails>(_onLoadDocumentDetails);
    on<UpdateDocumentField>(_onUpdateDocumentField);
    on<AddLineItem>(_onAddLineItem);
    on<UpdateLineItem>(_onUpdateLineItem);
    on<RemoveLineItem>(_onRemoveLineItem);
    on<SaveAndApproveDocument>(_onSaveAndApproveDocument);
  }

  final DocumentRepository _repository;

  Future<void> _onLoadDocumentDetails(
    LoadDocumentDetails event,
    Emitter<DocumentOcrState> emit,
  ) async {
    emit(const DocumentLoading());
    final result = await _repository.getDocument(event.documentId);
    result.fold(
      (failure) => emit(DocumentError(message: failure.message)),
      (DocumentEntity document) {
        final List<InvoiceItemEntity> items = _ensureItemIds(document.lineItems)
            .map(_normalizeItem)
            .toList(growable: false);
        final bool hasLineItems = items.isNotEmpty;
        emit(
          DocumentLoaded(
            _copyDocument(
              document,
              lineItems: items,
              subtotal: hasLineItems
                  ? _subtotal(items)
                  : document.subtotal ?? 0,
              vatAmount: hasLineItems
                  ? _vatAmount(items)
                  : document.vatAmount ?? 0,
              totalAmount: hasLineItems
                  ? _total(items)
                  : document.totalAmount ?? 0,
            ),
          ),
        );
      },
    );
  }

  void _onUpdateDocumentField(
    UpdateDocumentField event,
    Emitter<DocumentOcrState> emit,
  ) {
    final DocumentEntity? document = _documentFromState(state);
    if (document == null) {
      return;
    }

    final Object? value = event.value;
    switch (event.field) {
      case DocumentField.invoiceNumber:
        emit(
          DocumentLoaded(
            _copyDocument(document, invoiceNumber: _stringOrNull(value)),
          ),
        );
        break;
      case DocumentField.vendorName:
        emit(
          DocumentLoaded(
            _copyDocument(document, vendorName: _stringOrNull(value)),
          ),
        );
        break;
      case DocumentField.vendorVoen:
        emit(
          DocumentLoaded(
            _copyDocument(document, vendorVoen: _stringOrNull(value)),
          ),
        );
        break;
      case DocumentField.issueDate:
        emit(
          DocumentLoaded(
            _copyDocument(document, issueDate: _dateOrNull(value)),
          ),
        );
        break;
      case DocumentField.dueDate:
        emit(
          DocumentLoaded(
            _copyDocument(document, dueDate: _dateOrNull(value)),
          ),
        );
        break;
      case DocumentField.currency:
        emit(
          DocumentLoaded(
            _copyDocument(
              document,
              currency: value is String ? value.trim() : document.currency,
            ),
          ),
        );
        break;
    }
  }

  void _onAddLineItem(
    AddLineItem event,
    Emitter<DocumentOcrState> emit,
  ) {
    final DocumentEntity? document = _documentFromState(state);
    if (document == null) {
      return;
    }

    final InvoiceItemEntity item = _normalizeItem(
      event.item ?? _newLineItem(document.currency),
    );
    final List<InvoiceItemEntity> items = <InvoiceItemEntity>[
      ...document.lineItems,
      item,
    ];
    emit(DocumentLoaded(_recalculate(document, items)));
  }

  void _onUpdateLineItem(
    UpdateLineItem event,
    Emitter<DocumentOcrState> emit,
  ) {
    final DocumentEntity? document = _documentFromState(state);
    if (document == null ||
        event.index < 0 ||
        event.index >= document.lineItems.length) {
      return;
    }

    final List<InvoiceItemEntity> items =
        List<InvoiceItemEntity>.of(document.lineItems);
    items[event.index] = _normalizeItem(event.item);
    emit(DocumentLoaded(_recalculate(document, items)));
  }

  void _onRemoveLineItem(
    RemoveLineItem event,
    Emitter<DocumentOcrState> emit,
  ) {
    final DocumentEntity? document = _documentFromState(state);
    if (document == null ||
        event.index < 0 ||
        event.index >= document.lineItems.length) {
      return;
    }

    final List<InvoiceItemEntity> items =
        List<InvoiceItemEntity>.of(document.lineItems)
          ..removeAt(event.index);
    emit(DocumentLoaded(_recalculate(document, items)));
  }

  Future<void> _onSaveAndApproveDocument(
    SaveAndApproveDocument _event,
    Emitter<DocumentOcrState> emit,
  ) async {
    final DocumentEntity? document = _documentFromState(state);
    if (document == null) {
      emit(const DocumentError(message: 'Load a document before approving it.'));
      return;
    }

    final String? validationMessage = _validationMessage(document);
    if (validationMessage != null) {
      emit(
        DocumentError(
          message: validationMessage,
          document: document,
        ),
      );
      return;
    }

    emit(DocumentSaving(document));
    final result = await _repository.saveAndApproveDocument(document);
    result.fold(
      (failure) => emit(
        DocumentError(
          message: failure.message,
          document: document,
        ),
      ),
      (DocumentEntity approved) => emit(DocumentSavedSuccess(approved)),
    );
  }

  DocumentEntity? _documentFromState(DocumentOcrState currentState) {
    switch (currentState) {
      case DocumentLoaded state:
        return state.document;
      case DocumentSaving state:
        return state.document;
      case DocumentSavedSuccess state:
        return state.document;
      case DocumentError state:
        return state.document;
      default:
        return null;
    }
  }

  DocumentEntity _recalculate(
    DocumentEntity document,
    List<InvoiceItemEntity> items,
  ) {
    final List<InvoiceItemEntity> normalized =
        items.map(_normalizeItem).toList(growable: false);
    return _copyDocument(
      document,
      lineItems: normalized,
      subtotal: _subtotal(normalized),
      vatAmount: _vatAmount(normalized),
      totalAmount: _total(normalized),
    );
  }

  InvoiceItemEntity _normalizeItem(InvoiceItemEntity item) {
    final double quantity =
        item.quantity.isFinite && item.quantity >= 0 ? item.quantity : 0;
    final double unitPrice =
        item.unitPrice.isFinite && item.unitPrice >= 0 ? item.unitPrice : 0;
    final double vatRate =
        item.vatRate.isFinite && item.vatRate >= 0 ? item.vatRate : 0;
    final String currency =
        item.currency.trim().isEmpty ? 'AZN' : item.currency.trim();
    return item.copyWith(
      id: item.id.trim().isEmpty ? _newLineItemId() : item.id,
      quantity: quantity,
      unitPrice: unitPrice,
      vatRate: vatRate,
      lineTotal: quantity * unitPrice,
      currency: currency,
    );
  }

  List<InvoiceItemEntity> _ensureItemIds(List<InvoiceItemEntity> items) {
    final Set<String> usedIds = <String>{};
    return items.map((InvoiceItemEntity item) {
      String id = item.id.trim();
      if (id.isEmpty || !usedIds.add(id)) {
        do {
          id = _newLineItemId();
        } while (!usedIds.add(id));
      }
      return item.copyWith(id: id);
    }).toList(growable: false);
  }

  InvoiceItemEntity _newLineItem(String currency) {
    return InvoiceItemEntity(
      id: _newLineItemId(),
      description: 'New item',
      quantity: 1,
      unitPrice: 0,
      lineTotal: 0,
      vatRate: 0,
      currency: currency.trim().isEmpty ? 'AZN' : currency.trim(),
    );
  }

  String _newLineItemId() {
    return 'line-${DateTime.now().microsecondsSinceEpoch}-${state.hashCode}';
  }

  String? _validationMessage(DocumentEntity document) {
    final List<String> errors = <String>[];
    if (_stringOrNull(document.invoiceNumber) == null) {
      errors.add('Document number is required.');
    }
    if (_stringOrNull(document.vendorName) == null) {
      errors.add('Vendor name is required.');
    }
    if (document.issueDate == null) {
      errors.add('Issue date is required.');
    }
    if (document.currency.trim().isEmpty) {
      errors.add('Currency is required.');
    }

    for (int index = 0; index < document.lineItems.length; index++) {
      final InvoiceItemEntity item = document.lineItems[index];
      if (item.description.trim().isEmpty) {
        errors.add('Line ${index + 1} needs a description.');
      }
      if (item.quantity <= 0) {
        errors.add('Line ${index + 1} quantity must be greater than zero.');
      }
      if (item.unitPrice < 0 || item.vatRate < 0 || item.vatRate > 100) {
        errors.add('Line ${index + 1} has an invalid price or VAT rate.');
      }
    }
    return errors.isEmpty ? null : errors.join(' ');
  }

  DocumentEntity _copyDocument(
    DocumentEntity document, {
    Object? vendorName = _unsetDocumentField,
    Object? vendorVoen = _unsetDocumentField,
    Object? invoiceNumber = _unsetDocumentField,
    Object? issueDate = _unsetDocumentField,
    Object? dueDate = _unsetDocumentField,
    Object? subtotal = _unsetDocumentField,
    Object? vatAmount = _unsetDocumentField,
    Object? totalAmount = _unsetDocumentField,
    Object? currency = _unsetDocumentField,
    Object? lineItems = _unsetDocumentField,
  }) {
    return DocumentEntity(
      id: document.id,
      companyId: document.companyId,
      filePath: document.filePath,
      fileName: document.fileName,
      vendorName: identical(vendorName, _unsetDocumentField)
          ? document.vendorName
          : vendorName as String?,
      vendorVoen: identical(vendorVoen, _unsetDocumentField)
          ? document.vendorVoen
          : vendorVoen as String?,
      invoiceNumber: identical(invoiceNumber, _unsetDocumentField)
          ? document.invoiceNumber
          : invoiceNumber as String?,
      issueDate: identical(issueDate, _unsetDocumentField)
          ? document.issueDate
          : issueDate as DateTime?,
      dueDate: identical(dueDate, _unsetDocumentField)
          ? document.dueDate
          : dueDate as DateTime?,
      subtotal: identical(subtotal, _unsetDocumentField)
          ? document.subtotal
          : subtotal as double?,
      vatAmount: identical(vatAmount, _unsetDocumentField)
          ? document.vatAmount
          : vatAmount as double?,
      totalAmount: identical(totalAmount, _unsetDocumentField)
          ? document.totalAmount
          : totalAmount as double?,
      createdAt: document.createdAt,
      currency: identical(currency, _unsetDocumentField)
          ? document.currency
          : currency as String? ?? document.currency,
      status: document.status,
      lineItems: identical(lineItems, _unsetDocumentField)
          ? document.lineItems
          : lineItems as List<InvoiceItemEntity>? ?? document.lineItems,
      extractedData: document.extractedData,
    );
  }

  static double _subtotal(List<InvoiceItemEntity> items) {
    return items.fold<double>(
      0,
      (double total, InvoiceItemEntity item) => total + item.lineTotal,
    );
  }

  static double _vatAmount(List<InvoiceItemEntity> items) {
    return items.fold<double>(
      0,
      (double total, InvoiceItemEntity item) =>
          total + item.lineTotal * item.vatRate / 100,
    );
  }

  static double _total(List<InvoiceItemEntity> items) {
    return _subtotal(items) + _vatAmount(items);
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
